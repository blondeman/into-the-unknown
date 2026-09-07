class_name Room
extends Node3D

const EXIT_PADDING = 1
const MIN_ROOM_SIZE = 5
const MAX_ROOM_SIZE = 20
const MAX_ROOM_HEIGHT = 10
const SHRINK_EPSILON := 0.05

var size: Vector3
var entrance: Doorway
var exits: Array[Doorway]
var rng: RandomNumberGenerator
var scale_factor: float = 1.0

@export var direction_bias_curve: Curve
@export var exit_count_curve: Curve

@export var room_path: RoomPath

@export var debug_room_bound: MeshInstance3D
@export var debug_room_entrance: MeshInstance3D


func set_scale_factor(_scale: float) -> void:
	scale_factor = _scale
	if room_path:
		room_path.cell_size = _scale


func set_rng(_rng: RandomNumberGenerator) -> void:
	rng = _rng


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


func generate_room(_entrance: Doorway) -> Array[Doorway]:
	generate_room_bounds(_entrance)
	generate_exits(_entrance)
	
	room_path.set_rng(rng)
	room_path.generate_path(self)
	room_path.draw_path_debug()
	
	return get_doorways_local_to_global(exits)


func generate_room_bounds(_entrance: Doorway):
	size = Vector3(
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE),
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_HEIGHT),
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)) * scale_factor
	global_position = _entrance.position + ((_entrance.direction as Vector3) * size / 2)
	entrance = Doorway.new(_entrance.position - global_position, _entrance.direction)
	(debug_room_bound.mesh as BoxMesh).size = size

	debug_room_entrance.position = entrance.position


func generate_exits(_entrance: Doorway) -> Array[Doorway]:
	var directions: Array[Vector3i] = Doorway.cardinals.duplicate()
	directions.remove_at(directions.find(_entrance.direction))
	for i in get_exit_count():
		directions.remove_at(directions.find(create_exit(directions)))
	return get_doorways_local_to_global(exits)


func create_exit(directions: Array[Vector3i]) -> Vector3i:
	var exit_direction: Vector3i = pick_weighted_direction(directions)
	var size_cells: Vector3 = size / scale_factor

	var exit_position: Vector3 = ((exit_direction as Vector3) * size_cells / 2) * -1
	exit_position.y = rng.randi_range(-floor(size_cells.y/2) + EXIT_PADDING, floor(size_cells.y/2) - EXIT_PADDING)
	if abs(exit_direction.x) > 0:
		exit_position.z = rng.randi_range(-floor(size_cells.z/2) + EXIT_PADDING, floor(size_cells.z/2) - EXIT_PADDING)
	else:
		exit_position.x = rng.randi_range(-floor(size_cells.x/2) + EXIT_PADDING, floor(size_cells.x/2) - EXIT_PADDING)

	exit_position *= scale_factor
	exits.append(Doorway.new(exit_position, exit_direction))
	return exit_direction


func get_exit_count() -> int:
	var t: float = rng.randf()
	var sampled: float = exit_count_curve.sample(t)
	var mapped: float = lerp(1.0, 3.0, sampled)
	return clampi(roundi(mapped), 1, 3)


func pick_weighted_direction(directions: Array[Vector3i]) -> Vector3i:
	var outward: Vector3 = Vector3.ZERO
	if global_position.length() > 0.001:
		outward = global_position.normalized()
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for dir in directions:
		var dot: float = Vector3(dir).dot(outward)
		var t: float = (dot + 1.0) / 2.0
		var w: float = max(direction_bias_curve.sample(t), 0.0)
		weights.append(w)
		total_weight += w
	if total_weight <= 0.0:
		return directions[rng.randi_range(0, directions.size() - 1)]
	var r: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for i in directions.size():
		cumulative += weights[i]
		if r <= cumulative:
			return directions[i]
	return directions[-1]


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
		# only fixable if a_max is the thing poking into b
		if a_max > b_min and a_min <= b_min:
			new_extent = b_min - a_min - SHRINK_EPSILON
		else:
			return false # overlap is on the near/entrance side — can't fix by shrinking
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
	(debug_room_bound.mesh as BoxMesh).size = size

	# verify — never trust the math blindly
	var a2: AABB = AABB(global_position - size / 2.0, size)
	if a2.intersects(b):
		return false

	return true


func sample_curve_x(curve: Curve2D, x: float) -> float:
	var points := curve.get_baked_points()
	if points.is_empty():
		return 1.0
	if x <= points[0].x:
		return points[0].y
	if x >= points[-1].x:
		return points[-1].y
	for i in range(points.size() - 1):
		var p0: Vector2 = points[i]
		var p1: Vector2 = points[i + 1]
		if x >= p0.x and x <= p1.x:
			var t: float = 0.0 if p1.x == p0.x else (x - p0.x) / (p1.x - p0.x)
			return lerp(p0.y, p1.y, t)
	return points[-1].y


func _to_string() -> String:
	return "["+name+"] (" + \
	"global_position: "+ str(global_position) + ", " + \
	"size: "+ str(size) + ", " + \
	"entrance_position: "+ str(get_doorway_local_to_global(entrance.position)) + ", " + \
	"entrance_direction: "+ str(entrance.direction) + ", " + \
	"exits: "+ str(len(exits)) + ", " + \
	")"
