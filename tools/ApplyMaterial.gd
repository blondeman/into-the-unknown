@tool
extends EditorScript

const MATERIAL = preload("res://textures/dungeon_color_map.tres")

func _run() -> void:
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()

	if selected_nodes.is_empty():
		print("No node selected.")
		return
	
	for node in selected_nodes:
		print("Applying material to: ", node.name)
		apply_material_to_children(node)
	
	print("Done.")

func apply_material_to_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = MATERIAL
			print("  Applied to: ", child.name)
		apply_material_to_children(child)
