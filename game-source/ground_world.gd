extends Node3D
## Ground adventure layout. The original imported platform scene remains recoverable.
const Flower = preload("res://ground_flower.gd")
const Valley = preload("res://forest_valley.gd")
const SPOTS := [Vector2(-8,3),Vector2(-8,-1),Vector2(-5,-4),Vector2(-1,-5),Vector2(3,-4),Vector2(7,-2),Vector2(10,0),Vector2(11,3)]
var game: Node
var meadow_pads: Array[Node3D] = []
var guide: Node3D
var age := 0.0
var brooks: Array[MeshInstance3D] = []
var restored := 0
var meadow_bird: Node3D

func setup(controller: Node) -> void:
	game = controller
	for index in range(4):
		var section: Node3D = game.stage_path.sections[index]
		for child in section.get_children():
			if child is Node3D and child != game.memory_arena and child != game.canopy and child != game.stairway and child.name != "FullBlenderForest" and child.name != "Grove_pond": child.hide()
		if index >= 2:
			var forest := Node3D.new()
			forest.name = "GroundForest"
			section.add_child(forest)
			if index == 3: forest.global_position = game.stairway.center - Vector3.UP * .06
			Valley.build(forest)
	var meadow: Node3D = game.stage_path.sections[0]
	for i in range(8):
		var pad := Node3D.new()
		pad.name = "MeadowFlower%d" % i
		meadow.add_child(pad)
		pad.position = Vector3(SPOTS[i].x,.06,SPOTS[i].y)
		Flower.build(pad,Color(game.memory_arena.COLORS[i]))
		game.memory_arena._label(pad,game.NOTE_NAMES[i],Vector3(0,.85,0),28)
		meadow_pads.append(pad)
	# Gentle dirt trail between flower patches, instead of raised wooden steps.
	var points: Array[Vector3] = [entry()]
	for pad in meadow_pads: points.append(pad.global_position)
	for i in range(points.size()-1): trail(meadow,points[i],points[i+1])
	guide = Node3D.new()
	add_child(guide)
	Flower.sphere(guide,Vector3.ZERO,Vector3.ONE*.11,Color("fff0ac")).material_override = Flower.material(Color("ffe6a0"),true)
	for side in [-1,1]: Flower.sphere(guide,Vector3(side*.13,.035,0),Vector3(.14,.02,.07),Color("fff7d8"))
	meadow_bird = game.canopy.creatures[0].duplicate(0)
	meadow.add_child(meadow_bird)
	meadow_bird.position = Vector3(11,1.5,1.8)
	meadow_bird.hide()
	_make_brooks()
	# Replace inter-stage floating bridges with a continuous earthen route.
	for i in range(3):
		var bridge: Node3D = game.stage_path.bridges[i]
		for child in bridge.get_children():
			if child is MeshInstance3D: child.hide()
		bridge.global_position.y = .04
		bridge.rotation.x = 0
		var end: Vector3 = game.memory_arena.center if i == 0 else (game.canopy.arenas[0].center if i == 1 else game.stairway.center)
		var start: Vector3 = meadow_pads[-1].global_position if i == 0 else (game.memory_arena.center if i == 1 else game.canopy.arenas[2].center)
		trail(bridge,start,end)
		for label in bridge.find_children("*","Label3D",true,false): label.text = ["ECHO CLEARING →","BROKEN BROOK →","SINGING TREE →"][i]

func entry() -> Vector3:
	return game.stage_path.sections[0].global_position + Vector3(-10,.06,4.5)

func trail(parent: Node3D, start: Vector3, finish: Vector3) -> void:
	var length := start.distance_to(finish)
	var count := maxi(1,ceili(length/.75))
	for i in range(count+1):
		var stone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = .86
		mesh.bottom_radius = .86
		mesh.height = .028
		mesh.radial_segments = 10
		stone.mesh = mesh
		stone.material_override = Flower.material(Color("746c4c"))
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(stone)
		stone.global_position = start.lerp(finish,float(i)/count)
		stone.global_position.y = .016

func _make_brooks() -> void:
	for i in range(3):
		var arena: Node3D = game.canopy.arenas[i]
		var water := MeshInstance3D.new()
		water.name = "RestoredBrook%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.8,18)
		plane.subdivide_width = 4
		plane.subdivide_depth = 16
		water.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://living_water.gdshader")
		water.material_override = mat
		arena.add_child(water)
		water.position = Vector3(8.5,.07,2)
		water.hide()
		brooks.append(water)
		for j in range(9):
			for side in [-1,1]:
				preload("res://forest_scenery.gd").rock(arena,Vector3(8.5+side*1.65,-.05,-6+j*2),.65,j)

func reset(stage: int) -> void:
	if stage == 1:
		meadow_bird.hide()
		for pad in meadow_pads: Flower.bloom(pad,false)
	if stage == 3:
		restored = 0
		for brook in brooks: brook.hide()

func restore_brook(index: int) -> void:
	brooks[index].show()
	restored = maxi(restored,index+1)
	for i in range(index*3,index*3+3): game.canopy.creatures[i].show()

func _process(delta: float) -> void:
	if game == null or game.paused: return
	age += delta
	guide.visible = game.lesson.stage == 1 and game.lesson.phase != "complete"
	if guide.visible:
		var next := 0
		while next < 7 and game.lesson.collected.has(next): next += 1
		var at: Vector3 = meadow_pads[next].global_position + Vector3(0,1.25,0)
		guide.global_position = at + Vector3(sin(age*1.5)*.25,sin(age*2)*.15,cos(age*1.5)*.25)
	if meadow_bird.is_visible_in_tree():
		meadow_bird.position.y = 1.5+sin(age*3)*.15
		meadow_bird.rotation.z = sin(age*3)*.08
	for brook in brooks:
		if brook.is_visible_in_tree(): brook.material_override.set_shader_parameter("breeze_time",age)
