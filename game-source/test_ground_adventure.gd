extends SceneTree
class NoSaveController extends "res://melody_controller.gd":
	func _save_progress() -> void: pass
	func _load_progress() -> void: pass
var game: Node
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func frames(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		game._process(1.0/60)
		game.camera._process(1.0/60)
		check(absf(game.player.global_position.y-.06)<.001,"Explorer must remain on the ground")
func settle() -> void:
	for i in range(1800):
		if not game.hopping and not game.transitioning and game.memory_return_delay <= 0: return
		frames(1.0/60)
	check(false,"Movement failed to settle within 30 seconds")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	game = scene.get_node("MelodyController")
	game.set_script(NoSaveController)
	root.add_child(scene)
	current_scene = scene
	game.set_process(false)
	game.camera.set_process(false)
	check(game.lesson.unlocked()==1,"Fresh ground adventure keeps later stages locked")
	var start: Vector3 = game.player.global_position
	Input.action_release("grove_forward")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	frames(.5)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(game.player.global_position.distance_to(start)>1.5,"Keyboard moves freely without selecting a note")
	game.start_stage(1)
	game.request_note(0)
	frames(.15)
	game.toggle_pause()
	var frozen: Vector3 = game.player.global_position
	frames(.5)
	check(game.player.global_position==frozen,"Pause freezes walking")
	game.toggle_pause()
	settle()
	check(game.lesson.score==10,"Walking onto a flower earns its gem")
	game.request_note(0);settle()
	check(game.lesson.score==10,"Repeated flowers cannot farm gems")
	# Ground tap, not a note command, routes the character and activates after a pause.
	var point: Vector3 = game.route[2]
	game.walker.tap(game.camera.unproject_position(point))
	settle(); frames(.4)
	check(game.lesson.score==20,"Tap-to-walk chooses a flower after the dwell")
	check(not game.walker.walk_to(start+Vector3(100,0,0)),"Out-of-bounds taps stay out of the scenery")
	for i in range(2,8): game.request_note(i);settle()
	check(game.lesson.phase=="complete" and game.lesson.score==80,"Meadow completes with all eight flowers")
	game.advance_stage();settle()
	check(game.lesson.stage==2,"Continuous passage enters Echo Clearing")
	check(not game.walker.walk_to(game.memory_arena.center+Vector3(0,0,-1.5)),"Hollow tree blocks walking")
	game.listen_melody();frames(4)
	game.request_note(7);settle()
	check(game.lesson.mistakes==1 and game.route_index==0,"Wrong melody returns to the clearing")
	for stage in [2,3]:
		if stage==3: game.advance_stage();settle()
		check(game.lesson.stage==stage,"Stage passage preserves lesson progression")
		for round_number in range(3):
			game.listen_melody();frames(5)
			var notes: Array = game.lesson.melody()
			for note in notes:
				game.request_note(note)
				settle()
			check(game.lesson.round_index==round_number+1,"Melody advances exactly once")
		check(game.lesson.phase=="complete","Memory stage completes")
	check(game.ground.restored==3,"All three brook sections are restored")
	game.advance_stage();settle()
	check(game.lesson.stage==4,"Ground route reaches Singing Tree")
	var singing_spot: Vector3 = game.player.global_position
	game.singing.command("mic_on")
	for step in range(5):
		game.listen_melody();frames(1.6)
		game.singing.sample(game.singing.target_frequency()*1.15);frames(.2)
		check(game.lesson.round_index==step,"Wrong pitch does not open a blossom")
		for i in range(40):
			game.singing.sample(game.singing.target_frequency())
			frames(1.0/60)
		check(game.lesson.round_index==step+1,"Sustained pitch opens the next blossom")
		check(game.player.global_position==singing_spot,"Singing opens branches without jumping")
	check(game.lesson.phase=="complete" and game.lesson.score==100,"Five sung notes finish the adventure")
	check(game.stairway.complete_count==5,"All five branches blossom")
	game.start_stage(1)
	check(game.lesson.unlocked()==4,"Unlocked stages remain replayable")
	print("GROUND ADVENTURE: %d failures" % failures)
	scene.free()
	quit(1 if failures else 0)
