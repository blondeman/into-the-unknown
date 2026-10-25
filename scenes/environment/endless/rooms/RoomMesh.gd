class_name RoomMesh
extends Node3D
## Abstract base for every room mesh type. A RoomMesh only knows how to load a room's mesh
## and unload it again; what the room looks like is up to the subclass.

const FLOOR_THICKNESS := 1.0
@export var wall_height := 1
const WALL_THICKNESS := 0.5


## Virtual. Builds everything needed to show room (geometry and collision).
func load_mesh(_room: Room) -> void:
	push_error("RoomMesh.load_mesh() not implemented by " + str(get_script().resource_path))


## Virtual. Tears down everything load_mesh() built. Must be safe to call before load_mesh().
func unload_mesh() -> void:
	push_error("RoomMesh.unload_mesh() not implemented by " + str(get_script().resource_path))
