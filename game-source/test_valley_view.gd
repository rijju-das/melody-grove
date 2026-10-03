extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass
func _initialize() -> void:
	call_deferred("run")
	create_timer(60.0).timeout.connect(func(): push_error("Valley test timed out"); quit(1))
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../godot-diagnostics/valley-"+label+".png"))
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	var game = scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	current_scene = scene
	game.lesson.restore({"version":1,"records":[80,120,150,100].map(func(score): return {"complete":true,"score":score,"stars":3})})
	var camera: Camera3D = scene.get_node("GameCamera")
	for stage in range(1,5):
		game.start_stage(stage)
		for i in range(30):
			game.paused = false
			await process_frame
		var times: Array[float] = []
		var start := Time.get_ticks_usec()
		var last := start
		for i in range(90):
			game.paused = false
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now-last)/1000.0)
			last = now
		times.sort()
		print("STAGE %d: %.1f FPS, p95 %.1f ms, %d draw calls, %.1f MB engine memory" % [stage,90000000.0/(last-start),times[85],Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0])
		await snap("stage"+str(stage))
	game.start_stage(1)
	assert(camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(scene.find_child("ForestValley",true,false) != null)
	for child in game.get_children():
		if child is CanvasLayer: child.hide()
	for i in range(20):
		game.paused = false
		await process_frame
	await snap("welcome")
	root.size = Vector2i(390,844)
	game.start_stage(1)
	for i in range(20):
		game.paused = false
		await process_frame
	assert(camera.is_position_in_frustum(game.player.global_position+Vector3.UP),"Player visible on portrait screen")
	await snap("phone")
	camera.overview = true
	camera._update_camera(1.0)
	assert(camera.projection == Camera3D.PROJECTION_ORTHOGONAL,"Wide view is still available")
	print("PASS: perspective, portrait framing and wide view")
	scene.queue_free()
	await process_frame
	quit()
