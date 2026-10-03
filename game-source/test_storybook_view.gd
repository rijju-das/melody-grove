extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass
func _initialize() -> void:
	call_deferred("run")
	create_timer(60).timeout.connect(func(): push_error("Scenery check timed out"); quit(1))
func visible_details(node: Node, result: Array) -> void:
	if node is GeometryInstance3D and node.is_visible_in_tree(): result.append(node)
	for child in node.get_children(): visible_details(child, result)

func check_saved_forest(game: Node) -> void:
	var saved := load("res://editor_forest.scn").instantiate() as Node3D
	var live: Array = []
	visible_details(game.stage_path.sections[0], live)
	visible_details(game.stage_path.bridges[0], live)
	assert(saved.get_child_count() == live.size(), "Editor and runtime have the same visible forest details; regenerate the preview after scenery changes")
	for i in range(live.size()):
		var detail := saved.get_child(i) as GeometryInstance3D
		assert(detail.transform.is_equal_approx(live[i].global_transform), "Editor and runtime scenery positions match")
		if detail is MeshInstance3D:
			assert(detail.mesh.get_aabb().is_equal_approx(live[i].mesh.get_aabb()), "Editor and runtime mesh dimensions match")
		elif detail is MultiMeshInstance3D:
			assert(detail.multimesh.instance_count == live[i].multimesh.instance_count, "Editor and runtime grass counts match")
		elif detail is Label3D:
			assert(detail.text == live[i].text, "Editor and runtime signs match")
		if live[i].material_override is ShaderMaterial:
			assert(detail.material_override is ShaderMaterial)
			assert(detail.material_override.shader.code == live[i].material_override.shader.code, "Wood, ground and water shaders match")
	saved.free()

func capture(label: String) -> void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../../godot-diagnostics")
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("storybook-" + label + ".png"))
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	var preview = scene.get_node("EditorForestPreview")
	assert(preview.visible and preview.get_child_count() > 100, "Saved editor forest is present before runtime setup")
	assert(not scene.get_node("Melody Grove • musical forest").visible, "Old forest is hidden in the editor")
	assert(scene.get_node("Player/StorybookExplorer") != null, "New character is present before runtime setup")
	assert(scene.find_child("MS_Player", true, false) == null, "Old character is absent from the forest asset")
	var game = scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	current_scene = scene
	assert(scene.get_node_or_null("EditorForestPreview") == null, "Static editor preview is removed before gameplay")
	assert(scene.get_node("Melody Grove • musical forest").visible, "Interactive stage one is visible")
	check_saved_forest(game)
	game.lesson.restore({"version":1,"records":[80,120,150,100].map(func(score): return {"complete":true,"score":score,"stars":3})})
	assert(game.limbs.size() == 4, "All four explorer limb pivots are connected")
	assert(scene.find_children("StorybookExplorer", "Node3D", true, false).size() == 1, "There is exactly one playable explorer")
	for section in game.stage_path.sections:
		assert(section.find_child("MS_Player", true, false) == null, "No stage contains the old character")
		assert(section.find_child("MS_Torso", true, false) == null, "No detached old character meshes remain")
	for section in game.stage_path.sections.slice(0, 2):
		assert(section.get_node_or_null("FullBlenderForest") != null, "Full Blender scenery is installed")
		for old_tree in section.find_children("Grove_storybook tree*", "Node3D", true, false):
			assert(not old_tree.visible, "Old round trees are replaced")
	assert(get_nodes_in_group("living_canopy").size() >= 20, "Blender trees decorate all stages")
	var rig = game.player.get_node("StorybookExplorer")
	assert(rig.find_child("ExplorerEyeL", true, false) != null)
	var camera = scene.get_node("GameCamera")
	var living: Node
	for child in game.get_children():
		if child.get_script() == preload("res://storybook_presentation.gd"): living = child.foliage
	assert(living != null and living.ponds.size() == 2 and living.plants.size() > 40)
	game.paused = false
	var flower: Node3D
	for item in living.plants:
		if item.node.is_visible_in_tree():
			flower = item.node
			break
	assert(flower != null, "Visible Blender foliage is present")
	var before: Vector3 = flower.rotation
	living._process(0.5)
	assert(not flower.rotation.is_equal_approx(before), "Blender flowers move while playing")
	var clock: float = living.elapsed
	var water_clock: float = living.ponds[0].material.get_shader_parameter("breeze_time")
	before = flower.rotation
	game.paused = true
	living._process(0.5)
	assert(living.elapsed == clock and flower.rotation == before, "Pause freezes foliage")
	assert(living.ponds[0].material.get_shader_parameter("breeze_time") == water_clock, "Pause freezes ripples")
	game.paused = false
	game.stage_path.show_stage(2)
	before = flower.rotation
	living._process(0.5)
	assert(flower.rotation == before, "Hidden-stage foliage is not animated")
	game.stage_path.show_stage(1)
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
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = game.player.global_position + Vector3(3.5, 2.7, 5)
	camera.look_at(game.player.global_position + Vector3.UP * 1.35)
	camera.size = 4.3
	for child in game.get_children():
		if child is CanvasLayer: child.hide()
	await capture("explorer")
	camera.position = Vector3(-1.8052565, 25, 25.872365)
	camera.rotation = Vector3(-0.657394, 0, 0)
	camera.size = 32.0
	for title in ["MS_Title", "MS_Subtitle"]:
		var label := scene.find_child(title, true, false) as Node3D
		if label: label.hide()
	for bridge in game.stage_path.bridges: bridge.hide()
	await capture("welcome")
	print("PASS: four stages, connected explorer, Blender foliage, paused/hidden animation and pond clocks")
	scene.queue_free()
	await process_frame
	quit()
