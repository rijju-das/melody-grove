extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../../godot-diagnostics")
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("storybook-" + label + ".png"))
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	assert(scene.get_node("Player/StorybookExplorer") != null, "New character is present before runtime setup")
	assert(not scene.get_node("Melody Grove • musical forest/MS_Player").visible, "Old character is hidden in the saved scene")
	var game = scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	current_scene = scene
	game.lesson.restore({"version":1,"records":[80,120,150,100].map(func(score): return {"complete":true,"score":score,"stars":3})})
	assert(game.limbs.size() == 4, "All four explorer limb pivots are connected")
	var rig = game.player.get_node("StorybookExplorer")
	assert(rig.find_child("ExplorerEyeL", true, false) != null)
	var camera = scene.get_node("GameCamera")
	for stage in range(1,5):
		game.start_stage(stage)
		for i in range(120): camera._process(1.0/60.0)
		await capture("stage" + str(stage))
	game.set_process(false)
	game.start_stage(1)
	for note in range(8): game.lesson.explore(note)
	game.route_index = 8
	game.player.global_position = game.route[8]
	game.advance_stage()
	for frame in range(900):
		if not game.transitioning: break
		game._process(1.0 / 60.0)
	assert(game.lesson.stage == 2 and not game.transitioning)
	assert(game.player.is_visible_in_tree() and rig.is_visible_in_tree(), "Explorer stays visible across forest transitions")
	assert(game.player.get_parent() == scene, "Player stays outside duplicated forest sections")
	game.start_stage(1)
	camera.set_process(false)
	camera.position = game.player.global_position + Vector3(3.5, 2.7, 5)
	camera.look_at(game.player.global_position + Vector3.UP * 1.35)
	camera.size = 4.3
	for child in game.get_children():
		if child is CanvasLayer: child.hide()
	await capture("explorer")
	print("PASS: four stages render with the Blender explorer and connected animation pivots")
	scene.queue_free()
	await process_frame
	quit()
