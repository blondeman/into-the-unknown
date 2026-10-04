class_name RoomGen
extends RefCounted

# Quantizes a world position so float drift can't break dictionary-key lookups or equality
# checks between two paths that computed "the same" position slightly differently.
static func quantize(position: Vector3) -> Vector3:
	return (position * 100.0).round() / 100.0


# Deterministic RNG seeded purely from (base_seed, position, salt). Same inputs always produce
# the same generator state, regardless of call order or how many other rooms exist yet - this
# is what makes a room's layout a pure function of where its entrance is.
static func make_rng(base_seed: String, position: Vector3, salt: String = "") -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(base_seed + salt + str(quantize(position)))
	return rng


static func compute_exit_count(rng: RandomNumberGenerator, exit_count_curve: Curve) -> int:
	var t: float = rng.randf()
	var sampled: float = exit_count_curve.sample(t)
	var mapped: float = lerp(1.0, 3.0, sampled)
	return clampi(roundi(mapped), 1, 3)


static func pick_weighted_direction(rng: RandomNumberGenerator, direction_bias_curve: Curve, room_position: Vector3, directions: Array[Vector3i]) -> Vector3i:
	var outward: Vector3 = Vector3.ZERO
	if room_position.length() > 0.001:
		outward = room_position.normalized()
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


static func create_exit(rng: RandomNumberGenerator, direction_bias_curve: Curve, room_position: Vector3, size: Vector3, scale_factor: float, directions: Array[Vector3i]) -> Doorway:
	var exit_direction: Vector3i = pick_weighted_direction(rng, direction_bias_curve, room_position, directions)
	var size_cells: Vector3 = size / scale_factor

	var exit_position: Vector3 = ((exit_direction as Vector3) * size_cells / 2) * -1
	exit_position.y = rng.randi_range(-floor(size_cells.y / 2) + Room.EXIT_PADDING, floor(size_cells.y / 2) - Room.EXIT_PADDING)
	if abs(exit_direction.x) > 0:
		exit_position.z = rng.randi_range(-floor(size_cells.z / 2) + Room.EXIT_PADDING, floor(size_cells.z / 2) - Room.EXIT_PADDING)
	else:
		exit_position.x = rng.randi_range(-floor(size_cells.x / 2) + Room.EXIT_PADDING, floor(size_cells.x / 2) - Room.EXIT_PADDING)

	exit_position *= scale_factor
	return Doorway.new(exit_position, exit_direction)


# Pure computation of a room's size/position/exits from where its entrance is - no Node involved,
# so this can be called purely to "peek" at what a neighbor would look like without creating
# anything, and will always return the exact same result for the same entrance position.
static func compute_layout(entrance: Doorway, depth: int, scale_factor: float, base_seed: String, direction_bias_curve: Curve, exit_count_curve: Curve) -> RoomLayout:
	var layout := RoomLayout.new()
	layout.depth = depth
	layout.entrance = entrance
	layout.scale_factor = scale_factor

	var rng := make_rng(base_seed, entrance.position)

	layout.size = Vector3(
		rng.randi_range(Room.MIN_ROOM_SIZE, Room.MAX_ROOM_SIZE),
		rng.randi_range(Room.MIN_ROOM_SIZE, Room.MAX_ROOM_HEIGHT),
		rng.randi_range(Room.MIN_ROOM_SIZE, Room.MAX_ROOM_SIZE)) * scale_factor
	layout.position = entrance.position + ((entrance.direction as Vector3) * layout.size / 2)

	var directions: Array[Vector3i] = Doorway.cardinals.duplicate()
	directions.remove_at(directions.find(entrance.direction))

	var exit_count: int = compute_exit_count(rng, exit_count_curve)
	for i in exit_count:
		var exit: Doorway = create_exit(rng, direction_bias_curve, layout.position, layout.size, scale_factor, directions)
		directions.remove_at(directions.find(exit.direction))
		layout.exits.append(exit)

	return layout


static func overlap_volume(a_pos: Vector3, a_size: Vector3, b_pos: Vector3, b_size: Vector3) -> float:
	var a := AABB(a_pos - a_size / 2.0, a_size)
	var b := AABB(b_pos - b_size / 2.0, b_size)
	if not a.intersects(b):
		return 0.0
	var overlap: AABB = a.intersection(b)
	return overlap.size.x * overlap.size.y * overlap.size.z


static func overlap_percent(a_pos: Vector3, a_size: Vector3, b_pos: Vector3, b_size: Vector3) -> float:
	var vol: float = a_size.x * a_size.y * a_size.z
	if vol <= 0.0:
		return 0.0
	return overlap_volume(a_pos, a_size, b_pos, b_size) / vol


# Mutates layout in place to shrink it away from other_pos/other_size - same rule as the
# original Room.shrink_to_fit: only the far wall (away from the entrance) is allowed to move.
# Returns false (and leaves layout untouched) if it can't be resolved this way.
static func try_shrink(layout: RoomLayout, other_pos: Vector3, other_size: Vector3) -> bool:
	var a := AABB(layout.position - layout.size / 2.0, layout.size)
	var b := AABB(other_pos - other_size / 2.0, other_size)
	if not a.intersects(b):
		return true

	var dir: Vector3 = Vector3(layout.entrance.direction)
	var axis: int = 0 if dir.x != 0 else 2
	var sign: float = dir.x if axis == 0 else dir.z

	var a_min: float = a.position[axis]
	var a_max: float = a.position[axis] + a.size[axis]
	var b_min: float = b.position[axis]
	var b_max: float = b.position[axis] + b.size[axis]

	var new_extent: float
	if sign > 0:
		if a_max > b_min and a_min <= b_min:
			new_extent = b_min - a_min - Room.SHRINK_EPSILON
		else:
			return false
	else:
		if a_min < b_max and a_max >= b_max:
			new_extent = a_max - b_max - Room.SHRINK_EPSILON
		else:
			return false

	if new_extent < Room.MIN_ROOM_SIZE * layout.scale_factor:
		return false

	var new_size: Vector3 = layout.size
	new_size[axis] = new_extent

	for exit in layout.exits:
		if axis == 0 and abs(exit.position.x) > new_extent / 2 - Room.EXIT_PADDING * layout.scale_factor:
			return false
		if axis == 2 and abs(exit.position.z) > new_extent / 2 - Room.EXIT_PADDING * layout.scale_factor:
			return false

	var old_center: Vector3 = layout.position
	var shrink_amount: float = layout.size[axis] - new_extent
	layout.size = new_size
	layout.position = old_center - (dir.normalized() * shrink_amount / 2.0)

	# verify — never trust the math blindly
	var a2 := AABB(layout.position - layout.size / 2.0, layout.size)
	if a2.intersects(b):
		return false

	return true
