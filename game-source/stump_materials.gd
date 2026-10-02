extends RefCounted
static func wood(radius: float, inset := 0.0, tint := Color.WHITE) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://stump_wood.gdshader")
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("note_inset", inset)
	material.set_shader_parameter("note_color", tint)
	return material
