class_name Room
extends Node3D
## Abstract base for every room type.
##
## A room has exactly one entrance and any number of exits. Subclasses decide what the room
## looks like by implementing three virtuals:
##   _generate(entrance)  - pick a size, call place_at_entrance(), then add_exit() for each exit
##   _build_mesh()        - create whatever geometry/collision the room needs
##   _clear_mesh()        - tear that geometry/collision back down
## Everything else (bounds, overlap tests, shrinking, mesh load/unload bookkeeping) lives here.

const EXIT_PADDING = 1
const MIN_ROOM_SIZE = 5
const SHRINK_EPSILON := 0.05

var depth: int
var size: Vector3
var entrance: Doorway
var exits: Array[Doorway] = []
var rng: RandomNumberGenerator
var scale_factor: float = 1.0

var previous_room: Room

## Depth at which generation stops. A room at depth >= max_depth is a dead end: it must not
## create any exits. The root room is depth 0.
var max_depth: int = 10

var mesh_loaded: bool = false

@export var exit_hole: Node3D

## Draws a transparent green box showing the room's bounds. The box is created on the fly.
@export var debug_room_bound: bool = false

var _debug_bound_mesh: MeshInstance3D


func _ready() -> void:
	# every room starts with no mesh until load_mesh() is called
	exit_hole.visible = false
	_clear_mesh()


func set_scale_factor(_scale: float) -> void:
	scale_factor = _scale


func set_rng(_rng: RandomNumberGenerator) -> void:
	rng = _rng


func set_max_depth(_max_depth: int) -> void:
	max_depth = _max_depth


## True if this room is at the final depth and so must not create any exits.
func is_max_depth() -> bool:
	return depth >= max_depth


# --- Generation -------------------------------------------------------------------------

## Decides this room's bounds, entrance and exits. Does NOT build a mesh - call load_mesh()
## once the room has been accepted (e.g. after overlap checks).
## _entrance may be null for the first room, which then has no entrance (entrance stays null).
func generate(_entrance: Doorway, _depth: int, _previous_room: Room = null) -> void:
	depth = _depth
	previous_room = _previous_room
	_generate(_entrance)


## Virtual. Must call place_at_entrance() and then add_exit() for each exit - except when
## is_max_depth() is true, in which case it must add no exits at all.
func _generate(_entrance: Doorway) -> void:
	push_error("Room._generate() not implemented by " + str(get_script().resource_path))


## Sets size and position so the room's entrance lands exactly on _entrance, pointing inward.
## If _entrance is null (the first room), the room has no entrance and is centred at the origin.
func place_at_entrance(_entrance: Doorway, _size: Vector3) -> void:
	size = _size
	if _entrance:
		global_position = _entrance.position + ((_entrance.direction as Vector3) * size / 2)
		entrance = Doorway.new(_entrance.position - global_position, _entrance.direction)
	else:
		global_position = Vector3.ZERO
		entrance = null
	_update_debug_bound()


## Room-local Y of the floor surface. Rooms without an entrance (the first room) use 0.
func get_floor_y() -> float:
	return entrance.position.y if entrance else 0.0


## Creates, resizes or removes the debug bounds box to match debug_room_bound and size.
func _update_debug_bound() -> void:
	if not debug_room_bound:
		if _debug_bound_mesh:
			_debug_bound_mesh.queue_free()
			_debug_bound_mesh = null
		return

	if not _debug_bound_mesh:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.0, 1.0, 0.0, 0.25)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		_debug_bound_mesh = MeshInstance3D.new()
		_debug_bound_mesh.mesh = BoxMesh.new()
		_debug_bound_mesh.material_override = material
		add_child(_debug_bound_mesh)

	(_debug_bound_mesh.mesh as BoxMesh).size = size


## Adds an exit at a room-local position.
func add_exit(position: Vector3, direction: Vector3i) -> Doorway:
	var exit := Doorway.new(position, direction)
	exits.append(exit)
	return exit


func remove_exit(exit: Doorway) -> void:
	var idx: int = exits.find(exit)
	if idx == -1:
		push_warning("Room: remove_exit called with an exit not in this room's exits list")
		return
	exits.remove_at(idx)


# --- Mesh -------------------------------------------------------------------------------

## Builds the mesh if it isn't already built. Safe to call repeatedly. All generation (exits,
## remove_exit, shrink_to_fit) must be finished before the first load_mesh() - the mesh is
## never rebuilt, only loaded and unloaded.
func load_mesh() -> void:
	if mesh_loaded:
		return
	_build_mesh()
	mesh_loaded = true


## Tears the mesh down if it's built. Room data (bounds, entrance, exits) is kept.
func unload_mesh() -> void:
	if not mesh_loaded:
		return
	_clear_mesh()
	mesh_loaded = false


## Virtual.
func _build_mesh() -> void:
	push_error("Room._build_mesh() not implemented by " + str(get_script().resource_path))


## Virtual.
func _clear_mesh() -> void:
	push_error("Room._clear_mesh() not implemented by " + str(get_script().resource_path))


# --- Doorway helpers --------------------------------------------------------------------

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


# --- Bounds / overlap -------------------------------------------------------------------

## Shortest distance from pos to this room's bounds (0 if pos is inside the room).
func distance_to(pos: Vector3) -> float:
	var half: Vector3 = size / 2.0
	var local: Vector3 = pos - global_position
	var outside := Vector3(
		maxf(absf(local.x) - half.x, 0.0),
		maxf(absf(local.y) - half.y, 0.0),
		maxf(absf(local.z) - half.z, 0.0))
	return outside.length()


func is_in_bounds(pos: Vector3) -> bool:
	var a: AABB = AABB(global_position - size / 2.0, size)
	return a.has_point(pos)


func test_overlap(rooms: Array[Room]) -> bool:
	var aabb: AABB = AABB(global_position - size / 2.0, size)
	for room in rooms:
		var test_aabb: AABB = AABB(room.global_position - room.size / 2.0, room.size)
		if aabb.intersects(test_aabb):
			return true
	return false


func get_overlap_volume(other: Room) -> float:
	var a: AABB = AABB(global_position - size / 2.0, size)
	var b: AABB = AABB(other.global_position - other.size / 2.0, other.size)
	if not a.intersects(b):
		return 0.0
	var overlap: AABB = a.intersection(b)
	return overlap.size.x * overlap.size.y * overlap.size.z


func get_overlap_percent(other: Room) -> float:
	var vol: float = size.x * size.y * size.z
	if vol <= 0.0:
		return 0.0
	return get_overlap_volume(other) / vol


## Shrinks this room's far wall (away from the entrance) so it no longer overlaps other.
## Returns false if that isn't possible.
func shrink_to_fit(other: Room, entrance_direction: Vector3i) -> bool:
	var a: AABB = AABB(global_position - size / 2.0, size)
	var b: AABB = AABB(other.global_position - other.size / 2.0, other.size)
	if not a.intersects(b):
		return true

	var dir: Vector3 = Vector3(entrance_direction)
	var axis: int = 0 if dir.x != 0 else 2
	var sign: float = dir.x if axis == 0 else dir.z

	var a_min: float = a.position[axis]
	var a_max: float = a.position[axis] + a.size[axis]
	var b_min: float = b.position[axis]
	var b_max: float = b.position[axis] + b.size[axis]

	var new_extent: float
	if sign > 0:
		# near face (entrance) is a_min, fixed. Only the far wall (a_max) can move.
		if a_max > b_min and a_min <= b_min:
			new_extent = b_min - a_min - SHRINK_EPSILON
		else:
			return false # overlap is on the near/entrance side - can't fix by shrinking
	else:
		if a_min < b_max and a_max >= b_max:
			new_extent = a_max - b_max - SHRINK_EPSILON
		else:
			return false

	if new_extent < MIN_ROOM_SIZE * scale_factor:
		return false

	var new_size: Vector3 = size
	new_size[axis] = new_extent

	for exit in exits:
		if axis == 0 and abs(exit.position.x) > new_extent / 2 - EXIT_PADDING * scale_factor:
			return false
		if axis == 2 and abs(exit.position.z) > new_extent / 2 - EXIT_PADDING * scale_factor:
			return false

	var old_center: Vector3 = global_position
	var shrink_amount: float = size[axis] - new_extent
	size = new_size
	global_position = old_center - (dir.normalized() * shrink_amount / 2.0)
	if entrance:
		# the entrance is stored room-local, so keep it at the same world position
		entrance = Doorway.new(entrance.position + (old_center - global_position), entrance.direction)
	_update_debug_bound()

	# verify - never trust the math blindly
	var a2: AABB = AABB(global_position - size / 2.0, size)
	if a2.intersects(b):
		return false

	return true


func _generate_hole():
	pass


func generate_hole(hole_position: Vector3):
	exit_hole.global_position = hole_position
	exit_hole.visible = true
	var area: Area3D = exit_hole.find_child("Area3D") as Area3D
	area.body_entered.connect(hole_entered)


func hole_entered(body: Node3D):
	if body.get_parent() is PlayerController:
		GameManager.load_endless()


func _to_string() -> String:
	return "["+name+"] (" + \
	"global_position: "+ str(global_position) + ", " + \
	"size: "+ str(size) + ", " + \
	"entrance_position: "+ (str(get_doorway_local_to_global(entrance.position)) if entrance else "none") + ", " + \
	"entrance_direction: "+ (str(entrance.direction) if entrance else "none") + ", " + \
	"exits: "+ str(len(exits)) + ", " + \
	")"
