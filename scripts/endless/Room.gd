class_name Room
extends Node3D


var exit_padding: int = 1
@export var min_room_size: int = 5
var shrink_epsilon: float = 0.05
@export var max_room_size: int = 20
@export var max_room_height: int = 10
@export var chamber_placement_attempts: int = 10


var depth: int
var size: Vector3
var entrance: Doorway
var exits: Array[Doorway] = []
var rng: RandomNumberGenerator
var scale_factor: float = 1.0
var previous_room: Node3D
var max_depth: int = 10
var mesh_loaded: bool = false

@export var exit_hole: Node3D
@export var debug_room_bound: bool = false
var _debug_bound_mesh: MeshInstance3D

# --- Room_Maze Exports & Properties ---
@export var room_mesh: Node3D

@export_group("Chambers")
@export var min_chamber_count: int = 2
@export var max_chamber_count: int = 4
@export var min_chamber_size: int = 3
@export var max_chamber_size: int = 7

@export_group("Exits")
@export var min_exit_count: int = 1
@export var max_exit_count: int = 3


class Chamber extends RefCounted:
	var footprint: Rect2i
	var level: int


var grid_size: Vector3i
var floor_level: int
var chambers: Array[Chamber] = []
var paths: Array[Array] = []
var path_tiles: Array[Dictionary] = []


func _ready() -> void:
	if exit_hole:
		exit_hole.visible = false
	_clear_mesh()


func set_scale_factor(_scale: float) -> void:
	scale_factor = _scale


func set_rng(_rng: RandomNumberGenerator) -> void:
	rng = _rng


func set_max_depth(_max_depth: int) -> void:
	max_depth = _max_depth


func is_max_depth() -> bool:
	return depth >= max_depth


# --- Generation ---

func generate(_entrance: Doorway, _depth: int, _previous_room: Node3D = null) -> void:
	depth = _depth
	previous_room = _previous_room
	_generate(_entrance)


func _generate(_entrance: Doorway) -> void:
	place_at_entrance(_entrance, Vector3(
		_make_odd(rng.randi_range(min_room_size, max_room_size)),
		rng.randi_range(min_room_size, max_room_height),
		_make_odd(rng.randi_range(min_room_size, max_room_size))) * scale_factor)
	_generate_layout()


func place_at_entrance(_entrance: Doorway, _size: Vector3) -> void:
	size = _size
	if _entrance:
		global_position = _entrance.position + ((_entrance.direction as Vector3) * size / 2.0)
		entrance = Doorway.new(_entrance.position - global_position, _entrance.direction)
	else:
		global_position = Vector3.ZERO
		entrance = null
	_update_debug_bound()


func get_floor_y() -> float:
	return entrance.position.y if entrance else 0.0


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


func add_exit(position: Vector3, direction: Vector3i) -> Doorway:
	var exit := Doorway.new(position, direction)
	exits.append(exit)
	return exit


func remove_exit(exit: Doorway) -> void:
	var idx: int = exits.find(exit)
	if idx == -1:
		push_warning("Room_Maze: remove_exit called with an exit not in this room's exits list")
		return
	exits.remove_at(idx)


# --- Mesh Management ---

func load_mesh() -> void:
	if mesh_loaded:
		return
	_build_mesh()
	mesh_loaded = true


func unload_mesh() -> void:
	if not mesh_loaded:
		return
	_clear_mesh()
	mesh_loaded = false


func _build_mesh() -> void:
	if room_mesh and room_mesh.has_method("load_mesh"):
		room_mesh.load_mesh(self)


func _clear_mesh() -> void:
	if room_mesh and room_mesh.has_method("unload_mesh"):
		room_mesh.unload_mesh()


# --- Doorway Helpers ---

func get_doorway_local_to_global(pos: Vector3) -> Vector3:
	return pos + global_position


func get_doorways_local_to_global(doorways: Array[Doorway]) -> Array[Doorway]:
	var global_doorways: Array[Doorway] = []
	for doorway in doorways:
		global_doorways.append(Doorway.new(get_doorway_local_to_global(doorway.position), doorway.direction * -1))
	return global_doorways


func get_doorway_direction(pos: Vector3) -> Vector3i:
	if pos.x == size.x / 2.0:
		return Vector3i(1, 0, 0)
	elif pos.x == -size.x / 2.0:
		return Vector3i(-1, 0, 0)
	elif pos.z == size.z / 2.0:
		return Vector3i(0, 0, 1)
	elif pos.z == -size.z / 2.0:
		return Vector3i(0, 0, -1)
	return Vector3i.ZERO


# --- Bounds / Overlap ---

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


func test_overlap(rooms: Array) -> bool:
	var aabb: AABB = AABB(global_position - size / 2.0, size)
	for room in rooms:
		var test_aabb: AABB = AABB(room.global_position - room.size / 2.0, room.size)
		if aabb.intersects(test_aabb):
			return true
	return false


func get_overlap_volume(other) -> float:
	var a: AABB = AABB(global_position - size / 2.0, size)
	var b: AABB = AABB(other.global_position - other.size / 2.0, other.size)
	if not a.intersects(b):
		return 0.0
	var overlap: AABB = a.intersection(b)
	return overlap.size.x * overlap.size.y * overlap.size.z


func get_overlap_percent(other) -> float:
	var vol: float = size.x * size.y * size.z
	if vol <= 0.0:
		return 0.0
	return get_overlap_volume(other) / vol


func shrink_to_fit(other, entrance_direction: Vector3i) -> bool:
	var old_exits: Array[Doorway] = exits.duplicate()
	exits.clear()

	var a: AABB = AABB(global_position - size / 2.0, size)
	var b: AABB = AABB(other.global_position - other.size / 2.0, other.size)
	if not a.intersects(b):
		_generate_layout()
		return true

	var dir: Vector3 = Vector3(entrance_direction)
	var axis: int = 0 if dir.x != 0 else 2
	var sign_val: float = dir.x if axis == 0 else dir.z

	var a_min: float = a.position[axis]
	var a_max: float = a.position[axis] + a.size[axis]
	var b_min: float = b.position[axis]
	var b_max: float = b.position[axis] + b.size[axis]

	var new_extent: float
	if sign_val > 0:
		if a_max > b_min and a_min <= b_min:
			new_extent = b_min - a_min - shrink_epsilon
		else:
			exits = old_exits
			return false
	else:
		if a_min < b_max and a_max >= b_max:
			new_extent = a_max - b_max - shrink_epsilon
		else:
			exits = old_exits
			return false

	if new_extent < min_room_size * scale_factor:
		exits = old_exits
		return false

	var new_size: Vector3 = size
	new_size[axis] = new_extent

	for exit_item in old_exits:
		if axis == 0 and abs(exit_item.position.x) > new_extent / 2.0 - exit_padding * scale_factor:
			exits = old_exits
			return false
		if axis == 2 and abs(exit_item.position.z) > new_extent / 2.0 - exit_padding * scale_factor:
			exits = old_exits
			return false

	var old_center: Vector3 = global_position
	var shrink_amount: float = size[axis] - new_extent
	size = new_size
	global_position = old_center - (dir.normalized() * shrink_amount / 2.0)
	if entrance:
		entrance = Doorway.new(entrance.position + (old_center - global_position), entrance.direction)
	_update_debug_bound()

	var a2: AABB = AABB(global_position - size / 2.0, size)
	if a2.intersects(b):
		exits = old_exits
		return false

	_generate_layout()
	return true


func generate_hole() -> void:
	if exit_hole and not chambers.is_empty():
		var random_chamber: Chamber = chambers[rng.randi_range(0, chambers.size() - 1)]
		var random_cell: Vector3i = _random_cell_in(random_chamber)
		exit_hole.position = cell_to_local(random_cell)
		exit_hole.visible = true
		
		var area: Area3D = exit_hole.find_child("Area3D") as Area3D
		if area and not area.body_entered.is_connected(hole_entered):
			area.body_entered.connect(hole_entered)
			
		if room_mesh:
			room_mesh.carve_exit_hole(Vector2i(random_cell.x, random_cell.z))


func hole_entered(body: Node3D) -> void:
	if body.get_parent() is PlayerController:
		await get_tree().create_timer(0.5).timeout
		GameManager.load_endless()


func spawn_scene(scene: PackedScene):
	var random_chamber: Chamber = chambers[rng.randi_range(0, chambers.size() - 1)]
	var random_cell: Vector3i = _random_cell_in(random_chamber)
	var new_scene = scene.instantiate() as Node3D
	add_child(new_scene)

	# Place it at the cell first so the transforms are final before measuring
	var floor_pos: Vector3 = to_global(cell_to_local(random_cell))
	new_scene.global_position = floor_pos

	var bounds: AABB = _get_global_aabb(new_scene)
	if bounds.has_surface():
		# Move up/down so the bottom of the box sits exactly at floor height
		new_scene.global_position.y += floor_pos.y - bounds.position.y


func _get_global_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is VisualInstance3D:
			var box: AABB = node.global_transform * node.get_aabb()
			if found:
				result = result.merge(box)
			else:
				result = box
				found = true
	return result


func _to_string() -> String:
	return "[" + name + "] (" + \
	"global_position: " + str(global_position) + ", " + \
	"size: " + str(size) + ", " + \
	"entrance_position: " + (str(get_doorway_local_to_global(entrance.position)) if entrance else "none") + ", " + \
	"entrance_direction: " + (str(entrance.direction) if entrance else "none") + ", " + \
	"exits: " + str(len(exits)) + ", " + \
	")"


# --- Layout Generation ------------------------------------------------------------------

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

	for _i in count:
		var chamber: Chamber = _place_chamber()
		chambers.append(chamber)


func _place_chamber() -> Chamber:
	var chamber := Chamber.new()
	var width: int = _random_chamber_length(grid_size.x)
	var depth_cell: int = _random_chamber_length(grid_size.z)
	chamber.footprint = Rect2i(
		rng.randi_range(0, grid_size.x - width),
		rng.randi_range(0, grid_size.z - depth_cell),
		width, depth_cell)
	chamber.level = floor_level
	return chamber


func _random_chamber_length(room_cells: int) -> int:
	var lo: int = mini(min_chamber_size, room_cells)
	var hi: int = clampi(max_chamber_size, lo, room_cells)
	return rng.randi_range(lo, hi)


func _connect_chambers() -> void:
	var anchor := Vector3i.ZERO
	var has_anchor: bool = false
	if entrance:
		anchor = _get_start_cell()
		has_anchor = true

	for chamber in chambers:
		if has_anchor:
			var target: Vector3i = _pick_target(anchor, chamber)
			paths.append(_make_flat_path(anchor, target))

		anchor = _random_cell_in(chamber)
		has_anchor = true


func _pick_target(from: Vector3i, chamber: Chamber) -> Vector3i:
	var fp: Rect2i = chamber.footprint
	return Vector3i(
		clampi(from.x, fp.position.x, fp.end.x - 1),
		chamber.level,
		clampi(from.z, fp.position.y, fp.end.y - 1))


func _generate_exits() -> void:
	if is_max_depth():
		return

	var walls: Array[Vector3i] = Doorway.cardinals.duplicate()
	if entrance:
		walls.erase(entrance.direction)

	var lo: int = mini(min_exit_count, max_exit_count)
	var hi: int = maxi(min_exit_count, max_exit_count)
	var count: int = rng.randi_range(lo, hi)

	var used: Dictionary = {}

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

		paths.append(_make_flat_path(cell, target))
		add_exit(_exit_position(cell, wall), wall)


func _make_flat_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var dx: int = to.x - from.x
	var dz: int = to.z - from.z
	var x_step := Vector3i(signi(dx), 0, 0)
	var z_step := Vector3i(0, 0, signi(dz))
	var x_first: bool = rng.randf() < 0.5

	var steps: Array[Vector3i] = []
	for leg in 2:
		var is_x: bool = (leg == 0) == x_first
		var length: int = absi(dx) if is_x else absi(dz)
		for _i in length:
			steps.append(x_step if is_x else z_step)

	var path: Array[Vector3i] = [Vector3i(from.x, floor_level, from.z)]
	var cell: Vector3i = Vector3i(from.x, floor_level, from.z)
	for i in steps.size():
		cell += steps[i]
		cell.y = floor_level
		path.append(cell)
	return path


# --- Grid Helpers ---

func _compute_grid() -> void:
	var cells: Vector3 = size / scale_factor
	grid_size = Vector3i(_odd_floor(cells.x), maxi(floori(cells.y + 0.001), 1), _odd_floor(cells.z))
	floor_level = floori(grid_size.y / 2.0)


func _make_odd(n: int) -> int:
	return n if n % 2 == 1 else n - 1


func _odd_floor(v: float) -> int:
	return _make_odd(floori(v + 0.001))


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


func _closest_cell_in(chamber: Chamber, cell: Vector3i) -> Vector3i:
	var fp: Rect2i = chamber.footprint
	return Vector3i(
		clampi(cell.x, fp.position.x, fp.end.x - 1),
		chamber.level,
		clampi(cell.z, fp.position.y, fp.end.y - 1))


func _nearest_chamber(cell: Vector3i) -> Chamber:
	if chambers.is_empty():
		return null
	var best: Chamber = chambers[0]
	var best_dist: int = _horizontal_distance(cell, _closest_cell_in(best, cell))
	for chamber in chambers:
		var dist: int = _horizontal_distance(cell, _closest_cell_in(best, cell))
		if dist < best_dist:
			best = chamber
			best_dist = dist
	return best


func _random_wall_cell(wall: Vector3i) -> Vector3i:
	var cell := Vector3i(
		rng.randi_range(0, grid_size.x - 1),
		floor_level,
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


func cell_to_local(cell: Vector3i) -> Vector3:
	# Using exact grid-index math mapped to local space to avoid floating point drift/rounding gaps
	return Vector3(
		(cell.x + 0.5 - grid_size.x / 2.0) * scale_factor,
		(cell.y - floor_level) * scale_factor,
		(cell.z + 0.5 - grid_size.z / 2.0) * scale_factor)


func local_to_cell(pos: Vector3) -> Vector3i:
	return Vector3i(
		clampi(floori(pos.x / scale_factor + grid_size.x / 2.0), 0, grid_size.x - 1),
		clampi(roundi(pos.y / scale_factor) + floor_level, 0, grid_size.y - 1),
		clampi(floori(pos.z / scale_factor + grid_size.z / 2.0), 0, grid_size.z - 1))


func chamber_center_local(chamber: Chamber) -> Vector3:
	var fp: Rect2i = chamber.footprint
	var first: Vector3 = cell_to_local(Vector3i(fp.position.x, chamber.level, fp.position.y))
	return first + Vector3(fp.size.x - 1, 0, fp.size.y - 1) * scale_factor / 2.0


func _exit_position(cell: Vector3i, wall: Vector3i) -> Vector3:
	var pos: Vector3 = cell_to_local(cell)
	if wall.x != 0:
		pos.x = -wall.x * size.x / 2.0
	else:
		pos.z = -wall.z * size.z / 2.0
	return pos


# --- Path Tiles ---

func _build_tiles() -> void:
	path_tiles.clear()
	var seen: Dictionary = {}

	for path in paths:
		for cell in path:
			_add_tile(cell_to_local(cell), Vector3i.ZERO, 0.0, seen)


func _add_tile(pos: Vector3, dir: Vector3i, slope: float, seen: Dictionary) -> void:
	# Snapping position slightly to a clean tolerance bucket to prevent duplicate rounding slippage
	var snapped_pos = pos.snapped(Vector3.ONE * 0.001)
	var key: String = "%s|%s|%s" % [snapped_pos, dir, snappedf(slope, 0.001)]
	if seen.has(key):
		return
	seen[key] = true
	path_tiles.append({"position": snapped_pos, "direction": dir, "slope": slope})
