@tool
extends EditorScript

func _run() -> void:
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()

	if selected_nodes.is_empty():
		push_error("No node selected. Select the parent node in the scene tree first.")
		return

	var parent = selected_nodes[0]
	print("Processing children of: ", parent.name)

	var children = parent.get_children().duplicate()
	var converted = 0

	for child in children:
		if child is MeshInstance3D:
			_convert_to_rigidbody(child, parent)
			converted += 1

	print("Done! Converted %d mesh(es) to RigidBody3D." % converted)

	if converted == 0:
		push_warning("No MeshInstance3D children found under '%s'." % parent.name)

	var break_script = load("res://scripts/Break.gd")
	if break_script == null:
		push_error("Could not find res://Break.gd — make sure the path is correct.")
		return
	parent.set_script(break_script)


func _convert_to_rigidbody(mesh_instance: MeshInstance3D, parent: Node) -> void:
	var mesh = mesh_instance.mesh
	if mesh == null:
		push_warning("Skipping '%s' — no mesh assigned." % mesh_instance.name)
		return

	var mesh_transform = mesh_instance.transform

	var rigid_body = RigidBody3D.new()
	rigid_body.name = mesh_instance.name
	rigid_body.transform = Transform3D.IDENTITY

	rigid_body.collision_layer = 0

	var shape = mesh.create_convex_shape(true, true)

	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.transform = mesh_transform
	
	var new_mesh_instance = MeshInstance3D.new()
	new_mesh_instance.name = "MeshInstance3D"
	new_mesh_instance.mesh = mesh
	new_mesh_instance.transform = mesh_transform

	for i in range(mesh.get_surface_count()):
		var mat = mesh_instance.get_surface_override_material(i)
		if mat:
			new_mesh_instance.set_surface_override_material(i, mat)

	var scene_root = mesh_instance.get_tree().edited_scene_root
	var index = mesh_instance.get_index()

	parent.add_child(rigid_body)
	parent.move_child(rigid_body, index)
	rigid_body.owner = scene_root

	rigid_body.add_child(collision_shape)
	collision_shape.owner = scene_root

	rigid_body.add_child(new_mesh_instance)
	new_mesh_instance.owner = scene_root

	mesh_instance.queue_free()

	print("  Converted: %s" % rigid_body.name)
