extends RefCounted
## Grounded movement: camera-relative keyboard input and routed tap-to-walk.
const SPEED := 4.2
const HEIGHT := .06
var game: Node
var points: PackedVector3Array = []
var note_target := -1
var latched := -1
var dwell := 0.0
var age := 0.0
var moving := false
var origin := Vector3.ZERO
var bounds := Rect2()
var grid := AStarGrid2D.new()

func setup(controller: Node) -> void: game = controller

func reset() -> void:
	points.clear()
	note_target = -1
	latched = -1
	dwell = 0
	moving = false
	origin = game.stage_path.sections[0].global_position if game.lesson.stage == 1 else game.active_arena().center
	bounds = Rect2(-11,-8,24,14) if game.lesson.stage == 1 else Rect2(-7,-7,14,14)
	grid.region = Rect2i(Vector2i(bounds.position*2),Vector2i(bounds.size*2)+Vector2i.ONE)
	grid.cell_size = Vector2(.5,.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	# Hollow tree trunk is a real obstacle; the surrounding flowers stay accessible.
	if game.lesson.stage == 2:
		for x in range(-1,2):
			for z in range(-4,-1): grid.set_point_solid(Vector2i(x,z))
	if game.lesson.stage == 4:
		for x in range(-2,3):
			for z in range(-10,-5): grid.set_point_solid(Vector2i(x,z))

func flat(at: Vector3) -> Vector3: return Vector3(at.x,HEIGHT,at.z)

func walk_to(at: Vector3, note := -1) -> bool:
	var local := Vector2(at.x-origin.x,at.z-origin.z)
	if not bounds.has_point(local): return false
	var end := Vector2i((local*2).round())
	var start := Vector2i((Vector2(game.player.global_position.x-origin.x,game.player.global_position.z-origin.z)*2).round())
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end) or grid.is_point_solid(end): return false
	var path := grid.get_point_path(start,end)
	if path.is_empty(): return false
	points.clear()
	for p in path: points.append(flat(origin+Vector3(p.x,0,p.y)))
	points.append(flat(at))
	note_target = note
	game.destination = note if note >= 0 else game.route_index
	game.hopping = true # Existing UI lock means travelling; no airborne arc.
	return true

func tap(screen: Vector2) -> void:
	if game.paused or game.transitioning or game.lesson.phase in ["listening","complete","practice_complete"] or game.memory_return_delay > 0: return
	var ray: Vector3 = game.camera.project_ray_normal(screen)
	if ray.y >= -.01: return
	var start: Vector3 = game.camera.project_ray_origin(screen)
	var at := start + ray*((HEIGHT-start.y)/ray.y)
	walk_to(at)

func allowed(at: Vector3) -> bool:
	var local := Vector2(at.x-origin.x,at.z-origin.z)
	if not bounds.has_point(local): return false
	var cell := Vector2i((local*2).round())
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

func tick(delta: float, allow_keys := true) -> void:
	age += delta
	var previous: Vector3 = game.player.global_position
	var axis := Vector2.ZERO
	if allow_keys:
		axis = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if axis.length() > 0:
		points.clear()
		note_target = -1
		var right: Vector3 = game.camera.global_basis.x
		right.y = 0
		var forward: Vector3 = game.camera.global_basis.z
		forward.y = 0
		var direction := (right.normalized()*axis.x+forward.normalized()*axis.y).normalized()
		var at := flat(previous+direction*SPEED*delta)
		if allowed(at): game.player.global_position = at
		game.hopping = false
	elif not points.is_empty():
		var target := points[0]
		game.player.global_position = previous.move_toward(target,SPEED*delta)
		if game.player.global_position.distance_to(target) < .015: points.remove_at(0)
		if points.is_empty():
			game.hopping = false
			if note_target >= 0:
				var arrived := note_target
				note_target = -1
				latched = arrived
				game._arrive_note(arrived)
	var velocity: Vector3 = game.player.global_position-previous
	moving = velocity.length() > .001
	if moving:
		game.player.rotation.y = lerp_angle(game.player.rotation.y,atan2(velocity.x,velocity.z),minf(1,delta*14))
		for i in range(game.limbs.size()): game.limbs[i].rotation = game.limb_rest[i]+Vector3(sin(age*12)*.35*(1 if i%2==0 else -1),0,0)
	else: game._rest_limbs()
	# Stepping across a flower doesn't play it: pause briefly to choose it.
	if game.lesson.stage == 4 or game.lesson.phase not in ["explore","answer"] or game.hopping: return
	var nearby := -1
	for i in range(1,game.route.size()):
		if game.player.global_position.distance_to(flat(game.route[i])) < .62: nearby = i; break
	if nearby < 0:
		latched = -1
		dwell = 0
		game.route_index = 0
	elif nearby != latched and not moving:
		dwell += delta
		if dwell >= .28:
			latched = nearby
			dwell = 0
			game._arrive_note(nearby)
	else: dwell = 0
