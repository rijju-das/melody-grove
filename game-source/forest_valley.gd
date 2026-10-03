extends RefCounted
## Shared, low-cost Blender scenery around the playable clearing.
const CEDAR = preload("res://assets/forest-valley/cedar.glb")
const CRAG = preload("res://assets/forest-valley/crag.glb")
const REEDS = preload("res://assets/forest-valley/reeds.glb")

static func terrain_height(x: float, z: float) -> float:
	var rise := smoothstep(13.0, 34.0, -z)
	var height := -0.15 + 0.27 * sin(x * 0.13 + 1.0) * cos(z * 0.16)
	height += rise * (2.8 + sin(x * 0.13) * 1.8 + cos(z * 0.12))
	var pond_distance := pow((x - 5.0) / 5.5, 2) + pow((z - 4.5) / 2.9, 2)
	height = lerpf(-0.08, height, smoothstep(0.8, 1.35, pond_distance))
	return height

static func cedar(parent: Node3D, at: Vector3, size: float, turn: float) -> void:
	var tree: Node3D = CEDAR.instantiate()
	parent.add_child(tree)
	tree.position = at
	tree.scale = Vector3.ONE * size
	tree.rotation.y = turn
	var canopy := tree.find_child("CedarCanopy", true, false)
	if canopy:
		canopy.add_to_group("living_canopy")
		var needles := ShaderMaterial.new()
		needles.shader = preload("res://valley_pine.gdshader")
		canopy.material_override = needles
	if at.z < -22:
		for mesh in tree.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func instance_asset(asset: PackedScene, parent: Node3D, at: Vector3, dimensions: Vector3, turn: float) -> void:
	var item: Node3D = asset.instantiate()
	parent.add_child(item)
	item.position = at
	item.scale = dimensions
	item.rotation.y = turn
	if asset == CRAG:
		var stone := ShaderMaterial.new()
		stone.shader = preload("res://valley_rock.gdshader")
		for mesh in item.find_children("*", "MeshInstance3D", true, false): mesh.material_override = stone

static func build(parent: Node3D) -> void:
	var valley := Node3D.new()
	valley.name = "ForestValley"
	parent.add_child(valley)
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Continuous land beyond the original island; the existing note positions stay intact.
	ground.set_smooth_group(0)
	for iz in range(60):
		for ix in range(80):
			var x := -80.0 + ix * 2.0
			var z := -90.0 + iz * 2.0
			for p in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				ground.add_vertex(Vector3(p.x, terrain_height(p.x,p.y), p.y))
	ground.index()
	ground.generate_normals()
	var floor := MeshInstance3D.new()
	floor.name = "ContinuousMeadow"
	floor.mesh = ground.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://forest_ground.gdshader")
	floor.material_override = material
	valley.add_child(floor)
	var random := RandomNumberGenerator.new()
	random.seed = 731
	# Staggered forest layers leave a clear sight line along the musical path.
	for row in range(3):
		for i in range(12):
			var x := -43.0 + i * 7.5 + random.randf_range(-2,2)
			var z := -19.0 - row * 14.0 + random.randf_range(-3,3)
			cedar(valley, Vector3(x,terrain_height(x,z),z), random.randf_range(0.85,1.55), random.randf_range(0,TAU))
	for at in [Vector3(-18,-.5,-6),Vector3(-23,-.5,7),Vector3(18,-.5,-5),Vector3(23,-.5,5)]:
		cedar(valley,at,1.25,random.randf_range(0,TAU))
	# Irregular overlapping blue-grey crags, with lower rocks in front.
	for i in range(19):
		var x := -65.0 + i * 7.2
		var z := -58.0 - sin(i * 1.7) * 8.0
		instance_asset(CRAG,valley,Vector3(x,terrain_height(x,z)-1,z),Vector3(random.randf_range(7,11),random.randf_range(3.5,6.5),random.randf_range(5,8)),random.randf_range(0,TAU))
	for i in range(8):
		var x := -24.0 + i * 7.0
		var z := -24.0 - (i%3)*3
		instance_asset(CRAG,valley,Vector3(x,terrain_height(x,z)-1,z),Vector3(2.3,2.8+(i%3),2.2),i*1.8)
	# Large mossy bank boulders are deliberately asymmetrical and spaced in groups.
	for at in [Vector3(1.1,.15,6.8),Vector3(8.8,.05,6.7),Vector3(10.4,.1,3.4),Vector3(2.3,.1,2.0)]:
		preload("res://forest_scenery.gd").rock(valley,at,3.3,random.randf_range(0,TAU))
	for i in range(6):
		instance_asset(REEDS,valley,Vector3(2.6+i*1.25,.24,2.1+sin(i)*.35),Vector3.ONE*(.8+i*.08),i*1.3)
	# Grass batches surround the clearing without obscuring musical platforms.
	var grass: Array[Vector3] = []
	for i in range(1800):
		var x := random.randf_range(-38,38)
		var z := random.randf_range(-40,17)
		if x > -14 and x < 14 and z > -15 and z < 9: continue
		grass.append(Vector3(x,terrain_height(x,z)+.02,z))
	preload("res://forest_scenery.gd").grass(valley,grass,218)
