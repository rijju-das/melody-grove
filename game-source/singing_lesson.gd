extends Node
## Singing state is owned by the game; audio samples stay in the microphone adapter.
const HOLD_SECONDS := 0.55
const TOLERANCE_CENTS := 65.0
var game: Node
var enabled := false
var practice := false
var octave := 0
var held := 0.0
var miss_time := 0.0
var mic_level := 0.0
var frequency := 0.0
var freshness := 0.0
var playback_left := 0.0
var feedback := "Enable the microphone to begin."
var cents := 0.0
var has_pitch := false
var native_mic: Node

func setup(controller: Node) -> void:
	game = controller
	native_mic = preload("res://voice_capture.gd").new()
	add_child(native_mic)
	native_mic.stopped.connect(func(): enabled = false; held = 0; freshness = 0; has_pitch = false; mic_level = 0)
	native_mic.sample.connect(sample)
	native_mic.level_changed.connect(func(value: float): mic_level = value)
	native_mic.message.connect(func(text: String): feedback = text)
	native_mic.calibrated.connect(func(): enabled = true; feedback = "Ready! Tap Listen, then sing or hum.")

func reset() -> void:
	stop()
	practice = false
	held = 0
	miss_time = 0
	feedback = "Enable the microphone to begin."

func stop() -> void:
	enabled = false
	held = 0
	miss_time = 0
	freshness = 0
	has_pitch = false
	mic_level = 0
	if native_mic: native_mic.stop()

func target_frequency() -> float:
	var step: int = mini(game.lesson.round_index, 4)
	return 261.625565 * pow(2.0, octave + float([0, 2, 4, 2, 0][step]) / 12.0)

func target_name() -> String:
	var step: int = mini(game.lesson.round_index, 4)
	return "%s · %s%d" % [["Do", "Re", "Mi", "Re", "Do"][step], ["C", "D", "E", "D", "C"][step], 4 + octave]

func command(name: String, value: Variant = null) -> void:
	if game.lesson.stage != 4: return
	match name:
		"voice_level":
			mic_level = clampf(float(value), 0, 1)
		"mic_on":
			if game.paused or practice or game.lesson.phase == "complete": return
			enabled = true
			feedback = "Ready! Tap Listen, then sing or hum."
		"mic_off":
			stop()
			feedback = "Microphone off. Tap Enable microphone to continue."
		"mic_native":
			if not game.paused and not practice: native_mic.start()
		"voice_range":
			if game.hopping: return
			octave = clampi(int(value), -1, 0)
			held = 0
			miss_time = 0
			game.audio.stop()
			game.audio.pitch_scale = 1
			if game.lesson.phase in ["answer", "listening"]: game.lesson.phase = "ready"
			feedback = "Range changed. Tap Listen for your note."
		"practice":
			game.start_stage(4)
			practice = true
			feedback = "Listening practice · no singing points. Tap Listen."
		"practice_next":
			if practice and game.lesson.phase == "answer" and not game.paused and not game.hopping: _climb()

func listen() -> void:
	if game.paused or game.hopping or game.transitioning: return
	if not enabled and not practice:
		feedback = "Enable the microphone first, or choose listening practice."
		return
	if not game.lesson.listen(): return
	held = 0
	miss_time = 0
	freshness = 0
	has_pitch = false
	var step: int = game.lesson.round_index
	game.audio.pitch_scale = pow(2.0, octave)
	game.audio.stream = game.sounds[[0, 1, 2, 1, 0][step]]
	game.audio.play()
	# Pitch scaling changes playback duration; always leave 0.45 s of quiet.
	playback_left = 0.95 / game.audio.pitch_scale + 0.45
	game.stairway.light_note(step)
	feedback = "Listen to %s…" % ["Do", "Re", "Mi", "Re", "Do"][step]

func sample(hz: float) -> void:
	if not is_finite(hz): return
	frequency = hz
	freshness = 0.20

func tick(delta: float) -> void:
	game.stairway.tick(delta)
	if game.hopping:
		game._process_hop(delta)
		return
	if game.lesson.phase == "listening":
		playback_left -= delta
		if playback_left <= 0:
			game.lesson.demo_finished()
			game.audio.pitch_scale = 1
			freshness = 0
			feedback = "Your turn · sing or hum gently." if not practice else "Sing along, then tap Next step. No points in practice."
		return
	if game.lesson.phase != "answer" or practice or not enabled: return
	freshness -= delta
	has_pitch = freshness > 0 and frequency >= 75 and frequency <= 1000
	var matched := false
	if has_pitch:
		cents = pitch_error(frequency, target_frequency())
		matched = absf(cents) <= TOLERANCE_CENTS
		if matched:
			held += minf(delta, 0.1)
			miss_time = 0
			feedback = "That's it! Hold your note…"
		else:
			feedback = "A little higher ↑" if cents < 0 else "A little lower ↓"
	else:
		feedback = "I hear sound · try a steady hummm." if mic_level > 0.002 else "No voice detected · move closer or check your microphone."
	if not matched:
		miss_time += delta
		# Brief consonants/detector dropouts don't erase a good start; silence cannot add progress.
		if miss_time > 0.16: held = 0
	game.stairway.feedback(game.lesson.round_index, held / HOLD_SECONDS)
	if held >= HOLD_SECONDS: _climb()

func _climb() -> void:
	game._start_note_hop(game.lesson.round_index + 1)
	held = 0
	miss_time = 0
	freshness = 0
	feedback = "Good! Jumping to the next platform…"

func landed() -> void:
	var step: int = game.lesson.round_index
	game.stairway.collected_step(step)
	if practice:
		game.lesson.round_index += 1
		game.lesson.phase = "practice_complete" if game.lesson.round_index == 5 else "ready"
		feedback = "Practice complete! Enable singing with Retry stage." if step == 4 else "Tap Listen for the next note."
	else:
		game.lesson.submit([0, 1, 2, 1, 0][step])
		game._award_feedback(20, game.player.global_position + Vector3.UP * 1.4)
		feedback = "Well done! +20 points. Listen to your next note."
		if game.lesson.phase == "complete":
			stop()
			feedback = "You sang your way to the treetop!"
		game._check_completion()
	game.memory_marks = game.lesson.round_index
	game._update_lesson_hud()

static func pitch_error(hz: float, target: float) -> float:
	var raw := 1200.0 * log(hz / target) / log(2.0)
	# Beginners may use the same note one octave above/below the reference.
	var octave_shift := clampf(roundf(raw / 1200.0), -1.0, 1.0)
	return raw - octave_shift * 1200.0

func heard_note() -> String:
	if not has_pitch: return "—"
	var midi := roundi(69 + 12 * log(frequency / 440.0) / log(2.0))
	return "%s%d" % [["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][posmod(midi, 12)], midi / 12 - 1]

static func pitch_height(hz: float) -> float:
	# Fixed musical scale: C3 at 8%, C4 at 50%, C5 at 92%.
	# Equal semitone intervals have equal visual distances, across all platforms/ranges.
	if not is_finite(hz) or hz <= 0: return 0.0
	return clampf(0.08 + 0.84 * log(hz / 130.8127825) / log(4.0), 0, 1)

func pitch_meter() -> Dictionary:
	var reference: bool = not game.paused and not game.hopping and game.lesson.phase == "listening" and playback_left > 0.45
	var voice: bool = enabled and not practice and not game.paused and not game.hopping and game.lesson.phase == "answer" and has_pitch and freshness > 0
	var hz: float = target_frequency() if reference else (frequency if voice else 0.0)
	var error: float = pitch_error(frequency, target_frequency()) if voice else 0.0
	return {"active": reference or voice, "reference": reference, "target_height": pitch_height(target_frequency()), "value": pitch_height(hz), "hz": hz, "error": error, "matched": voice and absf(error) <= TOLERANCE_CENTS}

func snapshot() -> Dictionary:
	return {"pitch_meter": pitch_meter(), "level": snappedf(clampf(mic_level / 0.05, 0, 1), 0.02), "heard": heard_note(), "enabled": enabled, "practice": practice, "octave": octave, "target": target_frequency(), "target_name": target_name(), "hold": snappedf(held / HOLD_SECONDS, 0.02), "cents": snappedf(cents, 1), "has_pitch": has_pitch, "feedback": feedback}
