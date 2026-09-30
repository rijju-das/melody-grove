extends Camera3D
## Stable isometric follow: track the path height, not the bounce of each hop.
var controller: Node
var overview := false
var focus := Vector3.ZERO
var initialized := false

func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	controller = get_parent().get_node("MelodyController")

func is_overview() -> bool:
	return overview or (controller != null and controller.lesson.phase == "listening")

func reset_follow() -> void:
	if controller == null: controller = get_parent().get_node("MelodyController")
	overview = false
	initialized = false
	_update_camera(0.0)

func _process(delta: float) -> void:
	if controller == null or controller.player == null or controller.paused: return
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if controller.route.is_empty(): return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var target: Vector3
	var target_size: float
	if controller.transitioning:
		target = controller.travel_position + Vector3.UP * 0.9
		target_size = maxf(14.5, 11.0 * aspect)
	elif controller.lesson.stage == 2:
		target = controller.memory_arena.center + Vector3.UP * 0.7
		target_size = maxf(16.8, 14.0 * aspect)
		if not OS.has_feature("web"):
			target_size = maxf(18.0, 16.0 * aspect)
			target -= global_basis.y * 2.0
	elif is_overview():
		target = (controller.route[0] + controller.route[-1]) * 0.5
		target_size = maxf(32.0, 22.0 * aspect)
	else:
		var index: int = controller.route_index
		target = controller.route[index]
		if controller.hopping:
			var t: float = clampf(controller.hop_elapsed / controller.HOP_SECONDS, 0, 1)
			target = target.lerp(controller.route[controller.destination], smoothstep(0, 1, t))
		# Leave a little room ahead while keeping both adjacent steps visible.
		var next: int = mini(index + 1, controller.route.size() - 1)
		target += (controller.route[next] - controller.route[index]) * 0.20 + Vector3.UP * 0.8
		target_size = maxf(12.5, 10.0 * aspect)
	var weight := 1.0 if not initialized else 1.0 - exp(-5.5 * delta)
	focus = focus.lerp(target, weight)
	size = lerpf(size, target_size, weight)
	rotation.x = lerpf(rotation.x, -0.95 if controller.lesson.stage == 2 and not controller.transitioning else -0.657394, weight)
	global_position = focus + global_basis.z * 30.0
	initialized = true
