extends SceneTree
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("MelodyController")
	var camera = scene.get_node("GameCamera")
	game.set_process(false)
	camera.set_process(false)
	game.lesson = load("res://lesson.gd").new()
	game.start_stage(1)
	var original: Node3D = game.stage_path.sections[0]
	for child in original.find_children("*", "MeshInstance3D", true, false):
		var relative := original.get_path_to(child)
		for section in game.stage_path.sections.slice(1):
			check(section.get_node(relative).mesh == child.mesh, "Repeated forest retains mesh for " + str(relative))
	var origin: Vector3 = game.route[0]
	game.advance_stage()
	check(not game.transitioning, "Cannot skip an unfinished stage")
	for note in range(8): game.lesson.explore(note)
	game.route_index = 8
	game.player.global_position = game.route[8]
	game._show_success()
	check(game.success_overlay.visible, "Native celebration is visible")
	check(game.next_stage_button.text.contains("Next stage"), "Next stage button appears")
	game._set_volume(0)
	game.celebrate()
	check(game.success_audio.volume_linear == 0, "Victory sound respects mute")
	var first: int = game.celebrated_attempt
	game.celebrate()
	check(game.celebrated_attempt == first, "One celebration per attempt")
	game._set_volume(0.4)
	check(is_equal_approx(game.success_audio.volume_linear, 0.4), "Victory sound follows volume")
	game.advance_stage()
	check(game.transitioning and not game.success_overlay.visible, "Next stage closes the card and starts walking")
	check(not game.success_audio.playing, "Walking stops the victory sound")
	game._process(0.1)
	game.toggle_pause()
	var stopped: Vector3 = game.travel_position
	game._process(0.5)
	check(game.travel_position == stopped, "Transition pauses")
	game.toggle_pause()
	for frame in range(500):
		if not game.transitioning: break
		var before: Vector3 = game.player.global_position
		game._process(1.0 / 60.0)
		camera._process(1.0 / 60.0)
		check(game.player.global_position.distance_to(before) < 0.3, "Continuous movement without teleporting")
	check(game.lesson.stage == 2 and not game.transitioning, "Arrives in stage two")
	check(game.route[0].distance_to(origin) > 25, "Next stage is in a new forest section")
	check(game.stage_path.opened[0] == 1, "Trees open completely")
	check(game.stage_path.sections[1].visible and not game.stage_path.sections[0].visible, "Only current forest stays rendered after arrival")
	check(game.lesson.score == 0 and game.lesson.total() == 80, "Arrival preserves best score and resets new stage score")
	for melody in [[0,2,4],[4,2,0],[0,1,2]]:
		game.lesson.listen()
		game.lesson.demo_finished()
		for note in melody: game.lesson.submit(note)
	game.route_index = 3
	game.player.global_position = game.route[3]
	game.advance_stage()
	check(game.travel_points.size() == 6, "Walk follows remaining platforms before second bridge")
	for frame in range(900):
		if not game.transitioning: break
		game._process(1.0 / 60.0)
		camera._process(1.0 / 60.0)
	check(game.lesson.stage == 3 and game.stage_path.opened[1] == 1, "Second passage reaches stage three")
	game.start_stage(1)
	check(game.player.global_position.is_equal_approx(origin), "Menu replay returns to the correct forest")
	check(not game.success_overlay.visible and not game.success_audio.playing, "Replay clears victory screen and audio")
	if failures.is_empty(): print("PASS: victory card, volume/mute, single celebration, both tree passages, continuous movement, pause, scoring and replay")
	else:
		for failure in failures: push_error(failure)
	scene.queue_free()
	await process_frame
	# Let the audio thread release its stopped WAV playback before shutdown.
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
