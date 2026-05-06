@tool
extends EditorScript

const MATERIAL = preload("res://textures/dungeon_color_map.tres")

func _run() -> void:
	# MeshLibrary is a Resource, not a node — grab it from the FileSystem selection
	var selected = get_editor_interface().get_selected_paths()
	
	if selected.is_empty():
		print("No file selected in FileSystem.")
		return
	
	for path in selected:
		var resource = load(path)
		if not resource is MeshLibrary:
			print("Skipping (not a MeshLibrary): ", path)
			continue
		
		print("Applying material to MeshLibrary: ", path)
		apply_material_to_mesh_library(resource)
		
		# Mark resource as modified so Godot saves it
		ResourceSaver.save(resource, path)
		print("Saved: ", path)
	
	print("Done.")


func apply_material_to_mesh_library(library: MeshLibrary) -> void:
	for item_id in library.get_item_list():
		var mesh = library.get_item_mesh(item_id)
		if mesh == null:
			continue
		
		for surface_idx in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface_idx, MATERIAL)
			print("  Item %d, surface %d: material applied" % [item_id, surface_idx])
