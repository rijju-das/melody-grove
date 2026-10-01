extends Node
## Native input adapter. The muted capture bus never plays the microphone aloud.
signal sample(hz: float)
signal message(text: String)
signal stopped
signal calibrated
signal level_changed(value: float)
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var bus := -1
var clock := 0.0
var settling := 0.0
var noise := 0.002
var noise_samples: Array[float] = []
var elapsed := 0.0
var since_frames := 0.0
var active := false

func start() -> void:
	if OS.has_feature("web") or active: return
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		message.emit("Microphone input needs enabling in this native build. Listening practice is available.")
		return
	if OS.has_feature("android") and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permission("android.permission.RECORD_AUDIO")
		message.emit("Allow microphone access, then tap Enable microphone again.")
		return
	bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "SingingInput")
	AudioServer.set_bus_mute(bus, true)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.25
	AudioServer.add_bus_effect(bus, capture)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = "SingingInput"
	add_child(player)
	player.play()
	active = true
	settling = 1.5
	noise = 0.002
	noise_samples.clear()
	elapsed = 0
	since_frames = 0
	clock = 0
	message.emit("Microphone check: stay quiet for a moment…")

func stop() -> void:
	active = false
	stopped.emit()
	if player:
		player.stop()
		player.queue_free()
		player = null
	if bus >= 0:
		AudioServer.remove_bus(bus)
		bus = -1
	capture = null

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	since_frames += delta
	if since_frames > 3.0:
		stop()
		message.emit("No microphone input. Check Godot microphone permission and your Mac's input device, then enable again.")
		return
	clock += delta
	if clock < 0.09: return
	clock = 0
	if capture.get_frames_available() < 4096: return
	since_frames = 0
	var frames := capture.get_buffer(capture.get_frames_available())
	var stride := maxi(1, int(AudioServer.get_mix_rate() / 8000))
	var data := PackedFloat32Array()
	for i in range(maxi(0, frames.size() - 4096), frames.size(), stride): data.append((frames[i].x + frames[i].y) * 0.5)
	var rms := 0.0
	for value in data: rms += value * value
	rms = sqrt(rms / data.size())
	level_changed.emit(rms)
	if settling > 0:
		noise_samples.append(rms)
		if elapsed >= 1.5:
			noise = noise_floor(noise_samples)
			settling = 0
			if noise > 0.035:
				stop()
				message.emit("Setup heard too much sound. Stay quiet and enable the microphone again.")
				return
			calibrated.emit()
		return
	sample.emit(detect(data, AudioServer.get_mix_rate() / stride) if rms > noise else 0.0)

static func noise_floor(levels: Array[float]) -> float:
	var ordered := levels.duplicate()
	ordered.sort()
	return maxf(0.002, ordered[int(ordered.size() * 0.25)] * 1.8) if not ordered.is_empty() else 0.002

static func detect(data: PackedFloat32Array, rate: float) -> float:
	# YIN cumulative normalized difference; reject aperiodic noise.
	var max_lag := mini(int(rate / 75), data.size() / 2 - 1)
	var min_lag := int(rate / 1000)
	var values := PackedFloat32Array()
	values.resize(max_lag + 1)
	var running := 0.0
	for lag in range(1, max_lag + 1):
		var difference := 0.0
		for i in range(data.size() / 2):
			var d := data[i] - data[i + lag]
			difference += d * d
		running += difference
		values[lag] = difference * lag / running if running > 0.000001 else 1.0
	for lag in range(maxi(2, min_lag), max_lag - 1):
		if values[lag] < 0.15 and values[lag] <= values[lag - 1] and values[lag] <= values[lag + 1]:
			var denominator := values[lag - 1] - 2 * values[lag] + values[lag + 1]
			var adjustment := 0.5 * (values[lag - 1] - values[lag + 1]) / denominator if absf(denominator) > 0.000001 else 0.0
			return rate / (lag + adjustment)
	return 0

func _exit_tree() -> void:
	stop()
