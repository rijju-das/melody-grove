extends Node3D
## Connected forest sections share the original Blender meshes and textures.
const OFFSET := Vector3(30, 0, -12)
var sections: Array[Node3D] = []
var bridges: Array[Node3D] = []
var gates: Array = []
var opened := [0.0, 0.0]
var exit_trees: Array = []
var exit_tree_positions: Array = []

func setup(forest: Node3D, player: Node3D) -> void:
	# Keep one player when the forest sections are duplicated or hidden.
	player.reparent(self, true)
	sections.append(forest)
	for i in range(1, 3):
		# Copy the live static tree directly. Re-instantiating the imported scene
		# after moving its player can mismatch overrides against child indices.
		var section := forest.duplicate(0) as Node3D
		section.name = "ForestStage%d" % (i + 1)
		add_child(section)
		section.position = forest.position + OFFSET * i
		for object_name in ["MS_Player", "MS_Stage_Base", "MS_Stage_Surface", "MS_World_Floor", "MS_Target", "MS_Help"]:
			var object := section.find_child(object_name, true, false) as Node3D
			if object: object.hide()
		sections.append(section)
	for i in range(2):
		var branches := sections[i].find_children("Grove_storybook tree 6*", "Node3D", true, false)
		var positions: Array[Vector3] = []
		for branch in branches: positions.append(branch.position)
		exit_trees.append(branches)
		exit_tree_positions.append(positions)
		_make_bridge(i)
	show_stage(1)

func show_stage(number: int) -> void:
	for i in range(3): sections[i].visible = i == number - 1
	for i in range(2): bridges[i].visible = i == number - 1 or i == number - 2

func prepare_passage(number: int) -> void:
	show_stage(number)
	sections[number].show()
	opened[number - 1] = 0
	move_gate(number - 1, 0)

func move_gate(index: int, amount: float) -> void:
	opened[index] = amount
	var pair: Array = gates[index]
	pair[0].position.x = -2.0 - 3.0 * smoothstep(0, 1, amount)
	pair[1].position.x = 2.0 + 3.0 * smoothstep(0, 1, amount)
	pair[0].rotation.z = lerpf(-0.35, 0.62, smoothstep(0, 1, amount))
	pair[1].rotation.z = lerpf(0.35, -0.62, smoothstep(0, 1, amount))
	# The original foreground tree also parts, keeping the crossing visible.
	for i in range(exit_trees[index].size()):
		exit_trees[index][i].position = exit_tree_positions[index][i] + Vector3(0, 0, 8) * smoothstep(0, 1, amount)

func entry(number: int) -> Vector3:
	return sections[number - 1].find_child("Grove_starting surface", true, false).global_position + Vector3(0, 0.135, 0)

func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.9
	return material

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	object.mesh = shape
	object.material_override = material
	parent.add_child(object)
	object.position = at
	return object

func _make_bridge(index: int) -> void:
	var start: Vector3 = sections[index].find_child("MS_Pad_7", true, false).global_position
	var finish := entry(index + 2) - Vector3(0, 0.135, 0)
	var bridge := Node3D.new()
	add_child(bridge)
	bridge.global_position = start
	bridge.look_at(finish, Vector3.UP)
	bridges.append(bridge)
	var length := start.distance_to(finish)
	var wood := _material("c49958")
	var rail := _material("82512e")
	var plank := BoxMesh.new()
	plank.size = Vector3(2.5, 0.20, 0.52)
	var count := ceili(length / 0.55)
	for i in range(count + 1):
		_mesh(bridge, plank, Vector3(0, -0.04, -length * i / count), wood)
	for side in [-1.0, 1.0]:
		var beam := BoxMesh.new()
		beam.size = Vector3(0.14, 0.14, length)
		_mesh(bridge, beam, Vector3(side * 1.25, 0.78, -length / 2), rail)
		var post := CylinderMesh.new()
		post.top_radius = 0.09
		post.bottom_radius = 0.12
		post.height = 0.9
		post.radial_segments = 6
		for i in range(6): _mesh(bridge, post, Vector3(side * 1.25, 0.35, -length * i / 5), rail)
	var pair: Array[Node3D] = []
	var bark := _material("774d32")
	var leaf := _material("78ac58" if index == 0 else "66a994")
	for side in [-1.0, 1.0]:
		var tree := Node3D.new()
		bridge.add_child(tree)
		tree.position = Vector3(side * 2.0, 0, -length * 0.43)
		var trunk := CylinderMesh.new()
		trunk.bottom_radius = 0.3
		trunk.top_radius = 0.16
		trunk.height = 2.8
		trunk.radial_segments = 7
		_mesh(tree, trunk, Vector3(0, 1.3, 0), bark)
		var crown := SphereMesh.new()
		crown.radius = 1.5
		crown.height = 2.3
		crown.radial_segments = 10
		crown.rings = 5
		_mesh(tree, crown, Vector3(-side * 0.40, 2.9, 0), leaf)
		pair.append(tree)
	gates.append(pair)
	move_gate(index, 0)
	var sign := Label3D.new()
	sign.text = "ECHO MEADOW →" if index == 0 else "CANOPY CONCERT →"
	sign.font_size = 48
	sign.pixel_size = 0.012
	sign.modulate = Color("fff0c4")
	sign.outline_modulate = Color("173e35")
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bridge.add_child(sign)
	sign.position = Vector3(0, 4.4, -length * 0.43)
