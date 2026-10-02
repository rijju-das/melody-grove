extends RefCounted
## The actual sculpted trunk and individual-leaf canopy from the Blender study.
const TRUNK = preload("res://assets/living-grove/tree_trunk.glb")
const CANOPY = preload("res://assets/living-grove/tree_canopy.glb")
const ROCK = preload("res://assets/living-grove/moss_rock.glb")
const GRASS = preload("res://assets/living-grove/grass_tuft.glb")

static func tree(parent: Node3D, at: Vector3, size: float, turn := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "BlenderForestTree"
	parent.add_child(root)
	root.position = at
	root.scale = Vector3.ONE * size
	root.rotation.y = turn
	root.add_child(TRUNK.instantiate())
	var crown: Node3D = CANOPY.instantiate()
	crown.name = "BlenderLeafCanopy"
	root.add_child(crown)
	crown.add_to_group("living_canopy")
	return root

static func rock(parent: Node3D, at: Vector3, size: float, turn: float) -> void:
	var item: Node3D = ROCK.instantiate()
	parent.add_child(item)
	item.position = at
	item.scale = Vector3.ONE * size
	item.rotation.y = turn

static func grass(parent: Node3D, positions: Array[Vector3], seed_value: int) -> void:
	var template: Node3D = GRASS.instantiate()
	var mesh: Mesh = template.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var batch := MultiMeshInstance3D.new()
	batch.name = "BlenderGrass"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = positions.size()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i in range(positions.size()):
		var basis := Basis(Vector3.UP, random.randf_range(0, TAU)).scaled(Vector3.ONE * random.randf_range(0.8, 1.8))
		multi.set_instance_transform(i, Transform3D(basis, positions[i]))
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)
	template.free()
