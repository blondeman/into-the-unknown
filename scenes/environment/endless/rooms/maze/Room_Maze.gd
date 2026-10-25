class_name Room_Maze
extends Room
## A room made of chambers (big open spaces) joined by paths.
##
## Generation, in order:
##   1. Chambers are placed anywhere inside the room. They may overlap, but chambers that overlap
##      always share a level, so floors are never stacked on top of each other.
##   2. A path runs from the entrance to the first chamber, then from each chamber to the next,
##      until every chamber is connected. (The first room has no entrance, so it starts at the
##      first chamber.)
##   3. Exits are placed at random points on the room's walls and each is joined to its nearest
##      chamber.
## Every path is a shortest Manhattan path with a single turn. Where it has to change height it
## does so at 45 degrees (1 up for every 1 across). A ramp never turns: the cell at a turn and the
## cell after it are always flat. Nothing here builds geometry; see RoomMesh_Maze.

const MAX_ROOM_SIZE = 20
const MAX_ROOM_HEIGHT = 10

## Tries to find a spot for a chamber that doesn't overlap chambers at different levels.
const CHAMBER_PLACEMENT_ATTEMPTS := 10

@export var room_mesh: RoomMesh

@export_group("Chambers")
@export var min_chamber_count: int = 2
@export var max_chamber_count: int = 4

## Chamber footprint limits, in cells.
@export var min_chamber_size: int = 3
@export var max_chamber_size: int = 7

@export_group("Exits")
@export var min_exit_count: int = 1
@export var max_exit_count: int = 3

@export_group("Height")
## Off: everything in the room (chambers, paths, doorways) sits on the entrance's level, so there
## are no slopes and every room in the maze ends up at the same height. On: chambers and exits
## get random levels and paths ramp between them.
@export var allow_slopes: bool = false


class Chamber extends RefCounted:
	## Footprint in grid cells. Rect2i.position is (x, z) and Rect2i.size is (width, depth).
	var footprint: Rect2i
	## Grid level (y index) of the chamber's floor.
	var level: int


## Room size in cells. x and z are always odd so the entrance (which sits in the middle of its
## wall) lines up with a cell centre.
var grid_size: Vector3i

## Grid level (y index) that sits at the room's local y = 0, i.e. the entrance height.
var floor_level: int

var chambers: Array[Chamber] = []

## Each path is an Array[Vector3i] of grid cells, in order. Consecutive cells are one cell apart
## horizontally and at most one level apart vertically.
var paths: Array[Array] = []

## Flattened, de-duplicated path cells for drawing. Each entry: {"position": Vector3 (room-local,
## cell centre), "direction": Vector3i (horizontal travel), "slope": float (rise per cell)}.
var path_tiles: Array[Dictionary] = []


func _generate(_entrance: Doorway) -> void:
	place_at_entrance(_entrance, Vector3(
		_make_odd(rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)),
		rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_HEIGHT),
		_make_odd(rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE))) * scale_factor)
	_generate_layout()


func _build_mesh() -> void:
	room_mesh.load_mesh(self)


func _clear_mesh() -> void:
	room_mesh.unload_mesh()


## The layout depends on the room's size, so shrinking means redoing it (and with it the exits).
func shrink_to_fit(other: Room, entrance_direction: Vector3i) -> bool:
	var old_exits: Array[Doorway] = exits.duplicate()
	exits.clear() # they're regenerated for the new size, so they must not block the shrink
	if not super.shrink_to_fit(other, entrance_direction):
		exits = old_exits
		return false
	_generate_layout()
	return true


# --- Layout -----------------------------------------------------------------------------

func _generate_layout() -> void:
	exits.clear()
	chambers.clear()
	paths.clear()
	_compute_grid()

	_generate_chambers()
	_connect_chambers()
	_generate_exits()
	_build_tiles()


func _generate_chambers() -> void:
	var lo: int = mini(min_chamber_count, max_chamber_count)
	var hi: int = maxi(min_chamber_count, max_chamber_count)
	var count: int = rng.randi_range(maxi(lo, 1), maxi(hi, 1))

	var levels: Dictionary = {} # Vector2i (x, z) -> level of the chamber floor already there

	for _i in count:
		var chamber: Chamber = _place_chamber(levels)
		chambers.append(chamber)

		var fp: Rect2i = chamber.footprint
		for x in range(fp.position.x, fp.end.x):
			for z in range(fp.position.y, fp.end.y):
				levels[Vector2i(x, z)] = chamber.level


## Places a chamber so it never sits at a different height from a chamber it overlaps: if it
## overlaps one, it takes that chamber's level and the two become one open space. A spot that would
## overlap chambers at different heights is retried. If no attempt works the last one is used
## anyway, and RoomMesh_Maze cuts the overlap.
func _place_chamber(levels: Dictionary) -> Chamber:
	var chamber := Chamber.new()
	for _attempt in CHAMBER_PLACEMENT_ATTEMPTS:
		var width: int = _random_chamber_length(grid_size.x)
		var depth: int = _random_chamber_length(grid_size.z)
		chamber.footprint = Rect2i(
			rng.randi_range(0, grid_size.x - width),
			rng.randi_range(0, grid_size.z - depth),
			width, depth)

		var under: Array[int] = _levels_under(chamber.footprint, levels)
		chamber.level = under[0] if not under.is_empty() else _random_level()
		if under.size() <= 1:
			break
	return chamber


## The distinct chamber floor levels already present under a footprint.
func _levels_under(footprint: Rect2i, levels: Dictionary) -> Array[int]:
	var found: Array[int] = []
	for x in range(footprint.position.x, footprint.end.x):
		for z in range(footprint.position.y, footprint.end.y):
			var level: int = levels.get(Vector2i(x, z), -1)
			if level != -1 and not found.has(level):
				found.append(level)
	return found


func _random_chamber_length(room_cells: int) -> int:
	var lo: int = mini(min_chamber_size, room_cells)
	var hi: int = clampi(max_chamber_size, lo, room_cells)
	return rng.randi_range(lo, hi)


## Entrance -> chamber 0 -> chamber 1 -> ... so every chamber ends up connected.
func _connect_chambers() -> void:
	var anchor := Vector3i.ZERO
	var has_anchor: bool = false
	if entrance:
		anchor = _get_start_cell()
		has_anchor = true

	for chamber in chambers:
		if has_anchor:
			var target: Vector3i = _pick_target(anchor, chamber)

			# 45 degree slopes need as much run as rise. If even the farthest cell is too close in
			# plan to climb to the chamber's level, the chamber is moved to the level the path can reach.
			var reach: int = _max_rise(anchor, target)
			if absi(target.y - anchor.y) > reach:
				chamber.level = anchor.y + signi(target.y - anchor.y) * reach
				target.y = chamber.level

			paths.append(_make_path(anchor, target))

		# leave this chamber from a random point inside it
		anchor = _random_cell_in(chamber)
		has_anchor = true


## A random cell of the chamber that a path from `from` can climb to the chamber's level at,
## so the chamber's level doesn't have to change. Any cell if none can.
func _pick_target(from: Vector3i, chamber: Chamber) -> Vector3i:
	var fp: Rect2i = chamber.footprint
	var rise: int = absi(chamber.level - from.y)
	var options: Array[Vector3i] = []
	for x in range(fp.position.x, fp.end.x):
		for z in range(fp.position.y, fp.end.y):
			var cell := Vector3i(x, chamber.level, z)
			if _max_rise(from, cell) >= rise:
				options.append(cell)
	if options.is_empty():
		return _random_cell_in(chamber)
	return options[rng.randi_range(0, options.size() - 1)]


func _generate_exits() -> void:
	if is_max_depth():
		return # final depth: no exits

	var walls: Array[Vector3i] = Doorway.cardinals.duplicate()
	if entrance:
		walls.erase(entrance.direction) # the entrance owns its wall

	var lo: int = mini(min_exit_count, max_exit_count)
	var hi: int = maxi(min_exit_count, max_exit_count)
	var count: int = rng.randi_range(lo, hi)

	var used: Dictionary = {} # (x, z) cells that already have an exit

	for _i in count:
		var wall := Vector3i.ZERO
		var cell := Vector3i.ZERO
		var found: bool = false
		for _attempt in 10:
			wall = walls[rng.randi_range(0, walls.size() - 1)]
			cell = _random_wall_cell(wall)
			if not used.has(Vector2i(cell.x, cell.z)):
				found = true
				break
		if not found:
			continue
		used[Vector2i(cell.x, cell.z)] = true

		var chamber: Chamber = _nearest_chamber(cell)
		var target: Vector3i = _closest_cell_in(chamber, cell)

		# keep the climb within 45 degrees by bringing the exit's height towards the chamber's
		var reach: int = _max_rise(cell, target)
		cell.y = clampi(cell.y, target.y - reach, target.y + reach)

		paths.append(_make_path(cell, target))
		add_exit(_exit_position(cell, wall), wall)


## Shortest Manhattan path from `from` to `to` with one turn (x then z, or z then x, chosen at
## random). Height changes happen at 45 degrees: one level for each cell travelled while ramping.
## The ramp is one unbroken run inside a single leg. A ramp can't turn, so the cell at the turn and
## the cell after it are flat. `to.y - from.y` must not exceed _max_rise() (callers make sure).
func _make_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var dx: int = to.x - from.x
	var dz: int = to.z - from.z
	var x_step := Vector3i(signi(dx), 0, 0)
	var z_step := Vector3i(0, 0, signi(dz))
	var x_first: bool = rng.randf() < 0.5

	var steps: Array[Vector3i] = []
	var legs: Array[Vector2i] = [] # [start, end) range of step indices that make up each leg
	for leg in 2:
		var is_x: bool = (leg == 0) == x_first
		var length: int = absi(dx) if is_x else absi(dz)
		legs.append(Vector2i(steps.size(), steps.size() + length))
		for _i in length:
			steps.append(x_step if is_x else z_step)

	# step ranges [start, end) a ramp may use. Step i moves into cell i + 1, so the last step of the
	# first leg is the move into the turn cell and the first step of the second leg is the move out
	# of it; both stay flat.
	var ramp_ranges: Array[Vector2i] = []
	if absi(dx) > 0 and absi(dz) > 0:
		ramp_ranges.append(Vector2i(legs[0].x, legs[0].y - 1))
		ramp_ranges.append(Vector2i(legs[1].x + 1, legs[1].y))
	else:
		ramp_ranges.append(Vector2i(0, steps.size()))

	var rise: int = mini(absi(to.y - from.y), _max_rise(from, to))
	var rise_dir: int = signi(to.y - from.y)
	var ramp_start: int = 0
	if rise > 0:
		var starts: Array[int] = []
		for ramp_range in ramp_ranges:
			for s in range(ramp_range.x, ramp_range.y - rise + 1):
				starts.append(s)
		ramp_start = starts[rng.randi_range(0, starts.size() - 1)]

	var path: Array[Vector3i] = [from]
	var cell: Vector3i = from
	for i in steps.size():
		cell += steps[i]
		if i >= ramp_start and i < ramp_start + rise:
			cell.y += rise_dir
		path.append(cell)
	return path


## The most a path from `from` to `to` can climb or drop. A straight path can ramp along its whole
## length. With a turn, the turn cell and the one after it must be flat, so a ramp has to fit
## in what's left of one leg.
func _max_rise(from: Vector3i, to: Vector3i) -> int:
	var run_x: int = absi(to.x - from.x)
	var run_z: int = absi(to.z - from.z)
	if run_x == 0 or run_z == 0:
		return run_x + run_z
	return maxi(run_x, run_z) - 1


# --- Grid helpers -----------------------------------------------------------------------

func _compute_grid() -> void:
	var cells: Vector3 = size / scale_factor
	grid_size = Vector3i(_odd_floor(cells.x), maxi(floori(cells.y + 0.001), 1), _odd_floor(cells.z))
	floor_level = floori(grid_size.y / 2.0)


## A level for a new chamber or exit: the entrance's level unless slopes are allowed.
func _random_level() -> int:
	if not allow_slopes:
		return floor_level
	return rng.randi_range(0, grid_size.y - 1)


func _make_odd(n: int) -> int:
	return n if n % 2 == 1 else n - 1


func _odd_floor(v: float) -> int:
	return _make_odd(floori(v + 0.001))


## The entrance sits in the middle of the wall opposite its (inward) direction.
func _get_start_cell() -> Vector3i:
	var cell := Vector3i(floori(grid_size.x / 2.0), floor_level, floori(grid_size.z / 2.0))
	if entrance.direction.x > 0:
		cell.x = 0
	elif entrance.direction.x < 0:
		cell.x = grid_size.x - 1
	elif entrance.direction.z > 0:
		cell.z = 0
	elif entrance.direction.z < 0:
		cell.z = grid_size.z - 1
	return cell


func _horizontal_distance(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.z - b.z)


func _random_cell_in(chamber: Chamber) -> Vector3i:
	var fp: Rect2i = chamber.footprint
	return Vector3i(
		rng.randi_range(fp.position.x, fp.end.x - 1),
		chamber.level,
		rng.randi_range(fp.position.y, fp.end.y - 1))


## The cell of the chamber closest to `cell` in plan, at the chamber's level.
func _closest_cell_in(chamber: Chamber, cell: Vector3i) -> Vector3i:
	var fp: Rect2i = chamber.footprint
	return Vector3i(
		clampi(cell.x, fp.position.x, fp.end.x - 1),
		chamber.level,
		clampi(cell.z, fp.position.y, fp.end.y - 1))


func _nearest_chamber(cell: Vector3i) -> Chamber:
	var best: Chamber = chambers[0]
	var best_dist: int = _horizontal_distance(cell, _closest_cell_in(best, cell))
	for chamber in chambers:
		var dist: int = _horizontal_distance(cell, _closest_cell_in(chamber, cell))
		if dist < best_dist:
			best = chamber
			best_dist = dist
	return best


## A random cell on a wall, at a random height. Walls are identified by their exit direction,
## same as everywhere else: a wall with direction d sits on the -d side of the room.
func _random_wall_cell(wall: Vector3i) -> Vector3i:
	var cell := Vector3i(
		rng.randi_range(0, grid_size.x - 1),
		_random_level(),
		rng.randi_range(0, grid_size.z - 1))
	if wall.x > 0:
		cell.x = 0
	elif wall.x < 0:
		cell.x = grid_size.x - 1
	elif wall.z > 0:
		cell.z = 0
	else:
		cell.z = grid_size.z - 1
	return cell


## Room-local position of a cell's centre, at floor height.
func cell_to_local(cell: Vector3i) -> Vector3:
	return Vector3(
		(cell.x + 0.5 - grid_size.x / 2.0) * scale_factor,
		(cell.y - floor_level) * scale_factor,
		(cell.z + 0.5 - grid_size.z / 2.0) * scale_factor)


## The grid cell containing a room-local position (clamped to the grid). Works for doorway
## positions too, which sit exactly on the room's wall.
func local_to_cell(pos: Vector3) -> Vector3i:
	return Vector3i(
		clampi(floori(pos.x / scale_factor + grid_size.x / 2.0), 0, grid_size.x - 1),
		clampi(roundi(pos.y / scale_factor) + floor_level, 0, grid_size.y - 1),
		clampi(floori(pos.z / scale_factor + grid_size.z / 2.0), 0, grid_size.z - 1))


## Room-local centre of a chamber's floor.
func chamber_center_local(chamber: Chamber) -> Vector3:
	var fp: Rect2i = chamber.footprint
	var first: Vector3 = cell_to_local(Vector3i(fp.position.x, chamber.level, fp.position.y))
	return first + Vector3(fp.size.x - 1, 0, fp.size.y - 1) * scale_factor / 2.0


## Room-local exit position for a path that starts at cell on wall.
func _exit_position(cell: Vector3i, wall: Vector3i) -> Vector3:
	var pos: Vector3 = cell_to_local(cell)
	if wall.x != 0:
		pos.x = -wall.x * size.x / 2.0
	else:
		pos.z = -wall.z * size.z / 2.0
	return pos


# --- Path tiles -------------------------------------------------------------------------

## One tile per cell walked into. Every step runs exactly one cell, so slope is just the rise.
func _build_tiles() -> void:
	path_tiles.clear()
	var seen: Dictionary = {}

	for path in paths:
		var first: Vector3i = path[0]
		_add_tile(cell_to_local(first), Vector3i(1, 0, 0), 0.0, seen)

		for i in range(1, path.size()):
			var from: Vector3i = path[i - 1]
			var to: Vector3i = path[i]
			var delta: Vector3i = to - from
			var dir := Vector3i(signi(delta.x), 0, signi(delta.z))
			_add_tile(cell_to_local(to), dir, float(delta.y), seen)


func _add_tile(pos: Vector3, dir: Vector3i, slope: float, seen: Dictionary) -> void:
	var key_dir: Vector3i = dir if slope != 0.0 else Vector3i.ZERO # flat tiles look the same either way
	var key: String = "%s|%s|%s" % [pos.snapped(Vector3.ONE * 0.01), key_dir, snappedf(slope, 0.001)]
	if seen.has(key):
		return
	seen[key] = true
	path_tiles.append({"position": pos, "direction": dir, "slope": slope})


func _generate_hole():
	generate_hole(global_position)
