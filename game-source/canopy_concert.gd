extends Node3D
## Three treetop clearings. Geometry stays static except bridge growth and finale birds.
const Arena = preload("res://memory_arena.gd")
var arenas: Array[Node3D] = []
var bridges: Array = []
var growth := [0.0, 0.0]
var lanterns: Array[MeshInstance3D] = []
var creatures: Array[Node3D] = []
var celebrating := false
var elapsed := 0.0

func setup(section: Node3D, entry: Vector3) -> void:
	for child in section.get_children():
		if child != self and child is Node3D: child.hide()
	for i in range(3):
		var arena := Arena.new()
		add_child(arena)
		arena.setup_canopy(section.global_position + Vector3(i * 20, 4 + i * 3, -4 if i == 1 else 0), i)
		arenas.append(arena)
		_decorate(arena, i)
		# Paths go between the notes, leaving the playable platforms clear.
		arena._path(arena.center + Vector3(-6.6, 0, 2.3), arena.center)
		if i < 2: arena._path(arena.center, arena.center + Vector3(6.6, 0, 2.3))
	arenas[0]._path(entry, arenas[0].center + Vector3(-6.6, 0, 2.3))
	for i in range(2):
		var from: Vector3 = arenas[i].center + Vector3(6.6, 0, 2.3)
		var to: Vector3 = arenas[i + 1].center + Vector3(-6.6, 0, 2.3)
		var pieces: Array[Node3D] = []
		var count := ceili(from.distance_to(to) / 0.48)
		for j in range(count + 1):
			var board := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.7, 0.20, 0.46)
			board.mesh = mesh
			board.material_override = arenas[i]._material("d3a96b")
			add_child(board)
			board.global_position = from.lerp(to, float(j) / count) - Vector3.UP * 0.16
			board.look_at(board.global_position + to - from, Vector3.UP)
			pieces.append(board)
		bridges.append(pieces)
	reset()

func _sphere(parent: Node3D, at: Vector3, radius: float, color: String, glow := false) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	object.mesh = shape
	object.material_override = arenas[0]._material(color, glow)
	parent.add_child(object)
	object.position = at
	return object

func _decorate(arena: Node3D, index: int) -> void:
	# Broad crowns and trunks make these read as elevated tree platforms.
	arena._disc(arena, 1.3, 32.0, -16.5, "775339")
	# A distant tree line gives the clearings depth without obscuring note targets.
	for j in range(3):
		var tree := Node3D.new()
		arena.add_child(tree)
		tree.position = Vector3(-8 + j * 8, -2.0 + (j % 2), -13.0 - (j % 2) * 2)
		arena._disc(tree, 0.65, 40.0, -18.0, "786548")
		for side in [-1, 0, 1]:
			var crown := _sphere(tree, Vector3(side * 1.7, 1.2 + (1.5 if side == 0 else 0), 0.6 * abs(side)), 2.3, ["5d9d83", "86b793", "aac896"][(j + index + side + 3) % 3])
			crown.scale.y = 1.15
	for j in range(7):
		var angle := TAU * j / 7.0
		var crown := _sphere(arena, Vector3(cos(angle) * 5.8, -2.0, sin(angle) * 5.8), 2.0, ["38735e", "4c8c70", "72a578"][j % 3])
		crown.scale.y = 0.7
	var lamp := Node3D.new()
	arena.add_child(lamp)
	lamp.position = Vector3(0, 0, 0.75)
	arena._disc(lamp, 0.24, 0.55, 0.25, "876543")
	var light := _sphere(lamp, Vector3(0, 0.8, 0), 0.34, "ffe19a", true)
	arena._disc(lamp, 0.40, 0.10, 0.46, "3f7461")
	arena._disc(lamp, 0.40, 0.12, 1.14, "3f7461")
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.18
	ring.rings = 12
	ring.ring_segments = 6
	handle.mesh = ring
	handle.material_override = arena._material("d5b567")
	lamp.add_child(handle)
	handle.position.y = 1.35
	handle.rotation.x = PI / 2
	lanterns.append(light)
	for j in range(6):
		var angle := PI + j * PI / 5.0
		var bulb := _sphere(arena, Vector3(cos(angle) * 6.3, 0.65, sin(angle) * 6.3), 0.15, "b5bba0")
		lanterns.append(bulb)
	for j in range(3):
		var bird := Node3D.new()
		arena.add_child(bird)
		bird.position = Vector3(-3.1 + j * 3.1, 1.2, -6.3)
		_sphere(bird, Vector3.ZERO, 0.38, ["f3ce6d", "ee9a83", "98c9da"][j]).scale = Vector3(1, 1, 1.3)
		_sphere(bird, Vector3(0, 0.30, 0.16), 0.26, "fff2c8")
		_sphere(bird, Vector3(-0.10, 0.34, 0.39), 0.045, "243c35")
		_sphere(bird, Vector3(0.10, 0.34, 0.39), 0.045, "243c35")
		_sphere(bird, Vector3(0, 0.23, 0.46), 0.09, "eaa452").scale.z = 1.6
		for side in [-1, 1]:
			var wing := _sphere(bird, Vector3(side * 0.37, 0, -0.05), 0.26, "fff2c8")
			wing.scale = Vector3(1.4, 0.22, 0.8)
		creatures.append(bird)
	arena._label(arena, ["WATCH & REPEAT", "ONE LITTLE CLUE", "PLAY BY EAR"][index], Vector3(0, 0.8, -7.0), 35)

func grow_bridge(index: int, amount: float) -> void:
	growth[index] = clampf(amount, 0, 1)
	var pieces: Array = bridges[index]
	for i in range(pieces.size()):
		var reveal := clampf(amount * (pieces.size() + 3) - i, 0, 1)
		pieces[i].visible = reveal > 0
		pieces[i].scale = Vector3.ONE * maxf(0.01, smoothstep(0, 1, reveal))

func reset() -> void:
	celebrating = false
	elapsed = 0
	for arena in arenas: arena.reset()
	for i in range(2): grow_bridge(i, 0)
	for creature in creatures: creature.hide()
	for i in range(lanterns.size()):
		lanterns[i].material_override.albedo_color = Color("ffe19a" if i % 7 == 0 else "b5bba0")
		lanterns[i].material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if i % 7 == 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL

func finish() -> void:
	celebrating = true
	for creature in creatures: creature.show()
	for light in lanterns:
		light.material_override.albedo_color = Color("fff1aa")
		light.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func tick(delta: float) -> void:
	for arena in arenas: arena.tick(delta)
	if not celebrating: return
	elapsed += delta
	for i in range(creatures.size()):
		creatures[i].position.y = 1.2 + absf(sin(elapsed * 3 + i)) * 0.30
		creatures[i].rotation.z = sin(elapsed * 3 + i) * 0.12
