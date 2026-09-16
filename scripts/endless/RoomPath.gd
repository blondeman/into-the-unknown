class_name RoomPath
extends Node3D

const FLAT_PREFERENCE_MULTIPLIER := 4.0
const STEP_CAP_MULTIPLIER := 4
const MIN_STEP_CAP := 20

var rng: RandomNumberGenerator
var paths: Array[Array] = []
var _move_directions: Array[Vector3i] = []

@export var path_color: Color = Color.YELLOW
@export var cell_size: float = 1.0

var _debug_mesh_instance: MeshInstance3D


func set_rng(_rng: RandomNumberGenerator) -> void:
	rng = _rng


func generate_path(room: Room) -> void:
	paths.clear()
	if room.entrance == null:
		return
	if _move_directions.is_empty():
		_move_directions = _build_move_directions()

	var start: Vector3i = to_grid(room.entrance.position)
	var bounds_min: Vector3i = get_bounds_min(room)
	var bounds_max: Vector3i = get_bounds_max(room)

	var occupied: Dictionary = {}  # Vector3i -> true, shared across all paths in this room
	occupied[start] = true

	for exit in room.exits:
		var goal: Vector3i = to_grid(exit.position)
		var cells: Array[Vector3i] = walk_path(start, goal, bounds_min, bounds_max, occupied)
		cells = simplify_path(cells)
		for cell in cells:
			occupied[cell] = true
		paths.append(cells)


func to_grid(pos: Vector3) -> Vector3i:
	return Vector3i(roundi(pos.x / cell_size), roundi(pos.y / cell_size), roundi(pos.z / cell_size))


func get_bounds_min(room: Room) -> Vector3i:
	return Vector3i(
		int(-floor(room.size.x / (2 * cell_size)) + Room.EXIT_PADDING),
		int(-floor(room.size.y / (2 * cell_size)) + Room.EXIT_PADDING),
		int(-floor(room.size.z / (2 * cell_size)) + Room.EXIT_PADDING))


func get_bounds_max(room: Room) -> Vector3i:
	return Vector3i(
		int(floor(room.size.x / (2 * cell_size)) - Room.EXIT_PADDING),
		int(floor(room.size.y / (2 * cell_size)) - Room.EXIT_PADDING),
		int(floor(room.size.z / (2 * cell_size)) - Room.EXIT_PADDING))


func is_in_bounds(cell: Vector3i, bounds_min: Vector3i, bounds_max: Vector3i) -> bool:
	return cell.x >= bounds_min.x and cell.x <= bounds_max.x \
		and cell.y >= bounds_min.y and cell.y <= bounds_max.y \
		and cell.z >= bounds_min.z and cell.z <= bounds_max.z


func _move_weight(move: Vector3i, to_goal_dir: Vector3) -> float:
	var dot: float = Vector3(move).normalized().dot(to_goal_dir)
	var w: float = pow(max(dot + 1.0, 0.01), 3.0)
	if move.y == 0:
		w *= FLAT_PREFERENCE_MULTIPLIER
	return w


func _horizontal(move: Vector3i) -> Vector3i:
	return Vector3i(move.x, 0, move.z)


func _build_move_directions() -> Array[Vector3i]:
	var dirs: Array[Vector3i] = []
	var flat_moves: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
		Vector3i(1, 0, 1), Vector3i(1, 0, -1),
		Vector3i(-1, 0, 1), Vector3i(-1, 0, -1),
	]
	dirs.append_array(flat_moves)

	for flat in flat_moves:
		dirs.append(Vector3i(flat.x, 1, flat.z))
		dirs.append(Vector3i(flat.x, -1, flat.z))

	dirs.append(Vector3i(0, 1, 0))
	dirs.append(Vector3i(0, -1, 0))

	return dirs


func is_move_legal(move: Vector3i, last_move: Vector3i, has_last_move: bool) -> bool:
	if has_last_move and move == -last_move:
		return false  # no exact 180 reversal, covers pure vertical (0,1,0) <-> (0,-1,0) too

	if move.x == 0 and move.z == 0:
		return true  # pure vertical move - always legal (aside from the reversal check above)

	if has_last_move:
		var h_move: Vector3i = _horizontal(move)
		var h_last: Vector3i = _horizontal(last_move)
		if h_move != Vector3i.ZERO and h_last != Vector3i.ZERO and h_move == -h_last:
			return false  # no reversing horizontal direction

	if move.y == 0:
		return true

	if not has_last_move:
		return false

	# diagonal climbing must continue the same horizontal direction as the last move
	return _horizontal(move) == _horizontal(last_move)


func walk_path(start: Vector3i, goal: Vector3i, bounds_min: Vector3i, bounds_max: Vector3i, occupied: Dictionary) -> Array[Vector3i]:
	var cells: Array[Vector3i] = [start]
	var visited_this_path: Dictionary = {start: true}
	var current: Vector3i = start
	var last_move: Vector3i = Vector3i.ZERO
	var has_last_move: bool = false

	var manhattan: int = abs(goal.x - start.x) + abs(goal.y - start.y) + abs(goal.z - start.z)
	var max_steps: int = max(manhattan * STEP_CAP_MULTIPLIER, MIN_STEP_CAP)
	var steps: int = 0

	while current != goal and steps < max_steps:
		var to_goal: Vector3 = Vector3(goal - current)
		var to_goal_dir: Vector3 = to_goal.normalized() if to_goal.length() > 0.001 else Vector3.ZERO

		var candidates: Array[Vector3i] = []
		var candidate_moves: Array[Vector3i] = []
		var weights: Array[float] = []
		var total_weight: float = 0.0

		for move in _move_directions:
			if not is_move_legal(move, last_move, has_last_move):
				continue
			var next: Vector3i = current + move
			if next != goal and not is_in_bounds(next, bounds_min, bounds_max):
				continue
			if next != goal:
				if visited_this_path.has(next):
					continue
				if occupied.has(next):
					continue

			var w: float = _move_weight(move, to_goal_dir)
			candidates.append(next)
			candidate_moves.append(move)
			weights.append(w)
			total_weight += w

		if candidates.is_empty():
			break

		var r: float = rng.randf() * total_weight
		var cumulative: float = 0.0
		var chosen: Vector3i = candidates[-1]
		var chosen_move: Vector3i = candidate_moves[-1]
		for i in candidates.size():
			cumulative += weights[i]
			if r <= cumulative:
				chosen = candidates[i]
				chosen_move = candidate_moves[i]
				break

		current = chosen
		last_move = chosen_move
		has_last_move = true
		cells.append(current)
		visited_this_path[current] = true
		steps += 1

	# guaranteed-connect fallback, still respecting move legality + occupancy where possible
	var fallback_steps: int = 0
	var fallback_cap: int = max(manhattan * STEP_CAP_MULTIPLIER * 2, MIN_STEP_CAP * 2)

	while current != goal and fallback_steps < fallback_cap:
		var to_goal2: Vector3 = Vector3(goal - current)
		var to_goal_dir2: Vector3 = to_goal2.normalized() if to_goal2.length() > 0.001 else Vector3.ZERO
		var best_move: Vector3i = Vector3i.ZERO
		var best_score: float = -INF
		var found_unblocked: bool = false

		for move in _move_directions:
			if not is_move_legal(move, last_move, has_last_move):
				continue
			var next: Vector3i = current + move
			var blocked: bool = (next != goal) and (visited_this_path.has(next) or occupied.has(next))
			if blocked:
				continue
			var score: float = _move_weight(move, to_goal_dir2)
			if score > best_score:
				best_score = score
				best_move = move
				found_unblocked = true

		if not found_unblocked:
			best_score = -INF
			for move in _move_directions:
				if not is_move_legal(move, last_move, has_last_move):
					continue
				var dot: float = Vector3(move).normalized().dot(to_goal_dir2)
				if dot > best_score:
					best_score = dot
					best_move = move
					found_unblocked = true

		if not found_unblocked:
			push_warning("RoomPath: no legal move available, aborting before reaching goal")
			break

		current += best_move
		last_move = best_move
		has_last_move = true
		cells.append(current)
		visited_this_path[current] = true
		fallback_steps += 1

	if current != goal:
		push_warning("RoomPath: failed to connect path to goal within step cap")

	return cells


func simplify_path(cells: Array[Vector3i]) -> Array[Vector3i]:
	if cells.size() <= 2:
		return cells

	var result: Array[Vector3i] = cells.duplicate()
	var changed: bool = true

	while changed:
		changed = false
		var i: int = 0
		while i < result.size() - 2:
			var best_j: int = -1
			for j in range(result.size() - 1, i + 1, -1):
				var delta: Vector3i = result[j] - result[i]
				if delta.y == 0 and _move_directions.has(delta):
					best_j = j
					break
			if best_j != -1:
				result = result.slice(0, i + 1) + result.slice(best_j)
				changed = true
			i += 1

	return result


func draw_path_debug() -> void:
	if _debug_mesh_instance:
		_debug_mesh_instance.queue_free()

	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = path_color
	material.vertex_color_use_as_albedo = true

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	for cells in paths:
		for i in range(cells.size() - 1):
			var a: Vector3 = Vector3(cells[i]) * cell_size
			var b: Vector3 = Vector3(cells[i + 1]) * cell_size
			immediate_mesh.surface_add_vertex(a)
			immediate_mesh.surface_add_vertex(b)

	immediate_mesh.surface_end()

	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.mesh = immediate_mesh
	_debug_mesh_instance.material_override = material
	add_child(_debug_mesh_instance)
