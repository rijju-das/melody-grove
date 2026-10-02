extends Node3D
## Shared Blender meshes; only visible plants move. No gameplay or collision changes.
const PLANTS := {
	"broadleaf": preload("res://assets/living-grove/broadleaf.glb"),
	"fern": preload("res://assets/living-grove/fern.glb"),
	"canopy": preload("res://assets/living-grove/canopy.glb"),
	"flower_coral": preload("res://assets/living-grove/flower_coral.glb"),
	"flower_cream": preload("res://assets/living-grove/flower_cream.glb"),
	"flower_lilac": preload("res://assets/living-grove/flower_lilac.glb")
}
var game: Node
var plants: Array[Dictionary] = []
var ponds: Array[Dictionary] = []
var elapsed := 0.0

func add_plant(parent: Node3D, kind: String, at: Vector3, size: float, phase: float) -> Node3D:
	var plant: Node3D = PLANTS[kind].instantiate()
	plant.name = "Living_" + kind
	parent.add_child(plant)
	plant.position = at
	plant.scale = Vector3.ONE * size
	plant.rotation.y = phase
	for mesh in plant.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var strength := 0.085 if kind.begins_with("flower") else 0.048 if kind == "fern" else 0.038
	plants.append({"node":plant, "rest":plant.rotation, "phase":phase, "strength":strength})
	return plant

func setup(controller: Node) -> void:
	game = controller
	for section in game.stage_path.sections.slice(0, 2):
		var pond := section.find_child("Grove_pond", true, false) as MeshInstance3D
		if pond:
			var water := ShaderMaterial.new()
			water.shader = preload("res://living_water.gdshader")
			pond.material_override = water
			pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ponds.append({"node":pond, "material":water})
			for reflection in section.find_children("Grove_water reflection*", "Node3D", true, false): reflection.hide()
			# Bank plants use world placement so the imported pond's non-uniform scale
			# cannot stretch the leaves. Keep the front of the pond open to the camera.
			for i in range(7):
				var angle := PI + PI * float(i) / 6.0
				var at := pond.global_position + Vector3(cos(angle) * 5.3, 0.05, sin(angle) * 2.8)
				var clear := true
				for point in game.route:
					if Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) < 2.3: clear = false
				for pad in game.memory_arena.pads:
					var point: Vector3 = pad.global_position
					if Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) < 2.3: clear = false
				if not clear: continue
				var plant := add_plant(section, "fern" if i % 2 == 0 else "broadleaf", Vector3.ZERO, 0.85, i * 1.7)
				plant.global_position = at
		_full_forest(section)
	for arena in game.canopy.arenas:
		_style_arena(arena)
	_style_arena(game.memory_arena)
	for crown in get_tree().get_nodes_in_group("living_canopy"):
		plants.append({"node":crown, "rest":crown.rotation, "phase":float(plants.size()) * 0.7, "strength":0.008})

func _ground_height(at: Vector2) -> float:
	var result := -0.2
	for mound in [Vector4(0, -1, 13.5, 9.6), Vector4(-4, 4, 7.5, 3.8), Vector4(0, -8.5, 14, 8.5)]:
		var d := pow((at.x - mound.x) / mound.z, 2) + pow((at.y - mound.y) / mound.w, 2)
		if d < 1.0:
			var vertical := 0.45 if mound.x == -4 else 1.1 if mound.y == -8.5 else 1.0
			var base := -0.15 if mound.x == -4 else -0.65 if mound.y == -8.5 else -0.62
			result = maxf(result, base + vertical * sqrt(1.0 - d))
	return result + 0.01

func _full_forest(section: Node3D) -> void:
	var ground_material := ShaderMaterial.new()
	ground_material.shader = preload("res://forest_ground.gdshader")
	for item in section.get_children():
		var title := str(item.name)
		if item is MeshInstance3D and (title.begins_with("MS_Pad_") or title in ["Grove_starting stump", "Grove_starting surface"]):
			var tint := Color.WHITE
			var inset := 0.0
			if title.begins_with("MS_Pad_") and not title.begins_with("MS_Pad_Base_"):
				inset = 0.68
				var original: Material = item.mesh.surface_get_material(0)
				if original is StandardMaterial3D: tint = original.albedo_color
			item.material_override = preload("res://stump_materials.gd").wood(item.mesh.get_aabb().size.x / 2.0, inset, tint)
		if title.begins_with("Grove_storybook tree") or title.begins_with("Grove_cloud") or title.begins_with("Grove_cottage") or title.begins_with("Grove_tree cottage") or title.begins_with("Grove_roof") or title.begins_with("Grove_morning") or title.begins_with("Grove_distant") or title.begins_with("Grove_ground fern") or title.begins_with("Grove_river stone") or title.begins_with("Grove_flower"):
			item.hide()
		if title in ["Grove_forest floor", "Grove_front moss bank", "Grove_velvet meadow"]:
			item.material_override = ground_material
	var garden := Node3D.new()
	garden.name = "FullBlenderForest"
	section.add_child(garden)
	var scenery = preload("res://forest_scenery.gd")
	for i in range(6):
		scenery.tree(garden, Vector3(-14 + i * 5.8, -0.1, -10.5 - (i % 2) * 4), 1.6 + (i % 3) * 0.25, i * 1.5)
	var random := RandomNumberGenerator.new()
	random.seed = 138
	var spots: Array[Vector3] = []
	var planted := 0
	for i in range(1800):
		var at := Vector2(random.randf_range(-13, 13), random.randf_range(-12, 7))
		if pow(at.x / 13.2, 2) + pow((at.y + 1) / 9.1, 2) > 1.0: continue
		if pow((at.x - 5) / 5.6, 2) + pow((at.y - 4.5) / 2.9, 2) < 1.0: continue
		if section == game.stage_path.sections[1] and at.length() < 7.3: continue
		var world := section.to_global(Vector3(at.x, 0, at.y))
		var clear := true
		for point in game.route:
			if Vector2(world.x, world.z).distance_to(Vector2(point.x, point.z)) < 1.8: clear = false
		if not clear: continue
		var pos := Vector3(at.x, _ground_height(at), at.y)
		spots.append(pos)
		if i % 32 == 0 and planted < 35:
			add_plant(garden, "broadleaf" if i % 64 == 0 else "fern", pos, random.randf_range(0.7, 1.15), random.randf_range(0, TAU))
			planted += 1
		if i % 51 == 0: scenery.rock(garden, pos, random.randf_range(1.5, 3.0), i * 0.7)
		if i % 35 == 0: add_plant(garden, ["flower_coral","flower_cream","flower_lilac"][i % 3], pos, 1.1, i * 0.3)
	scenery.grass(garden, spots, 123)
	for i in range(18):
		var angle := TAU * i / 18.0
		scenery.rock(garden, Vector3(5 + cos(angle) * 5.35, 0.20, 4.5 + sin(angle) * 2.7), 1.5 + (i % 3) * 0.4, angle)
	for i in range(3):
		var lily: Node3D = preload("res://assets/living-grove/lily_pad.glb").instantiate()
		garden.add_child(lily)
		lily.position = Vector3(6.7 + i * 0.75, 0.335, 4.2 + sin(i * 1.8) * 0.65)
		lily.scale = Vector3.ONE * (1.6 + i * 0.3)

func _style_arena(arena: Node3D) -> void:
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://forest_ground.gdshader")
	for child in arena.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh and child.mesh.top_radius > 6:
			child.material_override = floor_material
	var spots: Array[Vector3] = []
	for i in range(180):
		var angle := TAU * i / 180.0
		# Grass skirts the edge, below the notes and their labels.
		spots.append(Vector3(cos(angle) * 6.55, -0.24, sin(angle) * 6.55))
	preload("res://forest_scenery.gd").grass(arena, spots, 97)

func _process(delta: float) -> void:
	if game == null or game.paused: return
	elapsed += delta
	var t := elapsed * TAU / 4.0
	for item in plants:
		if not item.node.is_visible_in_tree(): continue
		var phase: float = item.phase
		var strength: float = item.strength
		item.node.rotation = item.rest + Vector3(
			strength * (sin(t + phase) + 0.2 * sin(2 * t + phase)),
			strength * 0.22 * sin(2 * t + phase),
			strength * 0.55 * cos(t + phase + 0.6))
	for pond in ponds:
		if pond.node.is_visible_in_tree(): pond.material.set_shader_parameter("breeze_time", elapsed)
