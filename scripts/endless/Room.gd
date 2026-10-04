class_name Room
extends Node3D

const EXIT_PADDING = 1
const MIN_ROOM_SIZE = 5
const MAX_ROOM_SIZE = 20
const MAX_ROOM_HEIGHT = 10
const SHRINK_EPSILON := 0.05

var depth: int
var size: Vector3
var entrance: Doorway
var exits: Array[Doorway]
var scale_factor: float = 1.0

var previous_room: Room

# Other rooms this room connects to via a matched doorway (either generated from this room,
# or discovered later when a branch loops back into an existing room). Undirected - if A is
# in B's list, B is in A's list too. Used to measure "how many rooms away" something is,
# independent of original generation order/depth.
var connected_rooms: Array[Room] = []

# Whether this room currently has its visual mesh built. A room can exist (bounds, exits,
# path all generated) without a mesh - see apply_layout()'s build_mesh param and show_mesh()/
# hide_mesh() below.
var has_mesh: bool = false

@export var room_path: RoomPath
@export var room_mesh: RoomMesh

@export var debug_room_bound: MeshInstance3D


func set_scale_factor(_scale: float) -> void:
	scale_factor = _scale
	if room_path:
		room_path.cell_size = _scale


func get_doorway_local_to_global(pos: Vector3) -> Vector3:
	return pos + global_position


func get_doorways_local_to_global(doorways: Array[Doorway]) -> Array[Doorway]:
	var global_doorways: Array[Doorway]
	for doorway in doorways:
		global_doorways.append(Doorway.new(get_doorway_local_to_global(doorway.position), doorway.direction * -1))
	return global_doorways


func get_doorway_direction(pos: Vector3) -> Vector3i:
	if pos.x == size.x / 2:
		return Vector3i(1,0,0)
	elif pos.x == -size.x / 2:
		return Vector3i(-1,0,0)
	elif pos.z == size.z / 2:
		return Vector3i(0,0,1)
	elif pos.z == -size.z / 2:
		return Vector3i(0,0,-1)
	return Vector3i.ZERO


# Applies a layout computed (and already overlap-resolved) by RoomPlanner/RoomGen. This is the
# only place Room touches its own bounds/exits now - all the randomness that decides them lives
# in RoomGen, as a pure function of the entrance position, so it can be computed before this
# Node even exists.
func apply_layout(layout: RoomLayout, base_seed: String, build_mesh: bool = true) -> void:
	depth = layout.depth
	set_scale_factor(layout.scale_factor)
	size = layout.size
	global_position = layout.position
	entrance = Doorway.new(layout.entrance.position - layout.position, layout.entrance.direction)
	exits = layout.exits.duplicate()
	(debug_room_bound.mesh as BoxMesh).size = size

	if room_path:
		room_path.set_rng(RoomGen.make_rng(base_seed, layout.position, "path"))
		room_path.generate_path(self)
		room_path.draw_path_debug()

	if build_mesh:
		show_mesh()


# Builds the visible mesh if it isn't already built. Safe to call repeatedly.
func show_mesh() -> void:
	if has_mesh:
		return
	room_mesh.set_room_mesh(self)
	has_mesh = true


# Tears down the visible mesh (room data - bounds, exits, path - stays intact). Safe to call
# repeatedly. Requires RoomMesh to implement clear_mesh(); if it doesn't yet, add a method there
# that frees/clears whatever MeshInstance3D(s) set_room_mesh() created.
func hide_mesh() -> void:
	if not has_mesh:
		return
	if room_mesh and room_mesh.has_method("clear_mesh"):
		room_mesh.clear_mesh()
	has_mesh = false


func remove_exit(exit: Doorway, rebuild_mesh: bool = true) -> void:
	var idx: int = exits.find(exit)
	if idx == -1:
		push_warning("Room: remove_exit called with an exit not in this room's exits list")
		return

	exits.remove_at(idx)

	if rebuild_mesh and room_mesh and has_mesh:
		room_mesh.set_room_mesh(self)


func is_in_bounds(pos: Vector3) -> bool:
	var a: AABB = AABB(global_position - size / 2.0, size)
	return a.has_point(pos)


func _to_string() -> String:
	return "["+name+"] (" + \
	"global_position: "+ str(global_position) + ", " + \
	"size: "+ str(size) + ", " + \
	"entrance_position: "+ str(get_doorway_local_to_global(entrance.position)) + ", " + \
	"entrance_direction: "+ str(entrance.direction) + ", " + \
	"exits: "+ str(len(exits)) + ", " + \
	")"
