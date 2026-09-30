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
var camera: Camera3D
var collectible_time := 0.0
var attempt_id := 0
var reward_id := 0
var last_reward: Dictionary = {}
var reward_counter: Label
var gem_counter: Label
var reward_effects: Control
var camera_button: Button
var success_audio: AudioStreamPlayer
var celebrated_attempt := -1
var success_overlay: Control
var success_heading: Label
var success_summary: Label
var success_stars: Label
var next_stage_button: Button
var stage_path: Node3D
var transitioning := false
var travel_points: Array[Vector3] = []
var travel_index := 0
var travel_position := Vector3.ZERO
var travel_time := 0.0
var next_stage := 1
var memory_arena: Node3D
var canopy: Node3D
var canopy_index := 0
var concert_moving := false
var concert_hint := false
var native_hint_button: Button
var memory_marks := 0
var memory_return_delay := 0.0
var memory_return_text := ""
var native_markers: Label
var native_step_row: HBoxContainer
var native_choose_button: Button
var native_hint: Label
var native_glade: Button
var native_stages: HBoxContainer
var native_repeat: Button
var native_listen: Button
var native_panel: PanelContainer

func _ready() -> void:
	_bind_keys()
	camera = get_parent().get_node("GameCamera")
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
	stage_path = preload("res://stage_path.gd").new()
	add_child(stage_path)
	stage_path.setup(forest, player)
	memory_arena = preload("res://memory_arena.gd").new()
	stage_path.sections[1].add_child(memory_arena)
	memory_arena.setup(stage_path.sections[1])
	canopy = preload("res://canopy_concert.gd").new()
	stage_path.sections[2].add_child(canopy)
	canopy.setup(stage_path.sections[2], stage_path.entry(3))
	audio = AudioStreamPlayer.new()
	audio.name = "NoteAudio"
	audio.volume_db = -8.0
	add_child(audio)
	success_audio = AudioStreamPlayer.new()
	success_audio.name = "SuccessAudio"
	success_audio.stream = preload("res://success.wav")
	success_audio.volume_db = audio.volume_db
	add_child(success_audio)
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
	get_window().focus_exited.connect(_on_focus_lost)

func _web_command(arguments: Array) -> void:
	if arguments.is_empty():
		return
	match str(arguments[0]):
		"next": request_step(1)
		"back": request_step(-1)
		"repeat": repeat_note()
		"choose": choose_note()
		"listen": listen_melody()
		"hint": listen_melody(true)
		"note":
			if arguments.size() > 1: request_note(int(arguments[1]))
		"stage":
			if arguments.size() > 1: start_stage(int(arguments[1]))
		"restart": start_stage(lesson.stage)
		"pause": toggle_pause()
		"camera": toggle_camera()
		"advance": advance_stage()
		"celebrate": celebrate()
		"stop_celebration": success_audio.stop()
		"volume":
			if arguments.size() > 1:
				_set_volume(float(arguments[1]))

func _bind_keys() -> void:
	var bindings := {
		"grove_forward": [KEY_UP, KEY_RIGHT, KEY_W, KEY_D],
		"grove_backward": [KEY_DOWN, KEY_LEFT, KEY_S, KEY_A],
		"grove_repeat": [KEY_SPACE],
		"grove_choose": [KEY_ENTER],
		"grove_listen": [KEY_L],
		"grove_restart": [KEY_R],
		"grove_pause": [KEY_P, KEY_ESCAPE],
		"grove_camera": [KEY_C],
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
	if lesson.stage >= 2 and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
		request_note(event.physical_keycode - KEY_1)
	elif event.is_action_pressed("grove_restart"):
		start_stage(lesson.stage)
	elif event.is_action_pressed("grove_pause"):
		toggle_pause()
	elif event.is_action_pressed("grove_camera"):
		toggle_camera()
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
		var state := JSON.stringify({"text": status.text, "paused": paused, "step": route_index, "hopping": hopping, "lesson": lesson.snapshot(), "saved": saved_ok, "attempt": attempt_id, "reward": last_reward, "overview": camera.overview, "camera_wide": camera.is_overview(), "transitioning": transitioning, "memory_marks": memory_marks, "recovering": memory_return_delay > 0, "targets": _memory_targets(), "glade_target": _glade_target(), "clearing": canopy_index + 1, "guided": concert_hint, "concert_moving": concert_moving})
		if state != web_last_state:
			web_last_state = state
			JavaScriptBridge.eval("window.groveState && window.groveState(" + state + ")")
	if native_glade:
		native_glade.visible = lesson.stage >= 2 and not transitioning and lesson.phase != "complete"
		native_glade.disabled = paused or hopping or memory_return_delay > 0 or lesson.phase in ["listening", "complete"]
		native_glade.text = "♪ Listening…" if lesson.phase == "listening" else ("Listen again\n↓" if lesson.phase == "answer" else "Tap to listen\n↓")
		native_glade.position = camera.unproject_position(active_arena().center) - Vector2(80, 95)
	if native_hint_button:
		native_hint_button.visible = lesson.stage == 3
		native_hint_button.disabled = paused or hopping or transitioning or memory_return_delay > 0 or lesson.phase not in ["ready", "answer"]
	if player == null or paused:
		return
	if transitioning:
		if concert_moving: _walk_concert(delta)
		else: _walk_to_next_stage(delta)
		return
	if lesson.stage == 2: memory_arena.tick(delta)
	if lesson.stage == 3: canopy.tick(delta)
	collectible_time += delta
	for i in range(collectibles.size()):
		if collectibles[i].visible:
			collectibles[i].rotation.y += delta * 1.4
			collectibles[i].global_position.y = pads[i].global_position.y + 1.15 + sin(collectible_time * 2.8 + i) * 0.13
	if lesson.phase == "listening":
		if lesson.stage >= 2 and hopping:
			_process_hop(delta)
			return
		demo_elapsed -= delta
		if demo_elapsed <= 0:
			var melody: Array = lesson.melody()
			if demo_index < melody.size():
				_play_note(int(melody[demo_index]))
				status.text = "Listen: %s (%d of %d)" % [NOTE_NAMES[melody[demo_index]], demo_index + 1, melody.size()]
				if lesson.stage == 3 and not _reveal_demo_note():
					status.text = "Listen carefully… %d of 4" % (demo_index + 1)
				demo_index += 1
				demo_elapsed = 1.05
			else:
				lesson.demo_finished()
				halo.hide()
				if lesson.stage >= 2: active_arena().clear_lights()
				status.text = "Your turn! Tap the first platform, or press 1–8." if lesson.stage >= 2 else "Your turn! Move to a note, then Choose note."
		return
	if lesson.phase == "complete": return
	cooldown = maxf(0, cooldown - delta)
	if lesson.stage >= 2 and memory_return_delay > 0:
		memory_return_delay = maxf(0, memory_return_delay - delta)
		if memory_return_delay == 0: _start_note_hop(0)
		return
	if hopping:
		_process_hop(delta)
	elif cooldown <= 0 and lesson.stage == 1:
		var direction := queued_direction
		queued_direction = 0
		if direction == 0:
			direction = int(Input.is_action_pressed("grove_forward")) - int(Input.is_action_pressed("grove_backward"))
		if direction != 0:
			request_step(direction)

func _process_hop(delta: float) -> void:
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
		if lesson.stage >= 2:
			if route_index > 0: choose_note(true)
			else:
				halo.hide()
				status.text = "Listen carefully…" if lesson.phase == "listening" else memory_return_text
		elif route_index > 0:
			_play_note(route_index - 1)
			if lesson.explore(route_index - 1):
				_award_feedback(10, collectibles[route_index - 1].global_position)
				collectibles[route_index - 1].hide()
				status.text = "+10 points! %s · %d of 8 gems found" % [NOTE_NAMES[route_index - 1], lesson.collected.size()]
				_check_completion()
		else:
			halo.hide()
			status.text = "Starting stump · hop forward to hear Do"
		step_landed.emit(route_index)

func request_step(direction: int) -> void:
	if lesson.stage >= 2 or paused or player == null or lesson.phase in ["listening", "complete"]:
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

func request_note(index: int) -> void:
	if lesson.stage not in [1, 2, 3] or paused or hopping or transitioning or memory_return_delay > 0 or index < 0 or index > 7: return
	if lesson.phase == "complete" or (lesson.stage >= 2 and lesson.phase != "answer"): return
	_start_note_hop(index + 1)
	status.text = "Jumping to %s…" % NOTE_NAMES[index]

func _start_note_hop(target: int) -> void:
	destination = target
	hop_start = player.global_position
	hop_elapsed = 0
	hopping = true
	queued_direction = 0
	var facing := route[target] - hop_start
	if facing.length() > 0.01: player.rotation.y = atan2(facing.x, facing.z)

func _glade_target() -> Array:
	if lesson.stage < 2 or transitioning: return []
	var viewport_size := get_viewport().get_visible_rect().size
	var point := camera.unproject_position(active_arena().center)
	var edge := camera.unproject_position(active_arena().center + camera.global_basis.x * 1.25)
	return [snappedf(point.x / viewport_size.x, 0.0001), snappedf(point.y / viewport_size.y, 0.0001), snappedf(point.distance_to(edge) * 2.0 / viewport_size.x, 0.0001)]

func _memory_targets() -> Array:
	var targets: Array = []
	if lesson.stage not in [1, 2, 3] or transitioning: return targets
	var viewport_size := get_viewport().get_visible_rect().size
	for pad in pads:
		var point := camera.unproject_position(pad.global_position)
		var edge := camera.unproject_position(pad.global_position + camera.global_basis.x)
		targets.append([snappedf(point.x / viewport_size.x, 0.0001), snappedf(point.y / viewport_size.y, 0.0001), snappedf(point.distance_to(edge) * 2.1 / viewport_size.x, 0.0001)])
	return targets

func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("web") or lesson.stage not in [1, 2, 3]: return
	var point: Vector2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: point = event.position
	elif event is InputEventScreenTouch and event.pressed: point = event.position
	else: return
	var centre_screen := camera.unproject_position(active_arena().center)
	var centre_radius := centre_screen.distance_to(camera.unproject_position(active_arena().center + camera.global_basis.x * 1.25))
	if lesson.stage >= 2 and point.distance_to(centre_screen) <= centre_radius:
		listen_melody()
		get_viewport().set_input_as_handled()
		return
	for i in range(pads.size()):
		var screen := camera.unproject_position(pads[i].global_position)
		var radius := screen.distance_to(camera.unproject_position(pads[i].global_position + camera.global_basis.x * 1.05))
		if point.distance_to(screen) <= radius:
			request_note(i)
			get_viewport().set_input_as_handled()
			return

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
		status.text = "Tap the Listening Glade to hear the melody." if lesson.stage >= 2 else "Hop onto the first step to hear Do."
	else:
		_play_note(route_index - 1)

func toggle_pause() -> void:
	if lesson.phase == "complete" and not transitioning: return
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

func active_arena() -> Node3D:
	return canopy.arenas[canopy_index] if lesson.stage == 3 else memory_arena

func _reveal_demo_note() -> bool:
	return lesson.stage != 3 or lesson.phase != "listening" or concert_hint or canopy_index == 0 or (canopy_index == 1 and demo_index == 0)

func _play_note(index: int) -> void:
	audio.stream = sounds[index]
	audio.play()
	halo.global_position = pads[index].global_position + Vector3.UP * 0.16
	halo.show()
	status.text = "%s · listen, then sing it back" % NOTE_NAMES[index] if lesson.stage == 1 else "%s · Choose note to answer" % NOTE_NAMES[index]
	if lesson.stage >= 2:
		if _reveal_demo_note():
			status.text = "Listen: %s" % NOTE_NAMES[index] if lesson.phase == "listening" else NOTE_NAMES[index]
			active_arena().light_note(index)
		else:
			halo.hide()
			active_arena().clear_lights()
			status.text = "Listen carefully…"
	note_played.emit(index)

func start_stage(number: int, arriving := false) -> void:
	if not lesson.begin(number): return
	transitioning = false
	concert_moving = false
	concert_hint = false
	canopy_index = 0
	canopy.reset()
	stage_path.show_stage(number)
	pads.clear()
	route.clear()
	route.append(active_arena().center if number >= 2 else stage_path.entry(number))
	var section: Node3D = stage_path.sections[number - 1]
	for i in range(8):
		var pad := active_arena().pads[i] as Node3D if number >= 2 else section.find_child("MS_Pad_%d" % i, true, false) as Node3D
		pads.append(pad)
		route.append(pad.global_position + FOOT_OFFSET)
		collectibles[i].global_position = pad.global_position + Vector3.UP * 1.15
	memory_marks = 0
	memory_return_delay = 0
	memory_return_text = "Tap the Listening Glade to hear the melody."
	memory_arena.reset()
	attempt_id += 1
	success_audio.stop()
	success_overlay.hide()
	last_reward = {}
	for effect in reward_effects.get_children(): effect.queue_free()
	reset_player()
	if not arriving: camera.reset_follow()
	if camera_button: camera_button.text = "Wide view · C"
	if camera_button: camera_button.visible = number == 1
	demo_index = 0
	demo_elapsed = 0
	for orb in collectibles: orb.visible = number == 1
	status.text = "Tap a platform to jump and collect its gem · 10 points each" if number == 1 else "Tap Listen, remember the melody, then choose its notes."
	if number == 2: status.text = "Tap the centre glade. Watch, then jump to repeat the melody."
	if number == 3: status.text = _concert_prompt()
	_update_lesson_hud()

func advance_stage() -> void:
	if transitioning or lesson.phase != "complete" or lesson.stage >= 3: return
	next_stage = lesson.stage + 1
	stage_path.prepare_passage(lesson.stage)
	success_overlay.hide()
	success_audio.stop()
	halo.hide()
	camera.overview = false
	transitioning = true
	paused = false
	travel_points.clear()
	# Finish walking the current branch before crossing the connecting bridge.
	if lesson.stage == 2:
		travel_points.append(memory_arena.center)
		travel_points.append(memory_arena.exit_waypoint)
		travel_points.append(memory_arena.exit_point)
	else:
		for i in range(route_index + 1, route.size()): travel_points.append(route[i])
	travel_points.append(stage_path.entry(next_stage))
	if next_stage == 2: travel_points.append(memory_arena.center)
	if next_stage == 3:
		travel_points.append(canopy.arenas[0].center + Vector3(-6.6, 0, 2.3))
		travel_points.append(canopy.arenas[0].center)
	travel_index = 0
	travel_time = 0
	travel_position = player.global_position
	status.text = "The trees are opening! Walking to %s…" % lesson.TITLES[next_stage - 1]

func _walk_to_next_stage(delta: float) -> void:
	travel_time += delta
	var target := travel_points[travel_index]
	var facing := target - travel_position
	if facing.length() > 0.01: player.rotation.y = atan2(facing.x, facing.z)
	travel_position = travel_position.move_toward(target, delta * 4.8)
	player.global_position = travel_position + Vector3.UP * absf(sin(travel_time * 12)) * 0.07
	for i in range(limbs.size()): limbs[i].rotation = limb_rest[i] + Vector3(sin(travel_time * 12) * 0.35 * (1 if i % 2 == 0 else -1), 0, 0)
	var gate_index: int = lesson.stage - 1
	var gate: Node3D = stage_path.gates[gate_index][0]
	if travel_position.distance_to(gate.global_position) < 8 or stage_path.opened[gate_index] > 0:
		stage_path.move_gate(gate_index, minf(1, stage_path.opened[gate_index] + delta * 1.1))
	if travel_position.distance_to(target) < 0.01:
		travel_index += 1
		if travel_index >= travel_points.size(): start_stage(next_stage, true)

func _concert_prompt() -> String:
	return ["Tap the musical lantern. Watch all four notes, then repeat.", "Only the first note will glow. Tap the lantern, or ask for a hint.", "Listen by ear. Tap the lantern; Show hint is always free."][canopy_index]

func _start_concert_passage() -> void:
	transitioning = true
	concert_moving = true
	memory_return_delay = 0
	queued_direction = 0
	halo.hide()
	active_arena().clear_lights()
	travel_time = 0
	travel_index = 0
	travel_position = player.global_position
	var from: Vector3 = active_arena().center
	var to: Vector3 = canopy.arenas[canopy_index + 1].center
	travel_points.assign([from, from + Vector3(6.6, 0, 2.3), to + Vector3(-6.6, 0, 2.3), to])
	status.text = "+40 points! Your melody is growing a bridge…"

func _walk_concert(delta: float) -> void:
	travel_time += delta
	canopy.grow_bridge(canopy_index, minf(1, travel_time / 1.2))
	if travel_time < 1.2: return
	var target := travel_points[travel_index]
	var facing := target - travel_position
	if facing.length() > 0.01: player.rotation.y = atan2(facing.x, facing.z)
	travel_position = travel_position.move_toward(target, delta * 4.8)
	player.global_position = travel_position + Vector3.UP * absf(sin(travel_time * 12)) * 0.07
	for i in range(limbs.size()): limbs[i].rotation = limb_rest[i] + Vector3(sin(travel_time * 12) * 0.35 * (1 if i % 2 == 0 else -1), 0, 0)
	if travel_position.distance_to(target) >= 0.01: return
	travel_index += 1
	if travel_index < travel_points.size(): return
	canopy_index += 1
	transitioning = false
	concert_moving = false
	concert_hint = false
	memory_marks = 0
	route.clear()
	pads.clear()
	route.append(active_arena().center)
	for pad in active_arena().pads:
		pads.append(pad)
		route.append(pad.global_position + FOOT_OFFSET)
	reset_player()
	status.text = _concert_prompt()
	_update_lesson_hud()

func listen_melody(with_hint := false) -> void:
	if paused or hopping or transitioning or memory_return_delay > 0 or not lesson.listen(): return
	concert_hint = with_hint and lesson.stage == 3
	queued_direction = 0
	demo_index = 0
	demo_elapsed = 0
	status.text = "Listen carefully…"
	if lesson.stage >= 2:
		memory_marks = 0
		active_arena().clear_lights()
		if route_index != 0: _start_note_hop(0)
		_update_lesson_hud()

func choose_note(from_landing := false) -> void:
	if lesson.stage >= 2 and not from_landing: return
	if paused or hopping or route_index == 0: return
	var previous_score: int = lesson.score
	var result: String = lesson.submit(route_index - 1)
	if result == "ignored":
		status.text = "Tap Listen before answering." if lesson.phase == "ready" else status.text
		return
	_play_note(route_index - 1)
	if lesson.score > previous_score:
		_award_feedback(lesson.score - previous_score, player.global_position + Vector3.UP * 1.4)
	match result:
		"retry": status.text = "Try that melody again from its first note. Listen is always available."
		"correct": status.text = "Correct! Choose note %d of %d." % [lesson.answer_index + 1, lesson.melody().size()]
		"round": status.text = "Melody complete! Tap Listen for melody %d of 3." % [lesson.round_index + 1]
	if lesson.stage >= 2:
		var length := 4 if lesson.stage == 3 else 3
		memory_marks = lesson.answer_index if result == "correct" else (length if result in ["round", "complete"] else 0)
		if result == "correct": status.text = "Correct! Jump to the next note · %d / %d" % [memory_marks, length]
		if result == "retry":
			active_arena().wobble(route_index - 1)
			memory_return_delay = 0.60
			memory_return_text = "Try again, or tap the lantern to listen again." if lesson.stage == 3 else "Try again, or tap the centre glade to listen again."
			status.text = "Not quite! Back to the centre for another try."
		elif result == "round":
			if lesson.stage == 3: _start_concert_passage()
			else:
				memory_return_delay = 0.45
				memory_return_text = "Melody complete! Tap the glade for melody %d of 3." % (lesson.round_index + 1)
		elif result == "complete" and lesson.stage == 3: canopy.finish()
	_update_lesson_hud()
	_check_completion()

func _check_completion() -> void:
	_update_lesson_hud()
	if lesson.phase != "complete": return
	queued_direction = 0
	_save_progress()
	status.text = "Stage complete! %d points · %d stars · choose your next stage" % [lesson.score, lesson.stars]
	if not OS.has_feature("web"):
		var completed_attempt := attempt_id
		get_tree().create_timer(0.95).timeout.connect(func():
			if completed_attempt == attempt_id and lesson.phase == "complete":
				_show_success()
				celebrate())

func _set_volume(value: float) -> void:
	var gain := clampf(value, 0, 1)
	audio.volume_db = linear_to_db(maxf(gain, 0.00001))
	success_audio.volume_db = audio.volume_db
	audio.volume_linear = gain
	success_audio.volume_linear = gain

func celebrate() -> void:
	if lesson.phase != "complete" or celebrated_attempt == attempt_id: return
	celebrated_attempt = attempt_id
	audio.stop()
	success_audio.play()

func _show_success() -> void:
	success_heading.text = "HURRAY!\nStage %d complete!" % lesson.stage
	success_stars.text = "★ ".repeat(lesson.stars) + "☆ ".repeat(3 - lesson.stars)
	success_summary.text = "Well done! You earned %d points.\n%s" % [lesson.score, "Stage %d is unlocked!" % (lesson.stage + 1) if lesson.stage < 3 else "You completed the whole musical journey!"]
	next_stage_button.text = "Next stage  →" if lesson.stage < 3 else "Play again  →"
	success_overlay.show()

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
	if native_markers:
		native_panel.offset_top = -172 if lesson.stage >= 2 else -230
		native_stages.visible = lesson.stage == 1
		native_hint.visible = lesson.stage == 1
		native_repeat.visible = lesson.stage == 1
		native_listen.visible = lesson.stage == 1
		lesson_label.visible = lesson.stage == 1
		native_markers.visible = lesson.stage >= 2
		native_markers.text = "● ".repeat(memory_marks) + "○ ".repeat((4 if lesson.stage == 3 else 3) - memory_marks)
		native_step_row.visible = lesson.stage == 1
		native_choose_button.visible = lesson.stage == 1
		native_hint.text = "Click a platform / 1–8: jump · L: listen · R: retry · P: pause" if lesson.stage == 2 else "Arrows / WASD: hop · Space: hear note · Enter: choose · L: listen · R: retry stage"
	if reward_counter:
		reward_counter.text = "%d  POINTS" % lesson.score
		gem_counter.text = "◆  %d / 8 GEMS" % lesson.collected.size() if lesson.stage == 1 else "♪  %d / 3 MELODIES" % mini(lesson.round_index, 3)
	if lesson_label:
		lesson_label.text = "Stage %d: %s · %d points · Best total: %d" % [lesson.stage, lesson.TITLES[lesson.stage-1], lesson.score, lesson.total()]
	for i in range(stage_buttons.size()): stage_buttons[i].disabled = i + 1 > lesson.unlocked()

func _make_collectibles() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	# Eight flat faces make a readable gemstone, even on a small phone screen.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var equator := [Vector3(0.28, 0, 0), Vector3(0, 0, 0.28), Vector3(-0.28, 0, 0), Vector3(0, 0, -0.28)]
	var colors := [Color("fff4b0"), Color("ffd166"), Color("f0a83b"), Color("ffe895")]
	for i in range(4):
		builder.set_color(colors[i])
		for vertex in [Vector3(0, 0.44, 0), equator[(i + 1) % 4], equator[i]]: builder.add_vertex(vertex)
		builder.set_color(colors[(i + 2) % 4])
		for vertex in [Vector3(0, -0.34, 0), equator[i], equator[(i + 1) % 4]]: builder.add_vertex(vertex)
	builder.generate_normals()
	var mesh := builder.commit()
	for pad in pads:
		var orb := MeshInstance3D.new()
		orb.mesh = mesh
		orb.material_override = material
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(orb)
		orb.global_position = pad.global_position + Vector3.UP * 1.15
		collectibles.append(orb)

func toggle_camera() -> void:
	if lesson.stage >= 2: return
	camera.overview = not camera.overview
	if camera_button: camera_button.text = "Follow view · C" if camera.overview else "Wide view · C"

func _award_feedback(amount: int, origin: Vector3) -> void:
	reward_id += 1
	var point := camera.unproject_position(origin)
	var viewport_size := get_viewport().get_visible_rect().size
	last_reward = {"id": reward_id, "amount": amount, "from": [clampf(point.x / viewport_size.x, 0.05, 0.95), clampf(point.y / viewport_size.y, 0.08, 0.90)]}
	if OS.has_feature("web"): return
	var spark := Label.new()
	spark.text = "◆  +%d" % amount
	spark.add_theme_font_size_override("font_size", 32)
	spark.add_theme_color_override("font_color", Color("ffde86"))
	spark.add_theme_color_override("font_outline_color", Color("173e35"))
	spark.add_theme_constant_override("outline_size", 6)
	reward_effects.add_child(spark)
	spark.position = point - Vector2(35, 30)
	var flight := spark.create_tween()
	flight.tween_property(spark, "position", spark.position + Vector2(0, -48), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(spark, "position", reward_counter.global_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(spark, "modulate:a", 0.0, 0.18)
	flight.tween_callback(spark.queue_free)

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
	var top := PanelContainer.new()
	layer.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 18
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("173e35")
	top_style.set_corner_radius_all(18)
	top_style.set_content_margin_all(14)
	top.add_theme_stylebox_override("panel", top_style)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	gem_counter = Label.new()
	gem_counter.add_theme_font_size_override("font_size", 24)
	gem_counter.add_theme_color_override("font_color", Color("ffde86"))
	top_row.add_child(gem_counter)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	camera_button = _button(top_row, "Wide view · C", toggle_camera)
	reward_counter = Label.new()
	reward_counter.add_theme_font_size_override("font_size", 28)
	reward_counter.add_theme_color_override("font_color", Color("ffde86"))
	top_row.add_child(reward_counter)
	reward_effects = Control.new()
	reward_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(reward_effects)
	var panel := PanelContainer.new()
	native_panel = panel
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
	native_stages = stages
	stages.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stages)
	for i in range(3): stage_buttons.append(_button(stages, "Stage %d" % (i+1), start_stage.bind(i+1)))
	status = Label.new()
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("fff0ce"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	var hint := Label.new()
	native_hint = hint
	hint.text = "Arrows / WASD: hop · Space: hear note · Enter: choose · L: listen · R: retry stage"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 19)
	box.add_child(hint)
	native_markers = Label.new()
	native_markers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	native_markers.add_theme_font_size_override("font_size", 26)
	native_markers.add_theme_color_override("font_color", Color("ffdc86"))
	box.add_child(native_markers)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	native_step_row = HBoxContainer.new()
	row.add_child(native_step_row)
	_button(native_step_row, "← Back", request_step.bind(-1))
	_button(native_step_row, "Next →", request_step.bind(1))
	native_repeat = _button(row, "Repeat · Space", repeat_note)
	native_choose_button = _button(row, "Choose", choose_note)
	native_listen = _button(row, "Listen", listen_melody)
	native_hint_button = _button(row, "Show hint", listen_melody.bind(true))
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
	volume.value_changed.connect(_set_volume)
	row.add_child(volume)
	if not OS.has_feature("web"):
		native_glade = Button.new()
		layer.add_child(native_glade)
		native_glade.size = Vector2(160, 100)
		native_glade.add_theme_font_size_override("font_size", 23)
		native_glade.add_theme_color_override("font_color", Color("ffdf81"))
		native_glade.add_theme_color_override("font_disabled_color", Color("f5eccb"))
		for state in ["normal", "hover", "pressed", "disabled"]:
			native_glade.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		native_glade.pressed.connect(listen_melody)
	_make_success_overlay(layer)

func _make_success_overlay(layer: CanvasLayer) -> void:
	success_overlay = Control.new()
	layer.add_child(success_overlay)
	success_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.09, 0.06, 0.78)
	success_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	success_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff3d4")
	style.border_color = Color("edbd59")
	style.set_border_width_all(6)
	style.set_corner_radius_all(30)
	style.set_content_margin_all(30)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	success_heading = Label.new()
	success_stars = Label.new()
	success_summary = Label.new()
	for label in [success_heading, success_stars, success_summary]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("173e35"))
		box.add_child(label)
	success_heading.add_theme_font_size_override("font_size", 40)
	success_stars.add_theme_font_size_override("font_size", 54)
	success_stars.add_theme_color_override("font_color", Color("c88a18"))
	success_summary.add_theme_font_size_override("font_size", 24)
	next_stage_button = _button(box, "Next stage →", func():
		if lesson.stage < 3: advance_stage()
		else: start_stage(1))
	next_stage_button.custom_minimum_size.y = 72
	next_stage_button.add_theme_font_size_override("font_size", 30)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("3f823a")
	button_style.border_color = Color("bde77c")
	button_style.set_border_width_all(3)
	button_style.set_corner_radius_all(18)
	next_stage_button.add_theme_stylebox_override("normal", button_style)
	_button(box, "Replay this stage", func(): start_stage(lesson.stage))
	success_overlay.hide()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 38)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
