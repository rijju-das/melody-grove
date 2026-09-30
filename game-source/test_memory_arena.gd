extends SceneTree
var failures: Array[String] = []
var game: Node
var camera: Camera3D
var heard: Array[int] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func tick(seconds: float) -> void:
	for frame in range(ceili(seconds * 60)):
		game._process(1.0 / 60.0)
		camera._process(1.0 / 60.0)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	game = scene.get_node("MelodyController")
	camera = scene.get_node("GameCamera")
	game.set_process(false)
	camera.set_process(false)
	game.lesson = load("res://lesson.gd").new()
	for note in range(8): game.lesson.explore(note)
	game.start_stage(2)
	game.note_played.connect(func(note: int): heard.append(note))
	check(game.player.global_position.is_equal_approx(game.memory_arena.center), "Character starts in the middle")
	check(game.pads.size() == 8, "Eight surrounding notes")
	check(not game.native_choose_button.visible, "No native Choose button")
	game.request_note(0)
	check(not game.hopping, "Listen is required before answering")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = camera.unproject_position(game.memory_arena.center)
	game._unhandled_input(tap)
	check(game.lesson.phase == "listening", "Tapping the centre glade starts playback")
	check(game._glade_target().size() == 3, "Web receives the projected glade target")
	game._process(0.01)
	check(game.memory_arena.rings[0].visible, "Demo lights Do")
	game.request_note(7)
	check(not game.hopping, "Input blocked during playback")
	tick(3.3)
	check(heard == [0, 2, 4], "Glowing playback follows the melody")
	check(game.lesson.phase == "answer", "Answer phase begins after listening")
	for ring in game.memory_arena.rings: check(not ring.visible, "Demo lights fade")
	game.request_note(0)
	game.request_note(7)
	tick(0.6)
	check(game.route_index == 1 and game.lesson.answer_index == 1, "Landing auto-submits once; extra in-flight input ignored")
	check(game.memory_marks == 1, "First progress marker fills")
	# A direct cross-arena jump must not visit intervening notes.
	game.request_note(2)
	tick(0.2)
	var paused_position: Vector3 = game.player.global_position
	game.toggle_pause()
	tick(0.5)
	check(game.player.global_position == paused_position, "Midair pause holds the character")
	game.toggle_pause()
	tick(0.4)
	check(game.route_index == 3 and game.lesson.answer_index == 2, "Do jumps directly to Mi")
	game.request_note(4)
	tick(0.55)
	check(game.lesson.score == 30 and game.memory_marks == 3, "Completed melody earns thirty points and three markers")
	tick(1.1)
	check(game.route_index == 0 and game.lesson.round_index == 1, "Next melody starts at the centre")
	game.listen_melody()
	tick(3.4)
	game.request_note(4)
	tick(0.6)
	var position: Vector3 = game.player.global_position
	game.request_note(4)
	tick(0.25)
	check(game.player.global_position.y > position.y + 0.5, "Tapping current note jumps in place")
	tick(0.3)
	check(game.lesson.mistakes == 1 and game.memory_arena.wobble_time > 0, "Wrong note produces a wobble and one mistake")
	tick(1.2)
	check(game.route_index == 0 and game.lesson.answer_index == 0 and game.lesson.score == 30, "Wrong choice resets only current melody, retaining earned points")
	game.request_note(4)
	tick(0.6)
	game.listen_melody()
	check(game.hopping, "Listen again returns to centre")
	tick(4)
	check(game.route_index == 0 and game.lesson.phase == "answer" and game.lesson.answer_index == 0 and game.lesson.mistakes == 1, "Replay is free and restarts the phrase")
	game.start_stage(2)
	check(game.memory_marks == 0 and game.memory_return_delay == 0 and not game.hopping, "Stage retry clears feedback and movement")
	if failures.is_empty(): print("PASS: central start, glow sequence, direct jumps, auto answers, same-note jumps, markers, wrong-answer recovery, replay, pause and points")
	else:
		for failure in failures: push_error(failure)
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
