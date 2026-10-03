extends "res://memory_arena.gd"
## Sing from the clearing; five branches blossom while the explorer stays grounded.
var jewels: Array[MeshInstance3D] = []
var complete_count := 0
var bloom_age := 0.0

func setup_stairway(section: Node3D, at: Vector3, entry_point: Vector3) -> void:
	for child in section.get_children():
		if child != self and child is Node3D: child.hide()
	center = Vector3(at.x,.06,at.z)
	global_position = center
	_label(self,"THE SINGING TREE",Vector3(0,.35,1.3),28)
	_path(entry_point,center)
	preload("res://forest_scenery.gd").tree(self,Vector3(0,0,-4),1.65,.4)
	for i in range(5):
		var bud := Node3D.new()
		add_child(bud)
		bud.position = Vector3([-2.3,2.4,-1.6,1.6,0][i], [2.3,3.2,4.5,5.4,6.6][i],-3.2)
		var petal := MeshInstance3D.new()
		petal.name = "BloomBranch"
		petal.mesh = preload("res://ground_flower.gd").flower_mesh(Color(["ecb86a","9cc58a","80bbb4","9cc58a","ecb86a"][i]))
		petal.material_override = preload("res://ground_flower.gd").material(Color.WHITE)
		petal.material_override.vertex_color_use_as_albedo = true
		bud.add_child(petal)
		petal.scale = Vector3.ONE*3.2
		var top := preload("res://ground_flower.gd").sphere(bud,Vector3(0,.95,0),Vector3.ONE*.16,Color("fff1a9"))
		bud.rotation.x = PI*.25
		tops.append(top)
		pads.append(bud)
		_label(bud,["Do","Re","Mi","Re","Do"][i],Vector3(0,.6,0),28)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .66
		torus.outer_radius = .71
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = _material("ffe798",true)
		bud.add_child(ring)
		ring.position.y = .9
		rings.append(ring)
		jewels.append(preload("res://ground_flower.gd").sphere(bud,Vector3(0,.4,0),Vector3.ONE*.12,Color("ffda74")))
	reset()

func reset() -> void:
	complete_count = 0
	for pad in pads: pad.get_node("BloomBranch").scale = Vector3.ONE*1.7
	for gem in jewels: gem.hide()
	clear_lights()

func clear_lights() -> void:
	for i in range(rings.size()): rings[i].visible = i < complete_count

func light_note(index: int) -> void:
	clear_lights()
	if index < rings.size(): rings[index].show()

func feedback(index: int, amount: float) -> void:
	light_note(index)
	if index < rings.size(): rings[index].scale = Vector3.ONE*(1.0+amount*.14)

func collected_step(index: int) -> void:
	pads[index].get_node("BloomBranch").scale = Vector3.ONE*3.2
	jewels[index].show()
	complete_count = index+1
	clear_lights()

func tick(delta: float) -> void:
	bloom_age += delta
	for i in range(complete_count):
		jewels[i].position.y = .45+sin(bloom_age*2+i)*.12
