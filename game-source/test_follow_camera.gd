extends SceneTree
## Exercise the actual scene so camera, pickups and reset logic stay connected.
var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	if not value: failures.append(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("MelodyController")
	var camera = scene.get_node("GameCamera")
	# Advance deterministically without writing to the player's saved progress.
	game.set_process(false)
	camera.set_process(false)
	game.lesson = load("res://lesson.gd").new()
	game.start_stage(1)
	var initial: Vector3 = camera.position
	var initial_size: float = camera.size
	for step in range(1, 8):
		game.cooldown = 0
		game.request_step(1)
		for frame in range(40):
			game._process(1.0 / 60.0)
			camera._process(1.0 / 60.0)
		var projected: Vector2 = camera.unproject_position(game.player.global_position)
		var rect: Rect2 = root.get_visible_rect()
		check(rect.has_point(projected), "Player remains visible on step %d" % step)
		check(game.lesson.score == step * 10, "Pickup counts once on step %d" % step)
		check(not game.collectibles[step - 1].visible, "Collected gem disappears")
	check(camera.position.distance_to(initial) > 5, "Camera travels with the player")
	check(game.last_reward.amount == 10, "Reward event contains +10")
	var reward: int = game.reward_id
	game.cooldown = 0
	game.request_step(-1)
	for frame in range(40): game._process(1.0 / 60.0)
	check(game.reward_id == reward and game.lesson.score == 70, "Revisiting does not create a reward")
	game.paused = true
	var paused_position: Vector3 = camera.position
	camera._process(1)
	check(camera.position == paused_position, "Paused camera does not drift")
	game.paused = false
	game.toggle_camera()
	for frame in range(120): camera._process(1.0 / 60.0)
	check(camera.size > initial_size * 1.5, "Wide view reveals the forest")
	game.start_stage(1)
	check(camera.position.is_equal_approx(initial), "Retry returns camera to the starting platform")
	check(game.lesson.score == 0 and game.last_reward.is_empty(), "Retry clears attempt rewards")
	check(game.reward_counter.text == "0  POINTS", "Native wallet resets")
	for gem in game.collectibles: check(gem.visible, "Retry restores gems")
	game.lesson.records[0].complete = true
	game.start_stage(2)
	game.listen_melody()
	check(camera.is_overview(), "Listening automatically opens wide view")
	game.lesson.demo_finished()
	check(not camera.is_overview(), "Answering returns to follow view")
	if failures.is_empty(): print("PASS: moving camera, framing, unique pickups, pause, wide view, retry and melody overview")
	else:
		for failure in failures: push_error(failure)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
