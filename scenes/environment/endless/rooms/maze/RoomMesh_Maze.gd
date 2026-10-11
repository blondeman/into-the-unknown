class_name RoomMesh_Maze
extends RoomMesh
## Mesh for a Room_Maze. The mesh itself is still empty - the only thing it can draw so far is
## the debug path.

## Draws the room's random-walk path as one plane per grid cell, tilted on up and down moves.
@export var debug_path: bool = false

var _debug_planes: Array[MeshInstance3D] = []


func load_mesh(room: Room) -> void:
	_clear_debug_path()
	if debug_path:
		_draw_debug_path(room)


func unload_mesh() -> void:
	_clear_debug_path()


func _draw_debug_path(room: Room) -> void:
	var maze := room as Room_Maze
	if not maze:
		push_error("RoomMesh_Maze can only draw Room_Maze rooms")
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.6, 0.1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for tile in maze.path_tiles:
		var dir: Vector3i = tile.direction
		var slope: float = tile.slope

		# a plane that runs along `dir` and rises by `slope` per cell
		var forward := Vector3(dir.x, slope, dir.z).normalized()
		var normal := Vector3(-slope * dir.x, 1.0, -slope * dir.z).normalized()

		# one cell wide; stretched along the slope so it still covers exactly one cell of floor
		var plane := PlaneMesh.new()
		plane.size = Vector2(maze.scale_factor, maze.scale_factor * sqrt(1.0 + slope * slope))

		var instance := MeshInstance3D.new()
		instance.mesh = plane
		instance.material_override = material
		add_child(instance)
		instance.transform = Transform3D(Basis(normal.cross(forward), normal, forward), tile.position)
		_debug_planes.append(instance)


func _clear_debug_path() -> void:
	for plane in _debug_planes:
		plane.queue_free()
	_debug_planes.clear()
