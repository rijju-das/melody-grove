extends RefCounted
## Original flower patches: clear ground-level targets, with room to stand in the centre.
static func material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func sphere(parent: Node3D, at: Vector3, scale: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	node.scale = scale
	return node

static func build(parent: Node3D, color: Color) -> MeshInstance3D:
	var bed := sphere(parent, Vector3(0, -0.035, 0), Vector3(1.02, 0.075, 1.02), Color("547b49"))
	bed.name = "FlowerBed"
	var core := sphere(parent, Vector3(0, 0.03, 0), Vector3(.50,.025,.50), color.darkened(.15))
	core.name = "NoteGlow"
	var petals := flower_mesh(color)
	var mat := material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	for i in range(6):
		var angle := TAU * i / 6.0
		var flower := MeshInstance3D.new()
		flower.name = "Bloom%d" % i
		flower.mesh = petals
		flower.material_override = mat
		parent.add_child(flower)
		flower.position = Vector3(cos(angle)*.8,.08,sin(angle)*.8)
	return core

static func bloom(parent: Node3D, open: bool) -> void:
	for flower in parent.get_children():
		if str(flower.name).begins_with("Bloom"):
			flower.scale = Vector3.ONE if open else Vector3(.55,.6,.55)

static func listening_tree(parent: Node3D) -> void:
	# The listening landmark sits behind the standing spot, keeping movement clear.
	preload("res://forest_scenery.gd").tree(parent,Vector3(0,0,-1.65),.55,.2)
	var hole := sphere(parent,Vector3(0,.7,-1.28),Vector3(.30,.42,.06),Color("243b30"))
	hole.name = "EchoHollow"

static func flower_mesh(color: Color) -> ArrayMesh:
	var prototype := Node3D.new()
	sphere(prototype,Vector3(0,.12,0),Vector3(.025,.20,.025),Color("407244"))
	for j in range(5):
		var turn := TAU*j/5.0
		sphere(prototype,Vector3(cos(turn)*.105,.30,sin(turn)*.105),Vector3(.10,.065,.10),color)
	sphere(prototype,Vector3(0,.34,0),Vector3(.07,.045,.07),Color("fff1a9"))
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in prototype.get_children():
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var colors := PackedColorArray()
		colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
		colors.fill(part.material_override.albedo_color)
		arrays[Mesh.ARRAY_COLOR] = colors
		var colored := ArrayMesh.new()
		colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		combined.append_from(colored,0,part.transform)
	prototype.free()
	return combined.commit()
