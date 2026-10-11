class_name Room_EmptyWithRamps
extends Room

const MAX_ROOM_SIZE = 20
const MAX_ROOM_HEIGHT = 10

@export var direction_bias_curve: Curve
@export var exit_count_curve: Curve

@export var room_mesh: RoomMesh


func _generate(_entrance: Doorway) -> void:
	place_at_entrance(_entrance, Vector3(
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE),
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_HEIGHT),
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)) * scale_factor)

	var directions: Array[Vector3i] = Doorway.cardinals.duplicate()
	var exit_count: int
	if is_max_depth():
		exit_count = 0
	elif _entrance:
		directions.remove_at(directions.find(_entrance.direction))
		exit_count = get_exit_count()
	else:
		# no entrance (first room): every side gets an exit
		exit_count = directions.size()
	for i in exit_count:
		directions.remove_at(directions.find(create_exit(directions)))


func _build_mesh() -> void:
	room_mesh.load_mesh(self)


func _clear_mesh() -> void:
	room_mesh.unload_mesh()


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
	add_exit(exit_position, exit_direction)
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
