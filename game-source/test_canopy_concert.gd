extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: saved_ok = true

var failures: Array[String] = []
var game: Node
var camera: Camera3D
var glow: Array[bool] = []
var leaked_names: Array[String] = []

func check(condition: bool, description: String) -> void:
	if not condition: failures.append(description)

func tick(seconds: float) -> void:
	for frame in range(ceili(seconds * 60)):
		game._process(1.0 / 60)
		camera._process(1.0 / 60)

func demo(hint := false) -> void:
	glow.clear()
	leaked_names.clear()
	game.listen_melody(hint)
	tick(5.0)
	check(game.lesson.phase == "answer", "Demo finishes and accepts input")

func jump(note: int) -> void:
	game.request_note(note)
	tick(0.55)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_node("MelodyController").set_script(NoSaveController)
	root.add_child(scene)
	await process_frame
	game = scene.get_node("MelodyController")
	camera = scene.get_node("GameCamera")
	game.set_process(false)
	camera.set_process(false)
	game.lesson = load("res://lesson.gd").new()
	for i in range(2): game.lesson.records[i].complete = true
	game.start_stage(3)
	game.note_played.connect(func(_index):
		if game.lesson.phase == "listening":
			glow.append(game.halo.visible)
			if not game._reveal_demo_note() and game.status.text != "Listen carefully…": leaked_names.append(game.status.text)
	)
	check(game.canopy.arenas.size() == 3 and game.pads.size() == 8, "Three clearings with eight playable notes")
	check(game.player.global_position == game.canopy.arenas[0].center, "Start at first lantern")
	check(game.canopy.growth == [0.0, 0.0], "Bridges are initially locked")
	demo()
	check(glow == [true, true, true, true], "First clearing glows for every note")
	for note in [0, 2, 4, 2]: jump(note)
	check(game.lesson.score == 40 and game.concert_moving, "First melody earns forty and grows a bridge")
	tick(0.4)
	check(game.canopy.growth[0] > 0 and game.canopy.growth[0] < 1, "Bridge grows gradually")
	game.toggle_pause()
	var position: Vector3 = game.player.global_position
	var growth: float = game.canopy.growth[0]
	tick(1)
	check(game.player.global_position == position and game.canopy.growth[0] == growth, "Pause freezes growth and crossing")
	game.toggle_pause()
	for frame in range(1000):
		if not game.transitioning: break
		var previous: Vector3 = game.player.global_position
		tick(1.0 / 60)
		check(previous.distance_to(game.player.global_position) < 0.3, "Crossing never teleports")
	check(game.canopy_index == 1 and game.canopy.growth[0] == 1, "Arrives at second clearing")
	demo()
	check(glow == [true, false, false, false] and leaked_names.is_empty(), "Second clearing only reveals first note")
	jump(0)
	tick(1.2)
	check(game.route_index == 0 and game.lesson.score == 40 and game.lesson.mistakes == 1, "Wrong note returns to centre and retains score")
	demo(true)
	check(glow == [true, true, true, true] and game.lesson.mistakes == 1, "Hint reveals all notes without penalty")
	for note in [2, 3, 4, 7]: jump(note)
	tick(10)
	check(game.canopy_index == 2 and game.lesson.score == 80 and not game.transitioning, "Second bridge reaches final clearing")
	demo()
	check(glow == [false, false, false, false] and leaked_names.is_empty(), "Final melody has no visual answer leaks")
	jump(7)
	demo(true)
	check(game.route_index == 0 and game.lesson.answer_index == 0 and glow == [true, true, true, true], "Hint from a note returns to lantern and replays")
	for note in [7, 4, 2, 0]: jump(note)
	check(game.lesson.score == 145 and game.lesson.stars == 2 and game.lesson.phase == "complete", "Final score and stars preserve existing rules")
	check(game.canopy.celebrating, "Final melody lights the canopy")
	for bird in game.canopy.creatures: check(bird.visible, "Birds join the finale")
	game.start_stage(3)
	check(game.canopy_index == 0 and game.canopy.growth == [0.0, 0.0] and not game.canopy.celebrating, "Retry resets all clearings and bridges")
	check(game.lesson.records[2].score == 145, "Retry preserves best score")
	if failures.is_empty(): print("PASS: three clearings, fading clues, free hints, direct jumps, bridge growth, continuous crossing, pause, recovery, 145 points, finale and retry")
	else:
		for failure in failures: push_error(failure)
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
