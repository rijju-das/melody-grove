extends "res://memory_arena.gd"
## Five rising platforms; feedback lights grow with a steady sung note.
var jewels: Array[MeshInstance3D] = []
var complete_count := 0

func setup_stairway(section: Node3D, at: Vector3, entry_point: Vector3) -> void:
	for child in section.get_children():
		if child != self and child is Node3D: child.hide()
	center = at
	global_position = at
	_disc(self, 2.0, 0.6, -0.4, "be935f")
	_disc(self, 1.9, 0.12, -0.04, "f2d99a")
	_label(self, "SINGING STAIRWAY", Vector3(0, 0.35, 1.3), 28)
	_path(entry_point, center)
	var trunk := Node3D.new()
	add_child(trunk)
	trunk.position = Vector3(0, 2, -5)
	_disc(trunk, 1.3, 36, -10, "896343")
	for j in range(9):
		var crown := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 2.4
		sphere.height = 3.6
		sphere.radial_segments = 12
		sphere.rings = 6
		crown.mesh = sphere
		crown.material_override = _material(["78ac78", "a9c984", "4f9479"][j % 3])
		trunk.add_child(crown)
		crown.position = Vector3(cos(j * TAU / 9) * 4, 10 + sin(j * 2) * 1.1, sin(j * TAU / 9) * 3)
	for i in range(5):
		var pad := Node3D.new()
		add_child(pad)
		# A front-facing spiral keeps every landing visible around the tree.
		var angle := PI * 0.12 + i * PI * 0.22
		pad.position = Vector3(cos(angle) * 4.8, 1.6 + i * 1.7, -3 + sin(angle) * 4.0)
		_disc(pad, 1.3, 0.45, -0.30, "a67848")
		_disc(pad, 1.32, 0.12, -0.04, "f4d58b")
		tops.append(_disc(pad, 1.2, 0.10, 0.03, ["ecb86a", "9cc58a", "80bbb4", "9cc58a", "ecb86a"][i]))
		_label(pad, "%d · %s" % [i + 1, ["Do", "Re", "Mi", "Re", "Do"][i]], Vector3(0, 0.5, 0), 35)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.34
		torus.outer_radius = 1.43
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = _material("ffe798", true)
		pad.add_child(ring)
		ring.position.y = 0.10
		rings.append(ring)
		pads.append(pad)
		var branch := MeshInstance3D.new()
		var wood := CylinderMesh.new()
		var start := Vector3(0, pad.position.y - 0.4, -5)
		wood.top_radius = 0.15
		wood.bottom_radius = 0.32
		wood.height = start.distance_to(pad.position)
		wood.radial_segments = 8
		branch.mesh = wood
		branch.material_override = _material("896343")
		add_child(branch)
		branch.position = (start + pad.position) / 2
		branch.quaternion = Quaternion(Vector3.UP, (pad.position - start).normalized())
		var gem := MeshInstance3D.new()
		var gem_shape := SphereMesh.new()
		gem_shape.radius = 0.26
		gem_shape.height = 0.8
		gem_shape.radial_segments = 4
		gem_shape.rings = 1
		gem.mesh = gem_shape
		gem.material_override = _material("ffda74", true)
		pad.add_child(gem)
		gem.position = Vector3(0.7, 1.0, 0)
		jewels.append(gem)
	reset()

func reset() -> void:
	complete_count = 0
	for gem in jewels: gem.show()
	clear_lights()

func clear_lights() -> void:
	for ring in rings: ring.hide()

func light_note(index: int) -> void:
	clear_lights()
	if index < rings.size(): rings[index].show()

func feedback(index: int, amount: float) -> void:
	light_note(index)
	if index < rings.size():
		rings[index].scale = Vector3.ONE * (1.0 + amount * 0.14)

func collected_step(index: int) -> void:
	jewels[index].hide()
	complete_count = index + 1
	clear_lights()

func tick(delta: float) -> void:
	for jewel in jewels: jewel.rotation.y += delta
