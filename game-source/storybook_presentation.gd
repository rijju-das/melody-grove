extends Node3D
## Presentation only: shared meshes, no physics, scoring, or microphone changes.
var game: Node
var avatar: Node3D
var head: Node3D
var scarf: Node3D
var eyes: Array[Node3D] = []
var breeze: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var age := 0.0
var was_hopping := false
var landing := 0.0
var ripple: MeshInstance3D
var materials: Dictionary = {}
var round_mesh := SphereMesh.new()
var rng := RandomNumberGenerator.new()

func setup(controller: Node) -> void:
	game = controller
	# Two samples smooth the rounded silhouette without a heavy post-process.
	get_viewport().msaa_3d = Viewport.MSAA_2X
	rng.seed = 4207
	round_mesh.radial_segments = 20
	round_mesh.rings = 10
	round_mesh.radius = 1.0
	round_mesh.height = 2.0
	_install_explorer()
	for index in range(4):
		var section: Node3D = game.stage_path.sections[index]
		var garden := Node3D.new()
		garden.name = "StorybookDetails"
		section.add_child(garden)
		garden.global_position = Vector3.ZERO
		if index == 0:
			for i in range(game.route.size()):
				var point: Vector3 = game.route[i]
				_flower(garden, point + Vector3(-1.5 if i % 2 else 1.5, -0.4, 0.45), i)
			_fireflies(garden, game.route[4], 7)
		elif index == 1:
			_border(garden, game.memory_arena.center, 8)
		elif index == 2:
			for arena in game.canopy.arenas: _border(garden, arena.center, 6)
		else:
			var center: Vector3 = game.stairway.center
			# A layered distant forest replaces the empty sky behind the singing tree.
			_sphere(garden, center + Vector3(0, -8.2, -4), Vector3(14, 2.3, 10), "6eaa81")
			_sphere(garden, center + Vector3(-12, -9, -21), Vector3(18, 7, 8), "94bfa7")
			_sphere(garden, center + Vector3(15, -10, -25), Vector3(20, 9, 9), "aacbb6")
			for i in range(5):
				_tree(garden, center + Vector3(-15 + i * 7.0, -7.0, -17 - (i % 2) * 4), 10 + (i % 3) * 2.5, i)
			for i in range(5):
				var point: Vector3 = game.stairway.pads[i].global_position
				_flower(garden, point + Vector3(-1.25, -0.3, -0.2), i)
			_fireflies(garden, center + Vector3(0, 5, -3), 9)
	# Give the original imported crowns a gentle, slow breeze as well.
	for section in game.stage_path.sections.slice(0, 2):
		var count := 0
		for crown in section.find_children("*crown*", "MeshInstance3D", true, false):
			if count % 5 == 0: breeze.append({"node": crown, "rest": crown.rotation, "phase": count * 0.7})
			count += 1
	_make_landing_ripple()

func _install_explorer() -> void:
	# The model lives in main.tscn so the editor and running game match.
	avatar = game.player.get_node("StorybookExplorer")
	avatar.scale = Vector3.ONE * 1.12
	head = avatar.find_child("ExplorerHead", true, false)
	scarf = avatar.find_child("ExplorerScarf", true, false)
	for side in ["L", "R"]:
		var eye := avatar.find_child("ExplorerEye" + side, true, false) as Node3D
		if eye: eyes.append(eye)
	game.limbs.clear()
	game.limb_rest.clear()
	for name in ["ExplorerLegL", "ExplorerLegR", "ExplorerArmL", "ExplorerArmR"]:
		var limb := avatar.find_child(name, true, false) as Node3D
		if limb:
			game.limbs.append(limb)
			game.limb_rest.append(limb.rotation)

func _material(color: String, luminous := false) -> StandardMaterial3D:
	var key := color + str(luminous)
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.86
	if luminous: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = material
	return material

func _sphere(parent: Node3D, at: Vector3, dimensions: Vector3, color: String, luminous := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = round_mesh
	item.material_override = _material(color, luminous)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	item.position = at
	item.scale = dimensions
	return item

func _flower(parent: Node3D, at: Vector3, index: int) -> void:
	var plant := Node3D.new()
	parent.add_child(plant)
	plant.position = at
	for side in [-1, 1]:
		var leaf := _sphere(plant, Vector3(side * 0.19, 0.14, 0), Vector3(0.35, 0.09, 0.15), "73a15f")
		leaf.rotation.z = side * 0.4
	_sphere(plant, Vector3(0, 0.30, 0), Vector3(0.055, 0.28, 0.055), "477f61")
	var tint: String = ["f0b299", "edd183", "b3c2df"][index % 3]
	for p in range(5):
		var angle := TAU * p / 5
		_sphere(plant, Vector3(cos(angle) * 0.14, 0.57, sin(angle) * 0.14), Vector3(0.15, 0.08, 0.15), tint)
	_sphere(plant, Vector3(0, 0.62, 0), Vector3(0.09, 0.07, 0.09), "ffe4a1")
	breeze.append({"node": plant, "rest": Vector3.ZERO, "phase": index * 1.3})

func _border(parent: Node3D, center: Vector3, count: int) -> void:
	for i in range(count):
		var angle := TAU * (i + 0.5) / count
		_flower(parent, center + Vector3(cos(angle) * 6.65, -0.25, sin(angle) * 6.65), i)
	_fireflies(parent, center + Vector3(0, 1.5, 0), 6)

func _tree(parent: Node3D, at: Vector3, height: float, index: int) -> void:
	var tree := Node3D.new()
	parent.add_child(tree)
	tree.position = at
	var trunk := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.22
	shape.bottom_radius = 0.58
	shape.height = height
	shape.radial_segments = 12
	trunk.mesh = shape
	trunk.material_override = _material("769280")
	tree.add_child(trunk)
	trunk.position.y = height * 0.5
	for i in range(4):
		var color: String = ["669d83", "79ac8d", "8fba98"][(index + i) % 3]
		_sphere(tree, Vector3((i - 1.5) * 1.1, height + sin(i * 1.5), 0.35 * (i % 2)), Vector3(2.1, 2.7, 1.9), color)
	breeze.append({"node": tree, "rest": Vector3.ZERO, "phase": index})

func _fireflies(parent: Node3D, center: Vector3, count: int) -> void:
	for i in range(count):
		var at := center + Vector3(rng.randf_range(-6, 6), rng.randf_range(0.8, 3.5), rng.randf_range(-4, 3))
		var mote := _sphere(parent, at, Vector3.ONE * 0.035, "ffe4a1", true)
		motes.append({"node": mote, "rest": at, "phase": rng.randf_range(0, TAU)})

func _make_landing_ripple() -> void:
	ripple = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38
	ring.outer_radius = 0.44
	ring.rings = 24
	ring.ring_segments = 6
	ripple.mesh = ring
	var material := _material("fff2bb", true).duplicate() as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple.material_override = material
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ripple)
	ripple.hide()

func _process(delta: float) -> void:
	if game == null or game.paused: return
	age += delta
	for item in breeze:
		if item.node.is_visible_in_tree(): item.node.rotation.z = item.rest.z + sin(age * 0.7 + item.phase) * 0.012
	for item in motes:
		if item.node.is_visible_in_tree(): item.node.position = item.rest + Vector3(sin(age * 0.45 + item.phase) * 0.5, sin(age * 0.9 + item.phase) * 0.25, 0)
	if was_hopping and not game.hopping:
		landing = 0.3
		ripple.global_position = game.player.global_position + Vector3.UP * 0.015
	was_hopping = game.hopping
	landing = maxf(0, landing - delta)
	var squash := sin((1.0 - landing / 0.3) * PI) * 0.14 if landing > 0 else 0.0
	var stretch := sin(PI * game.hop_elapsed / game.HOP_SECONDS) * 0.10 if game.hopping else 0.0
	avatar.scale = Vector3(1 + squash * 0.65 - stretch * 0.4, 1 - squash + stretch, 1 + squash * 0.65 - stretch * 0.4) * 1.12
	avatar.position.y = sin(age * 2.3) * 0.014 if not game.hopping else 0.0
	if head: head.rotation.z = sin(age * 1.2) * 0.035
	if scarf: scarf.rotation.x = sin(age * 3) * 0.10 + (0.25 if game.hopping else 0.0)
	var blink := fmod(age, 4.7)
	for eye in eyes: eye.scale.y = 0.08 if blink > 4.50 and blink < 4.64 else 1.0
	ripple.visible = landing > 0
	if ripple.visible:
		ripple.scale = Vector3.ONE * lerpf(2.7, 0.7, landing / 0.3)
		(ripple.material_override as StandardMaterial3D).albedo_color.a = landing / 0.3 * 0.6
