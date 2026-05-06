@tool
extends EditorScript

var separation: float = 20.0
var columns: int = 8

func _run() -> void:
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	if selected_nodes.is_empty():
		push_error("No node selected. Select the parent node in the scene tree first.")
		return
	var parent = selected_nodes[0]
	print("Processing children of: ", parent.name)
	var children = parent.get_children().duplicate()
	for i in children.size():
		var child = children[i]
		var col = i % columns
		var row = i / columns
		child.position = Vector3(col * separation, 0, row * separation)
	print("Done. Arranged %d children into %d columns." % [children.size(), columns])
