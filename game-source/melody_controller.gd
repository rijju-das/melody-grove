extends Node

signal note_played(note_index: int)
signal step_landed(route_index: int)

const NOTE_NAMES := ["Do · C4", "Re · D4", "Mi · E4", "Fa · F4", "Sol · G4", "La · A4", "Ti · B4", "Do · C5"]
const SEMITONES := [0, 2, 4, 5, 7, 9, 11, 12]
const HOP_SECONDS := 0.5
const FOOT_OFFSET := Vector3(0, 0.135, 0)

var player: Node3D
var pads: Array[Node3D] = []
var route: Array[Vector3] = []
var sounds: Array[AudioStreamWAV] = []
var route_index := 0
var destination := 0
var hopping := false
var paused := false
var hop_elapsed := 0.0
var cooldown := 0.0
var hop_start := Vector3.ZERO
var queued_direction := 0
var audio: AudioStreamPlayer
var halo: MeshInstance3D
var status: Label
var pause_button: Button
var limbs: Array[Node3D] = []
var limb_rest: Array[Vector3] = []
var web_callback: JavaScriptObject
var web_last_state := ""
var lesson = preload("res://lesson.gd").new()
var demo_index := 0
var demo_elapsed := 0.0
var collectibles: Array[MeshInstance3D] = []
var stage_buttons: Array[Button] = []
var lesson_label: Label
var saved_ok := true
var status_before_pause := ""

func _ready() -> void:
	_bind_keys()
	var forest := get_parent().get_node("Melody Grove • musical forest")
	player = forest.find_child("MS_Player", true, false) as Node3D
	var spawn := forest.find_child("Grove_starting surface", true, false) as Node3D
	if player == null or spawn == null:
		push_error("Melody Grove: missing player or starting platform.")
		set_process(false)
		return
	route.append(spawn.global_position + FOOT_OFFSET)
	for i in range(8):
		var pad := forest.find_child("MS_Pad_%d" % i, true, false) as Node3D
		if pad == null:
			push_error("Melody Grove: missing note platform %d." % i)
			set_process(false)
			return
		pads.append(pad)
		route.append(pad.global_position + FOOT_OFFSET)
	for limb_name in ["MS_Leg_L", "MS_Leg_R", "MS_Arm_L", "MS_Arm_R"]:
		var limb := player.find_child(limb_name, true, false) as Node3D
		if limb:
			limbs.append(limb)
			limb_rest.append(limb.rotation)
	audio = AudioStreamPlayer.new()
	audio.name = "NoteAudio"
	audio.volume_db = -8.0
	add_child(audio)
	_make_sounds()
	_make_halo()
	_make_collectibles()
	_make_hud()
	_load_progress()
	start_stage(1)
	if OS.has_feature("web"):
		get_node("GameControls").hide()
		web_callback = JavaScriptBridge.create_callback(_web_command)
		JavaScriptBridge.get_interface("window").groveCommand = web_callback
		get_parent().get_node("GameCamera").keep_aspect = Camera3D.KEEP_WIDTH
		get_viewport().size_changed.connect(_fit_web_camera)
		_fit_web_camera()
	get_window().focus_exited.connect(_on_focus_lost)

func _fit_web_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y > 0:
		get_parent().get_node("GameCamera").size = maxf(36.0, 25.0 * viewport_size.x / viewport_size.y)

func _web_command(arguments: Array) -> void:
	if arguments.is_empty():
		return
	match str(arguments[0]):
		"next": request_step(1)
		"back": request_step(-1)
		"repeat": repeat_note()
		"choose": choose_note()
		"listen": listen_melody()
		"stage":
			if arguments.size() > 1: start_stage(int(arguments[1]))
		"restart": start_stage(lesson.stage)
		"pause": toggle_pause()
		"volume":
			if arguments.size() > 1:
				audio.volume_db = linear_to_db(maxf(clampf(float(arguments[1]), 0, 1), 0.00001))

func _bind_keys() -> void:
	var bindings := {
		"grove_forward": [KEY_UP, KEY_RIGHT, KEY_W, KEY_D],
		"grove_backward": [KEY_DOWN, KEY_LEFT, KEY_S, KEY_A],
		"grove_repeat": [KEY_SPACE],
		"grove_choose": [KEY_ENTER],
		"grove_listen": [KEY_L],
		"grove_restart": [KEY_R],
		"grove_pause": [KEY_P, KEY_ESCAPE],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or player == null:
		return
	if event.is_action_pressed("grove_restart"):
		start_stage(lesson.stage)
	elif event.is_action_pressed("grove_pause"):
		toggle_pause()
	elif event.is_action_pressed("grove_repeat"):
		repeat_note()
	elif event.is_action_pressed("grove_choose"):
		choose_note()
	elif event.is_action_pressed("grove_listen"):
		listen_melody()
	elif event.is_action_pressed("grove_forward"):
		request_step(1)
	elif event.is_action_pressed("grove_backward"):
		request_step(-1)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if OS.has_feature("web") and status:
		var state := JSON.stringify({"text": status.text, "paused": paused, "step": route_index, "hopping": hopping, "lesson": lesson.snapshot(), "saved": saved_ok})
		if state != web_last_state:
			web_last_state = state
			JavaScriptBridge.eval("window.groveState && window.groveState(" + state + ")")
	if player == null or paused:
		return
	if lesson.phase == "listening":
		demo_elapsed -= delta
		if demo_elapsed <= 0:
			var melody: Array = lesson.melody()
			if demo_index < melody.size():
				_play_note(int(melody[demo_index]))
				status.text = "Listen: %s (%d of %d)" % [NOTE_NAMES[melody[demo_index]], demo_index + 1, melody.size()]
				demo_index += 1
				demo_elapsed = 1.05
			else:
				lesson.demo_finished()
				halo.hide()
				status.text = "Your turn! Move to a note, then Choose note."
		return
	if lesson.phase == "complete": return
	cooldown = maxf(0, cooldown - delta)
	if hopping:
		hop_elapsed = minf(HOP_SECONDS, hop_elapsed + delta)
		var t := hop_elapsed / HOP_SECONDS
		var eased := t * t * (3.0 - 2.0 * t)
		player.global_position = hop_start.lerp(route[destination], eased) + Vector3.UP * sin(PI * t) * 0.8
		for i in range(limbs.size()):
			var swing := sin(TAU * t) * 0.28 * (1.0 if i % 2 == 0 else -1.0)
			limbs[i].rotation = limb_rest[i] + Vector3(swing, 0, 0)
		if t >= 1.0:
			player.global_position = route[destination]
			route_index = destination
			hopping = false
			cooldown = 0.16
			_rest_limbs()
			if route_index > 0:
				_play_note(route_index - 1)
				if lesson.explore(route_index - 1):
					collectibles[route_index - 1].hide()
					status.text = "+10 points! %s · %d of 8 notes found" % [NOTE_NAMES[route_index - 1], lesson.collected.size()]
					_check_completion()
			else:
				halo.hide()
				status.text = "Starting stump · hop forward to hear Do"
			step_landed.emit(route_index)
	elif cooldown <= 0:
		var direction := queued_direction
		queued_direction = 0
		if direction == 0:
			direction = int(Input.is_action_pressed("grove_forward")) - int(Input.is_action_pressed("grove_backward"))
		if direction != 0:
			request_step(direction)

func request_step(direction: int) -> void:
	if paused or player == null or lesson.phase in ["listening", "complete"]:
		return
	if hopping or cooldown > 0:
		# Buffer one tap so quick presses feel responsive without a long queue.
		queued_direction = direction
		return
	var target := clampi(route_index + direction, 0, route.size() - 1)
	if target == route_index:
		status.text = "Top Do! Hop back to descend the scale." if route_index > 0 else "At the start · press Up, Right, W or D"
		return
	destination = target
	hop_start = player.global_position
	hop_elapsed = 0
	hopping = true
	var facing := route[target] - hop_start
	player.rotation.y = atan2(facing.x, facing.z)
	status.text = "Hopping to %s…" % NOTE_NAMES[target - 1] if target > 0 else "Returning to the starting stump…"

func reset_player() -> void:
	if player == null or route.is_empty():
		return
	hopping = false
	paused = false
	queued_direction = 0
	cooldown = 0.2
	hop_elapsed = 0
	route_index = 0
	destination = 0
	player.global_position = route[0]
	player.rotation = Vector3.ZERO
	_rest_limbs()
	if audio:
		audio.stop()
		audio.stream_paused = false
	if halo:
		halo.hide()
	if status:
		status.text = "Free play · hop onto a step, listen, then sing along"
	if pause_button:
		pause_button.text = "Pause · P"

func repeat_note() -> void:
	if paused or hopping or lesson.phase in ["listening", "complete"]:
		return
	if route_index == 0:
		status.text = "Hop onto the first step to hear Do."
	else:
		_play_note(route_index - 1)

func toggle_pause() -> void:
	if lesson.phase == "complete": return
	paused = not paused
	queued_direction = 0
	audio.stream_paused = paused
	pause_button.text = "Resume · P" if paused else "Pause · P"
	if paused:
		status_before_pause = status.text
		status.text = "Paused · tap Resume to continue"
	else:
		status.text = status_before_pause

func _on_focus_lost() -> void:
	# The web page owns touch controls outside the canvas. It pauses on tab hide.
	if OS.has_feature("web"):
		return
	if not paused:
		toggle_pause()

func _rest_limbs() -> void:
	for i in range(limbs.size()):
		limbs[i].rotation = limb_rest[i]

func _play_note(index: int) -> void:
	audio.stream = sounds[index]
	audio.play()
	halo.global_position = pads[index].global_position + Vector3.UP * 0.16
	halo.show()
	status.text = "%s · listen, then sing it back" % NOTE_NAMES[index] if lesson.stage == 1 else "%s · Choose note to answer" % NOTE_NAMES[index]
	note_played.emit(index)

func start_stage(number: int) -> void:
	if not lesson.begin(number): return
	reset_player()
	demo_index = 0
	demo_elapsed = 0
	for orb in collectibles: orb.visible = number == 1
	status.text = "Collect all 8 golden notes · 10 points each" if number == 1 else "Tap Listen, remember the melody, then choose its notes."
	_update_lesson_hud()

func listen_melody() -> void:
	if paused or hopping or not lesson.listen(): return
	queued_direction = 0
	demo_index = 0
	demo_elapsed = 0
	status.text = "Listen carefully…"

func choose_note() -> void:
	if paused or hopping or route_index == 0: return
	var result: String = lesson.submit(route_index - 1)
	if result == "ignored":
		status.text = "Tap Listen before answering." if lesson.phase == "ready" else status.text
		return
	_play_note(route_index - 1)
	match result:
		"retry": status.text = "Try that melody again from its first note. Listen is always available."
		"correct": status.text = "Correct! Choose note %d of %d." % [lesson.answer_index + 1, lesson.melody().size()]
		"round": status.text = "Melody complete! Tap Listen for melody %d of 3." % [lesson.round_index + 1]
	_update_lesson_hud()
	_check_completion()

func _check_completion() -> void:
	_update_lesson_hud()
	if lesson.phase != "complete": return
	queued_direction = 0
	_save_progress()
	status.text = "Stage complete! %d points · %d stars · choose your next stage" % [lesson.score, lesson.stars]

func _load_progress() -> void:
	var content := ""
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval("window.groveLoadProgress ? window.groveLoadProgress() : ''")
		if value is String: content = value
	elif FileAccess.file_exists("user://grove-progress.json"):
		content = FileAccess.get_file_as_string("user://grove-progress.json")
	if not content.is_empty(): lesson.restore(JSON.parse_string(content))

func _save_progress() -> void:
	var content := JSON.stringify(lesson.progress())
	if OS.has_feature("web"):
		saved_ok = JavaScriptBridge.eval("window.groveSaveProgress && window.groveSaveProgress(" + JSON.stringify(content) + ")") == true
	else:
		var file := FileAccess.open("user://grove-progress.json", FileAccess.WRITE)
		saved_ok = file != null
		if file: file.store_string(content)

func _update_lesson_hud() -> void:
	if lesson_label:
		lesson_label.text = "Stage %d: %s · %d points · Best total: %d" % [lesson.stage, lesson.TITLES[lesson.stage-1], lesson.score, lesson.total()]
	for i in range(stage_buttons.size()): stage_buttons[i].disabled = i + 1 > lesson.unlocked()

func _make_collectibles() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffd578")
	for pad in pads:
		var orb := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.15
		mesh.height = 0.30
		mesh.radial_segments = 12
		mesh.rings = 6
		orb.mesh = mesh
		orb.material_override = material
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(orb)
		orb.global_position = pad.global_position + Vector3.UP * 0.65
		collectibles.append(orb)

func _make_sounds() -> void:
	const RATE := 22050
	const SECONDS := 0.95
	for semitone in SEMITONES:
		var pcm := PackedByteArray()
		var count := int(RATE * SECONDS)
		pcm.resize(count * 2)
		var frequency := 261.625565 * pow(2.0, float(semitone) / 12.0)
		for i in range(count):
			var t := float(i) / RATE
			var envelope := minf(t / 0.025, 1.0) * minf((SECONDS - t) / 0.20, 1.0)
			var phase := TAU * frequency * t
			var tone := sin(phase) + 0.2 * sin(phase * 2) + 0.07 * sin(phase * 3)
			pcm.encode_s16(i * 2, int(tone * envelope * 14000))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = RATE
		stream.data = pcm
		sounds.append(stream)

func _make_halo() -> void:
	halo = MeshInstance3D.new()
	halo.name = "CurrentNoteRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.99
	ring.outer_radius = 1.065
	ring.rings = 32
	ring.ring_segments = 8
	halo.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("fff2af")
	halo.material_override = material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameControls"
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 22
	panel.offset_right = -22
	panel.offset_top = -230
	panel.offset_bottom = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.18, 0.20, 0.96)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	lesson_label = Label.new()
	lesson_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson_label.add_theme_font_size_override("font_size", 23)
	box.add_child(lesson_label)
	var stages := HBoxContainer.new()
	stages.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stages)
	for i in range(3): stage_buttons.append(_button(stages, "Stage %d" % (i+1), start_stage.bind(i+1)))
	status = Label.new()
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("fff0ce"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	var hint := Label.new()
	hint.text = "Arrows / WASD: hop · Space: hear note · Enter: choose · L: listen · R: retry stage"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 19)
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_button(row, "← Back", request_step.bind(-1))
	_button(row, "Next →", request_step.bind(1))
	_button(row, "Repeat · Space", repeat_note)
	_button(row, "Choose", choose_note)
	_button(row, "Listen", listen_melody)
	_button(row, "Retry", func(): start_stage(lesson.stage))
	pause_button = _button(row, "Pause · P", toggle_pause)
	var volume_label := Label.new()
	volume_label.text = "Volume"
	row.add_child(volume_label)
	var volume := HSlider.new()
	volume.custom_minimum_size.x = 125
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = db_to_linear(audio.volume_db)
	volume.focus_mode = Control.FOCUS_NONE
	volume.value_changed.connect(func(value: float): audio.volume_db = linear_to_db(maxf(value, 0.00001)))
	row.add_child(volume)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 38)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
