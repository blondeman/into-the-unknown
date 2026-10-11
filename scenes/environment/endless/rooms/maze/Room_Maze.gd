class_name Room_Maze
extends Room
## A room whose interior is a set of random walks on the room's grid.
##
## Every walk starts at the entrance (or the room's centre for the first room) and wanders until
## it touches a wall that doesn't have an exit yet - that is where the exit gets created. The
## walks themselves are kept in `walks` (grid cells) and `path_tiles` (one entry per cell, for
## drawing). Nothing here builds geometry; see RoomMesh_Maze.

const MAX_ROOM_SIZE = 20
const MAX_ROOM_HEIGHT = 10

## Longest horizontal run of a single move. A move may rise or fall at most as many cells as it
## runs, so slopes never exceed 45 degrees: 1 up over 2 across is fine, 2 up over 1 across isn't.
const MAX_RUN := 2

const WALK_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## A walk that hasn't found a free wall after grid.x * grid.z * this many steps is walked
## straight to the nearest free wall instead.
const WALK_STEP_LIMIT_FACTOR := 4

@export var exit_count_curve: Curve
@export var room_mesh: RoomMesh

## Relative likelihood of a 2-cell move compared to a 1-cell move.
@export var long_step_weight: float = 0.4

## Relative likelihood of a sloped move compared to a flat one.
@export var slope_weight: float = 0.3

## Room size in cells. x and z are always odd so the entrance (which sits in the middle of its
## wall) lines up with a cell centre.
var grid_size: Vector3i

## Grid level (y index) that sits at the room's local y = 0, i.e. the entrance height.
var floor_level: int

var start_cell: Vector3i

## Each walk is an Array[Vector3i] of grid cells, in order, starting at start_cell.
var walks: Array[Array] = []

## Flattened, de-duplicated path for drawing. Each entry: {"position": Vector3 (room-local, cell
## centre), "direction": Vector3i (horizontal travel), "slope": float (rise per cell of run)}.
var path_tiles: Array[Dictionary] = []


func _generate(_entrance: Doorway) -> void:
	place_at_entrance(_entrance, Vector3(
		_make_odd(rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)),
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_HEIGHT),
		_make_odd(rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE))) * scale_factor)
	_generate_walks()


func _build_mesh() -> void:
	room_mesh.load_mesh(self)


func _clear_mesh() -> void:
	room_mesh.unload_mesh()


## The walks depend on the room's size, so shrinking means redoing them (and with them the exits).
func shrink_to_fit(other: Room, entrance_direction: Vector3i) -> bool:
	var old_exits: Array[Doorway] = exits.duplicate()
	exits.clear() # they're regenerated for the new size, so they must not block the shrink
	if not super.shrink_to_fit(other, entrance_direction):
		exits = old_exits
		return false
	_generate_walks()
	return true


# --- Walk generation --------------------------------------------------------------------

func _generate_walks() -> void:
	exits.clear()
	walks.clear()
	_compute_grid()
	start_cell = _get_start_cell()

	var walls: Array[Vector3i] = Doorway.cardinals.duplicate()
	var walk_count: int
	if is_max_depth():
		walk_count = 0
	elif entrance:
		walls.erase(entrance.direction)
		walk_count = mini(get_exit_count(), walls.size())
	else:
		walk_count = walls.size() # first room: an exit on every side

	for _i in walk_count:
		var result: Dictionary = _random_walk(start_cell, walls)
		var path: Array = result.path
		var wall: Vector3i = result.wall
		walks.append(path)
		walls.erase(wall)
		add_exit(_exit_position(path.back(), wall), wall)

	if is_max_depth():
		# dead end: no exits, but still wander so the room isn't empty
		var no_walls: Array[Vector3i] = []
		walks.append(_random_walk(start_cell, no_walls, grid_size.x + grid_size.z).path)

	_build_tiles()


## Walks from start until a cell touches one of allowed_walls, and returns
## {"path": Array[Vector3i], "wall": Vector3i}. With no allowed walls it just wanders for
## wander_steps steps and returns a zero wall.
func _random_walk(start: Vector3i, allowed_walls: Array[Vector3i], wander_steps: int = 0) -> Dictionary:
	var path: Array[Vector3i] = [start]
	var cell: Vector3i = start

	var max_steps: int = wander_steps
	if not allowed_walls.is_empty():
		max_steps = grid_size.x * grid_size.z * WALK_STEP_LIMIT_FACTOR

	for _i in max_steps:
		cell += _pick_move(cell)
		path.append(cell)
		var wall: Vector3i = _wall_at(cell, allowed_walls)
		if wall != Vector3i.ZERO:
			return {"path": path, "wall": wall}

	if allowed_walls.is_empty():
		return {"path": path, "wall": Vector3i.ZERO}

	# step limit hit: walk straight to the nearest free wall
	var target: Vector3i = _nearest_wall(cell, allowed_walls)
	var toward := Vector3i(-target.x, 0, -target.z)
	while not _on_wall(cell, target):
		cell += toward
		path.append(cell)
	return {"path": path, "wall": target}


## Picks one move (a grid-cell offset) at random, weighted towards short, flat moves.
func _pick_move(from: Vector3i) -> Vector3i:
	var moves: Array[Vector3i] = []
	var weights: Array[float] = []
	var total: float = 0.0

	for dir in WALK_DIRECTIONS:
		for run in range(1, MAX_RUN + 1):
			for dy in range(-run, run + 1): # |rise| <= run keeps every slope within 45 degrees
				var move := Vector3i(dir.x * run, dy, dir.z * run)
				if not _in_grid(from + move):
					continue
				var weight: float = (1.0 if run == 1 else long_step_weight) * (1.0 if dy == 0 else slope_weight)
				moves.append(move)
				weights.append(weight)
				total += weight

	var pick: float = rng.randf() * total
	for i in moves.size():
		pick -= weights[i]
		if pick <= 0.0:
			return moves[i]
	return moves[-1]


# --- Grid helpers -----------------------------------------------------------------------

func _compute_grid() -> void:
	var cells: Vector3 = size / scale_factor
	grid_size = Vector3i(_odd_floor(cells.x), maxi(floori(cells.y + 0.001), 1), _odd_floor(cells.z))
	floor_level = floori(grid_size.y / 2.0)


func _make_odd(n: int) -> int:
	return n if n % 2 == 1 else n - 1


func _odd_floor(v: float) -> int:
	return _make_odd(floori(v + 0.001))


func _in_grid(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x \
		and cell.y >= 0 and cell.y < grid_size.y \
		and cell.z >= 0 and cell.z < grid_size.z


## The entrance sits in the middle of the wall opposite its (inward) direction.
func _get_start_cell() -> Vector3i:
	var cell := Vector3i(floori(grid_size.x / 2.0), floor_level, floori(grid_size.z / 2.0))
	if entrance:
		if entrance.direction.x > 0:
			cell.x = 0
		elif entrance.direction.x < 0:
			cell.x = grid_size.x - 1
		elif entrance.direction.z > 0:
			cell.z = 0
		elif entrance.direction.z < 0:
			cell.z = grid_size.z - 1
	return cell


## Room-local position of a cell's centre, at floor height.
func cell_to_local(cell: Vector3i) -> Vector3:
	return Vector3(
		(cell.x + 0.5 - grid_size.x / 2.0) * scale_factor,
		(cell.y - floor_level) * scale_factor,
		(cell.z + 0.5 - grid_size.z / 2.0) * scale_factor)


# Walls are identified by their exit direction, same as everywhere else: a wall with direction
# d sits on the -d side of the room.
func _on_wall(cell: Vector3i, wall: Vector3i) -> bool:
	if wall.x > 0:
		return cell.x == 0
	if wall.x < 0:
		return cell.x == grid_size.x - 1
	if wall.z > 0:
		return cell.z == 0
	return cell.z == grid_size.z - 1


func _wall_at(cell: Vector3i, walls: Array[Vector3i]) -> Vector3i:
	for wall in walls:
		if _on_wall(cell, wall):
			return wall
	return Vector3i.ZERO


func _wall_distance(cell: Vector3i, wall: Vector3i) -> int:
	if wall.x > 0:
		return cell.x
	if wall.x < 0:
		return grid_size.x - 1 - cell.x
	if wall.z > 0:
		return cell.z
	return grid_size.z - 1 - cell.z


func _nearest_wall(cell: Vector3i, walls: Array[Vector3i]) -> Vector3i:
	var best: Vector3i = walls[0]
	var best_dist: int = _wall_distance(cell, best)
	for wall in walls:
		var dist: int = _wall_distance(cell, wall)
		if dist < best_dist:
			best = wall
			best_dist = dist
	return best


## Room-local exit position for a walk that ended at cell on wall.
func _exit_position(cell: Vector3i, wall: Vector3i) -> Vector3:
	var pos: Vector3 = cell_to_local(cell)
	if wall.x != 0:
		pos.x = -wall.x * size.x / 2.0
	else:
		pos.z = -wall.z * size.z / 2.0
	return pos


func get_exit_count() -> int:
	var t: float = rng.randf()
	var sampled: float = exit_count_curve.sample(t)
	var mapped: float = lerp(1.0, 3.0, sampled)
	return clampi(roundi(mapped), 1, 3)


# --- Path tiles -------------------------------------------------------------------------

## One tile per cell walked into; a move that runs 2 cells gives 2 tiles at the same slope.
func _build_tiles() -> void:
	path_tiles.clear()
	var seen: Dictionary = {}

	for walk in walks:
		var first: Vector3i = walk[0]
		_add_tile(cell_to_local(first), Vector3i(1, 0, 0), 0.0, seen)

		for i in range(1, walk.size()):
			var from: Vector3i = walk[i - 1]
			var to: Vector3i = walk[i]
			var delta: Vector3i = to - from
			var run: int = maxi(absi(delta.x), absi(delta.z))
			var dir := Vector3i(signi(delta.x), 0, signi(delta.z))
			var slope: float = float(delta.y) / run

			for k in range(1, run + 1):
				var pos: Vector3 = cell_to_local(from) + Vector3(dir.x, slope, dir.z) * scale_factor * k
				_add_tile(pos, dir, slope, seen)


func _add_tile(pos: Vector3, dir: Vector3i, slope: float, seen: Dictionary) -> void:
	var key_dir: Vector3i = dir if slope != 0.0 else Vector3i.ZERO # flat tiles look the same either way
	var key: String = "%s|%s|%s" % [pos.snapped(Vector3.ONE * 0.01), key_dir, snappedf(slope, 0.001)]
	if seen.has(key):
		return
	seen[key] = true
	path_tiles.append({"position": pos, "direction": dir, "slope": slope})
