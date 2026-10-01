extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	var game = scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	game.lesson.restore({"version":1,"records":[80,120,150].map(func(score): return {"complete":true,"score":score,"stars":3})})
	game.start_stage(4)
	for dimensions in [Vector2i(1152,800),Vector2i(1440,1000)]:
		root.size = dimensions
		for settings in [false,true]:
			game.native_settings_open = settings
			game._update_lesson_hud()
			for i in range(6): await process_frame
			var bounds: Rect2 = root.get_visible_rect()
			for control in [game.native_panel,game.native_voice_panel,game.native_voice_enable,game.native_voice_meters]:
				assert(bounds.encloses(control.get_global_rect()), "Native singing controls must fit inside the window")
			assert(game.native_voice_enable.is_visible_in_tree())
			assert(game.native_panel.is_ancestor_of(game.native_voice_enable), "Microphone action stays in bottom panel")
			assert(game.native_voice_level.size.y < game.native_voice_hold.size.y)
			assert(is_equal_approx(game.native_voice_level.get_global_rect().end.y, game.native_voice_hold.get_global_rect().end.y))
			assert(game.native_voice_panel.position.x > bounds.size.x / 2, "Coach belongs on the right")
			assert(game.native_voice_target.text.begins_with("Do · C4"))
	# The real control changes height while its bottom and the other bar stay fixed.
	game.set_process(false)
	var heights: Array[float] = []
	var baseline: float = game.native_voice_hold.get_global_rect().end.y
	var hold_height: float = game.native_voice_hold.size.y
	for step in range(3):
		game.lesson.round_index = step
		game._process(0)
		heights.append(game.native_voice_level.size.y)
		assert(is_equal_approx(game.native_voice_level.get_global_rect().end.y, baseline))
		assert(is_equal_approx(game.native_voice_hold.size.y, hold_height))
	assert(heights[0] < heights[1] and heights[1] < heights[2], "Entire Do/Re/Mi bar heights must differ")
	game.lesson.round_index = 0
	game.singing.command("voice_range", -1)
	assert(game.singing.target_name() == "Do · C3")
	game.lesson.round_index = 1
	assert(game.singing.target_name() == "Re · D3")
	print("PASS: microphone button and meters fit both window sizes, with Settings open and closed")
	scene.queue_free()
	await process_frame
	quit()
