extends SceneTree
## Regenerate the saved editor view from the same builders used during play.
## Run headless with --path game-source --script test_bake_editor_forest.gd.
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass

func _initialize() -> void:
	call_deferred("run")

func copy_visible(source: Node, target: Node3D) -> void:
	if source is GeometryInstance3D and source.is_visible_in_tree():
		var item := source.duplicate(0) as GeometryInstance3D
		for child in item.get_children():
			child.free()
		item.set_script(null)
		item.scene_file_path = ""
		item.name = "Detail%04d_%s" % [target.get_child_count(), str(source.name).validate_node_name()]
		target.add_child(item)
		item.owner = target
		item.transform = source.global_transform
	for child in source.get_children():
		copy_visible(child, target)

func run() -> void:
	var scene := load("res://main.tscn").instantiate() as Node3D
	var game := scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	current_scene = scene
	if game.stage_path.sections[0].get_node_or_null("FullBlenderForest/ForestValley") == null:
		push_error("Scenery failed to build; keeping the previous editor preview.")
		scene.free()
		quit(1)
		return
	var preview := Node3D.new()
	preview.name = "EditorForestPreview"
	copy_visible(game.stage_path.sections[0], preview)
	copy_visible(game.stage_path.bridges[0], preview)
	assert(preview.get_child_count() > 100, "The saved view contains the complete starting forest")
	var packed := PackedScene.new()
	assert(packed.pack(preview) == OK)
	assert(ResourceSaver.save(packed, "res://editor_forest.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	print("Saved editor forest: %d visible details" % preview.get_child_count())
	preview.free()
	scene.queue_free()
	await process_frame
	quit()
