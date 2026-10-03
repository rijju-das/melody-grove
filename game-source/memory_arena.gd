extends Node3D
## Eight fixed note positions around a central listening stump.
const COLORS := ["efab57", "f1d665", "afcf53", "58cbb0", "73bedb", "ad9ddd", "e1a4ca", "f3bb98"]
const LABELS := ["1 · Do\nC4 · LOW", "2 · Re\nD4", "3 · Mi\nE4", "4 · Fa\nF4", "5 · Sol\nG4", "6 · La\nA4", "7 · Ti\nB4", "8 · Do\nC5 · HIGH"]
var pads: Array[Node3D] = []
var tops: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var pulses: Array[float] = []
var center := Vector3.ZERO
var exit_point := Vector3.ZERO
var exit_waypoint := Vector3.ZERO
var wobble_note := -1
var wobble_time := 0.0

func setup(section: Node3D) -> void:
	center = section.global_position + Vector3(0, 0.06, 0)
	exit_waypoint = center + Vector3(6.6, 0, 2.3)
	exit_point = section.find_child("MS_Pad_7", true, false).global_position + Vector3(0, 0.135, 0)
	var entry: Vector3 = section.find_child("Grove_starting surface", true, false).global_position + Vector3(0, 0.135, 0)
	for child in section.find_children("*", "Node3D", true, false):
		var title := str(child.name)
		if title.begins_with("MS_Pad") or title.begins_with("MS_Note") or title.begins_with("MS_Letter") or title.begins_with("Grove_connected musical branch") or title.begins_with("Grove_branch highlight") or title.begins_with("Grove_branch leaf") or title.begins_with("Grove_wooden halo") or title.begins_with("Grove_cut wood grain"):
			child.hide()
		if title.begins_with("Grove_leaf twig") or title.begins_with("Grove_node leaf") or title.begins_with("Grove_node root support") or title in ["MS_Title", "MS_Subtitle"]:
			child.hide()
	global_position = center

	preload("res://ground_flower.gd").listening_tree(self)
	_label(self, "ECHO TREE", Vector3(0, 0.12, 0.75), 27)
	_build_notes()

func setup_canopy(at: Vector3, index: int) -> void:
	center = at
	global_position = center
	_disc(self, 1.18, 0.04, -0.02, "75976d")
	_label(self, "FOREST CHOIR", Vector3(0, 0.15, 0.9), 25)
	_build_notes()

func _build_notes() -> void:
	for i in range(8):
		var pad := Node3D.new()
		add_child(pad)
		var angle := PI + TAU * i / 8.0
		pad.position = Vector3(cos(angle) * 5.1, 0, sin(angle) * 5.1)
		tops.append(preload("res://ground_flower.gd").build(pad, Color(COLORS[i])))
		_label(pad, LABELS[i], Vector3(0, 1.05, 0.0), 32)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.06
		mesh.outer_radius = 1.15
		mesh.rings = 32
		mesh.ring_segments = 6
		ring.mesh = mesh
		ring.material_override = _material("fffbd0", true)
		pad.add_child(ring)
		ring.position.y = 0.12
		ring.hide()
		rings.append(ring)
		pads.append(pad)
		pulses.append(0.0)

func _material(color: String, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.9
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _disc(parent: Node3D, radius: float, height: float, y: float, color: String) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	object.mesh = mesh
	object.material_override = _material(color)
	if color in ["bd8e50", "f3df9b", "c89a58", "f0d58b", "b78d55", "f6d78d", "b58346", "f6dc8c", "be935f", "f2d99a", "a67848", "f4d58b"]:
		object.material_override = preload("res://stump_materials.gd").wood(radius)
	parent.add_child(object)
	object.position.y = y
	return object

func _label(parent: Node3D, text: String, at: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.016
	label.modulate = Color("193d35")
	label.outline_modulate = Color("fff4cf")
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.position = at

func _path(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	var plank := BoxMesh.new()
	plank.size = Vector3(1.5, 0.04, 0.55)
	var material := _material("746c4c")
	var count := ceili(length / 0.5)
	for i in range(count + 1):
		var board := MeshInstance3D.new()
		board.mesh = plank
		board.material_override = material
		add_child(board)
		board.global_position = from.lerp(to, float(i) / count)
		board.global_position.y = .018
		board.rotation.y = atan2(to.x-from.x,to.z-from.z)

func light_note(index: int) -> void:
	clear_lights()
	pulses[index] = 0.85
	rings[index].show()
	tops[index].material_override.albedo_color = Color("fff4bd")

func clear_lights() -> void:
	for i in range(8):
		pulses[i] = 0
		rings[i].hide()
		tops[i].material_override.albedo_color = Color(COLORS[i])

func wobble(index: int) -> void:
	wobble_note = index
	wobble_time = 0.55

func reset() -> void:
	clear_lights()
	wobble_time = 0
	wobble_note = -1
	for pad in pads: pad.rotation = Vector3.ZERO

func tick(delta: float) -> void:
	for i in range(8):
		if pulses[i] <= 0: continue
		pulses[i] = maxf(0, pulses[i] - delta)
		rings[i].visible = pulses[i] > 0
		rings[i].scale = Vector3.ONE * (1.0 + sin(pulses[i] / 0.85 * PI) * 0.12)
		tops[i].material_override.albedo_color = Color(COLORS[i]).lerp(Color("fff4bd"), pulses[i] / 0.85)
	if wobble_note >= 0:
		wobble_time = maxf(0, wobble_time - delta)
		pads[wobble_note].rotation.z = sin(wobble_time * 40) * 0.08 * wobble_time / 0.55
		if wobble_time == 0: wobble_note = -1
