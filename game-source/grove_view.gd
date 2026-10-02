extends Node3D

func _enter_tree() -> void:
	# The saved preview gives the editor the same forest as stage one. Remove
	# it before child _ready methods build the animated, interactive stages.
	var preview := get_node_or_null("EditorForestPreview")
	if preview:
		preview.free()
	get_node("Melody Grove • musical forest").show()

# These prototype objects were hidden in Blender but included in the GLB.
# Keep the source model intact and hide them only in the playable scene.
func _ready() -> void:
	var forest := get_node("Melody Grove • musical forest")
	for object_name in ["MS_Stage_Base", "MS_Stage_Surface", "MS_World_Floor", "MS_Target", "MS_Help"]:
		var object := forest.find_child(object_name, true, false) as Node3D
		if object:
			object.hide()
