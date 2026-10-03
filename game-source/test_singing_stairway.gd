extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass

func frames(game: Node, seconds: float) -> void:
	for i in range(ceili(seconds * 60)):
		game._process(1.0 / 60)
		game.camera._process(1.0 / 60)

func _initialize() -> void:
	call_deferred("run")
	create_timer(30).timeout.connect(func(): push_error("Singing check timed out"); quit(1))

func run() -> void:
	var levels: Array[float] = [0.001, 0.001, 0.001, 0.20, 0.001, 0.001]
	assert(preload("res://voice_capture.gd").noise_floor(levels) <= 0.0021, "A setup bump must not mask the voice")
	assert(absf(preload("res://singing_lesson.gd").pitch_error(130.81, 261.625)) < 1, "Low Do is still Do")
	assert(absf(preload("res://singing_lesson.gd").pitch_error(523.25, 261.625)) < 1, "High Do is still Do")
	assert(absf(preload("res://singing_lesson.gd").pitch_error(146.83, 261.625)) > 190, "Re must not count as Do")
	var pcm := PackedFloat32Array()
	for hz in [130.81, 261.63, 329.63]:
		pcm.clear()
		for i in range(820): pcm.append(0.2 * sin(TAU * hz * i / 8820.0) + 0.08 * sin(TAU * hz * i / 4410.0))
		assert(absf(preload("res://voice_capture.gd").detect(pcm, 8820) - hz) < 2)
	var scene = load("res://main.tscn").instantiate()
	var game = scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	game.set_process(false)
	game.camera.set_process(false)
	# Restore legacy three-stage progress without losing stars or scores.
	game.lesson.restore({"version":1,"records":[{"complete":true,"score":80,"stars":3},{"complete":true,"score":120,"stars":3},{"complete":true,"score":150,"stars":3}]})
	assert(game.lesson.unlocked() == 4 and game.lesson.total() == 350)
	game.start_stage(4)
	assert(game.pads.size() == 5 and game.route.size() == 6)
	game.request_note(2)
	assert(not game.hopping, "Tapping cannot answer a singing challenge")
	game.singing.listen()
	assert(game.lesson.phase == "ready", "No microphone means no scored singing")
	game.singing.command("mic_on")
	game.singing.listen()
	for i in range(60): game.singing.sample(game.singing.target_frequency()); frames(game, 1.0 / 60)
	assert(game.lesson.score == 0 and not game.hopping, "Playback cannot score itself")
	frames(game, 0.5)
	assert(game.lesson.phase == "answer")
	# Absolute pitch heights differ by note, and the same frequency never moves with the target.
	for note_step in range(5):
		game.lesson.round_index = note_step
		for offset in [-150.0, 0.0, 150.0]:
			game.singing.sample(game.singing.target_frequency() * pow(2, offset / 1200.0))
			game.singing.has_pitch = true
			game.singing.mic_level = 0.001
			var meter = game.singing.pitch_meter()
			assert(is_equal_approx(meter.value, game.singing.pitch_height(game.singing.frequency)))
			assert(meter.matched == (offset == 0.0))
			game.singing.mic_level = 0.9
			assert(is_equal_approx(meter.value, game.singing.pitch_meter().value))
	var do_height: float = game.singing.pitch_height(261.625565)
	var re_height: float = game.singing.pitch_height(293.664768)
	var mi_height: float = game.singing.pitch_height(329.627557)
	assert(do_height < re_height and re_height < mi_height)
	assert(game.singing.pitch_height(130.8127825) < do_height)
	game.singing.sample(293.664768)
	for step in range(5):
		game.lesson.round_index = step
		assert(is_equal_approx(game.singing.pitch_meter().value, re_height))
	# During reference playback the bar shows the actual note, then clears in the quiet gap.
	game.lesson.phase = "listening"
	game.singing.playback_left = 1.0
	game.lesson.round_index = 2
	assert(game.singing.pitch_meter().reference and is_equal_approx(game.singing.pitch_meter().value, mi_height))
	assert(game.singing.held == 0, "Reference animation cannot fill the jump meter")
	game.singing.playback_left = 0.4
	assert(not game.singing.pitch_meter().active)
	game.lesson.phase = "answer"
	game.lesson.round_index = 0
	game.singing.freshness = 0
	assert(game.singing.pitch_meter().value == 0 and not game.singing.pitch_meter().active)
	for i in range(70): game.singing.sample(game.singing.target_frequency()*1.15); frames(game, 1.0/60)
	assert(game.lesson.score == 0 and game.lesson.mistakes == 0, "Wrong notes get guidance, never penalties")
	game.singing.sample(game.singing.target_frequency())
	frames(game, 0.8)
	assert(not game.hopping, "Stale pitch cannot satisfy the hold")
	for step in range(5):
		if step > 0:
			game.singing.listen()
			frames(game, 1.5)
		for i in range(40):
			var hz: float = game.singing.target_frequency() * (0.5 if step == 0 else 1.0)
			if step == 0 and i >= 16 and i < 22: hz = 0
			game.singing.sample(hz)
			frames(game, 1.0 / 60)
		assert(not game.hopping, "Singing blooms the tree without a jump")
		frames(game, 0.6)
		assert(game.lesson.score == (step + 1) * 20)
		assert(game.stairway.complete_count == step + 1)
	assert(game.lesson.phase == "complete" and game.lesson.total() == 450 and game.lesson.stars == 3)
	assert(not game.singing.enabled)
	game.start_stage(4)
	game.singing.command("practice")
	for step in range(5):
		game.singing.listen(); frames(game, 1.5)
		game.singing.command("practice_next"); frames(game, 0.6)
	assert(game.lesson.phase == "practice_complete" and game.lesson.score == 0 and game.lesson.total() == 450)
	game.start_stage(4)
	game.singing.command("mic_on")
	game.toggle_pause()
	assert(not game.singing.enabled)
	game.toggle_pause()
	game.singing.command("voice_range", -1)
	assert(absf(game.singing.target_frequency() - 130.81) < 0.1)
	game.singing.command("mic_on")
	game.singing.listen()
	frames(game, 1.5)
	assert(game.lesson.phase == "listening", "Lower octave reference must finish before microphone answers")
	frames(game, 0.9)
	assert(game.lesson.phase == "answer")
	# Stage 3's ending must visibly connect to the stairway without resetting rewards.
	game.start_stage(3)
	game.lesson.phase = "complete"
	game.player.global_position = game.canopy.arenas[2].center
	game.advance_stage()
	assert(game.transitioning and game.travel_points[-1] == game.stairway.center)
	frames(game, 10)
	assert(game.lesson.stage == 4 and not game.transitioning)
	print("SINGING TREE PASS: legacy saves, locks, playback guard, pitch hold, gentle retry, five blossoms, rewards, practice isolation, mic pause, range, continuous entry")
	scene.queue_free()
	await process_frame
	quit()
