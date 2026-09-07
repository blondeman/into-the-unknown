class_name RoomPath
extends Node3D

const STEP_CAP_MULTIPLIER := 4
const MIN_STEP_CAP := 20

var rng: RandomNumberGenerator
var paths: Array[Array] = []  # one Array[Vector3i] per entrance->exit connection
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
	return Vector3i(roundi(pos.x), roundi(pos.y), roundi(pos.z))


func get_bounds_min(room: Room) -> Vector3i:
	return Vector3i(
		int(-floor(room.size.x / 2) + Room.EXIT_PADDING),
		int(-floor(room.size.y / 2) + Room.EXIT_PADDING),
		int(-floor(room.size.z / 2) + Room.EXIT_PADDING))


func get_bounds_max(room: Room) -> Vector3i:
	return Vector3i(
		int(floor(room.size.x / 2) - Room.EXIT_PADDING),
		int(floor(room.size.y / 2) - Room.EXIT_PADDING),
		int(floor(room.size.z / 2) - Room.EXIT_PADDING))


func is_in_bounds(cell: Vector3i, bounds_min: Vector3i, bounds_max: Vector3i) -> bool:
	return cell.x >= bounds_min.x and cell.x <= bounds_max.x \
		and cell.y >= bounds_min.y and cell.y <= bounds_max.y \
		and cell.z >= bounds_min.z and cell.z <= bounds_max.z


func _build_move_directions() -> Array[Vector3i]:
	var dirs: Array[Vector3i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dy == 0 and dz == 0:
					continue
				if dy != 0 and dx == 0 and dz == 0:
					continue  # no pure vertical step - must be diagonal
				dirs.append(Vector3i(dx, dy, dz))
	return dirs


func walk_path(start: Vector3i, goal: Vector3i, bounds_min: Vector3i, bounds_max: Vector3i, occupied: Dictionary) -> Array[Vector3i]:
	var cells: Array[Vector3i] = [start]
	var visited_this_path: Dictionary = {start: true}
	var current: Vector3i = start

	var manhattan: int = abs(goal.x - start.x) + abs(goal.y - start.y) + abs(goal.z - start.z)
	var max_steps: int = max(manhattan * STEP_CAP_MULTIPLIER, MIN_STEP_CAP)
	var steps: int = 0

	while current != goal and steps < max_steps:
		var to_goal: Vector3 = Vector3(goal - current)
		var to_goal_dir: Vector3 = to_goal.normalized() if to_goal.length() > 0.001 else Vector3.ZERO

		var candidates: Array[Vector3i] = []
		var weights: Array[float] = []
		var total_weight: float = 0.0

		for move in _move_directions:
			var next: Vector3i = current + move
			if next != goal and not is_in_bounds(next, bounds_min, bounds_max):
				continue
			if next == goal:
				pass  # always allow stepping onto the goal, even if "occupied"
			elif visited_this_path.has(next):
				continue  # never re-enter our own trail
			elif occupied.has(next):
				continue  # never cross another path's trail

			var dot: float = Vector3(move).normalized().dot(to_goal_dir)
			var w: float = pow(max(dot + 1.0, 0.01), 3.0)
			candidates.append(next)
			weights.append(w)
			total_weight += w

		if candidates.is_empty():
			break

		var r: float = rng.randf() * total_weight
		var cumulative: float = 0.0
		var chosen: Vector3i = candidates[-1]
		for i in candidates.size():
			cumulative += weights[i]
			if r <= cumulative:
				chosen = candidates[i]
				break

		current = chosen
		cells.append(current)
		visited_this_path[current] = true
		steps += 1

	# guaranteed-connect fallback, still respecting occupancy where possible
	while current != goal:
		var to_goal2: Vector3 = Vector3(goal - current)
		var to_goal_dir2: Vector3 = to_goal2.normalized() if to_goal2.length() > 0.001 else Vector3.ZERO
		var best_move: Vector3i = _move_directions[0]
		var best_dot: float = -INF
		var found_unblocked: bool = false

		for move in _move_directions:
			var next: Vector3i = current + move
			var blocked: bool = (next != goal) and (visited_this_path.has(next) or occupied.has(next))
			var dot: float = Vector3(move).normalized().dot(to_goal_dir2)
			if not blocked and dot > best_dot:
				best_dot = dot
				best_move = move
				found_unblocked = true

		if not found_unblocked:
			# every neighbor is blocked - allow crossing as last resort so it still terminates
			best_dot = -INF
			for move in _move_directions:
				var dot: float = Vector3(move).normalized().dot(to_goal_dir2)
				if dot > best_dot:
					best_dot = dot
					best_move = move

		current += best_move
		cells.append(current)
		visited_this_path[current] = true

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
			# look as far ahead as possible for a valid single-move shortcut
			var best_j: int = -1
			for j in range(result.size() - 1, i + 1, -1):
				var delta: Vector3i = result[j] - result[i]
				if _move_directions.has(delta):
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
