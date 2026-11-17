extends TextureRect

@export var iso_rotation_degrees: float = 45.0
@export_range(0.1, 1.0) var iso_squash: float = 0.5

@export var wall_color: Color = Color(0.9, 0.9, 0.95, 1.0)
@export var player_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var wall_pixel_size: float = 2.0    # on-screen wall thickness in pixels
@export var player_pixel_size: float = 4.0  # on-screen player dot radius in pixels

var _origin: Vector2
var _cell_size: float = 1.0
var _map_cells: Vector2 = Vector2.ZERO
var _walls: PackedVector2Array = PackedVector2Array() # pairs of points, in cell units
var _player_cell: Vector2 = Vector2(-1, -1)
var _player: PlayerController = null

@export var fullscreen_map_container: Control
@export var fullscreen_map: TextureRect

func _ready() -> void:
	resized.connect(queue_redraw)

	var endless_generator = get_tree().get_first_node_in_group("endless_generator")
	if endless_generator:
		endless_generator.maze_generated.connect(generate_map)
		if not endless_generator.rooms.is_empty():
			generate_map(endless_generator.rooms)

	if fullscreen_map_container:
		fullscreen_map_container.hide()

	update_map_loop()


func _unhandled_key_input(event: InputEvent) -> void:
	# Only the minimap instance has a container assigned; the fullscreen instance ignores input
	if fullscreen_map_container == null:
		return

	if event.is_action_pressed("fullscreen_map") and not event.is_echo():
		hide()
		fullscreen_map_container.show()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("fullscreen_map"):
		show()
		fullscreen_map_container.hide()
		get_viewport().set_input_as_handled()


func update_map_loop() -> void:
	while is_inside_tree():
		if not is_instance_valid(_player):
			_player = GameManager.find_player()
		if _player:
			update_player_marker()
		await get_tree().create_timer(0.1).timeout


func _map_transform() -> Transform2D:
	var rot := deg_to_rad(iso_rotation_degrees)
	var extent: float = (_map_cells.x + _map_cells.y) / sqrt(2.0)
	var k: float = minf(size.x / extent, size.y / (extent * iso_squash))
	return Transform2D(Vector2(1, 0), Vector2(0, iso_squash), size / 2.0) \
		* Transform2D(rot, Vector2.ZERO) \
		* Transform2D(Vector2(k, 0), Vector2(0, k), Vector2.ZERO) \
		* Transform2D(0.0, -_map_cells / 2.0)


func _draw() -> void:
	if _walls.is_empty():
		return
	var xf := _map_transform()
	var k: float = xf.get_scale().x / iso_squash if false else _fit_scale()
	var half: float = (wall_pixel_size / k) * 0.5

	draw_set_transform_matrix(xf)

	# Extend each segment by half the thickness so corners join without gaps
	var pts := PackedVector2Array()
	for i in range(0, _walls.size(), 2):
		var a: Vector2 = _walls[i]
		var b: Vector2 = _walls[i + 1]
		var d: Vector2 = (b - a).normalized() * half
		pts.append(a - d)
		pts.append(b + d)
	draw_multiline(pts, wall_color, wall_pixel_size / k, true)

	if _player:
		draw_circle(_player_cell, player_pixel_size / k, player_color)

	draw_set_transform_matrix(Transform2D.IDENTITY)


func _fit_scale() -> float:
	var extent: float = (_map_cells.x + _map_cells.y) / sqrt(2.0)
	return minf(size.x / extent, size.y / (extent * iso_squash))


func generate_map(rooms: Array) -> void:
	if rooms.is_empty():
		return

	_cell_size = rooms[0].scale_factor

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for room: Room in rooms:
		var corner := _room_corner(room)
		min_p = min_p.min(corner)
		max_p = max_p.max(corner + Vector2(room.grid_size.x, room.grid_size.z) * _cell_size)
	min_p -= Vector2.ONE * _cell_size
	max_p += Vector2.ONE * _cell_size
	_origin = min_p

	var cells := Vector2i(((max_p - min_p) / _cell_size).round())
	var w: int = cells.x
	var h: int = cells.y
	_map_cells = Vector2(w, h)

	# Mark walkable cells
	var walkable := PackedByteArray()
	walkable.resize(w * h)
	for room: Room in rooms:
		var off: Vector2i = ((_room_corner(room) - _origin) / _cell_size).round()
		for chamber in room.chambers:
			var fp: Rect2i = chamber.footprint
			for x in range(fp.position.x, fp.end.x):
				for y in range(fp.position.y, fp.end.y):
					_mark(walkable, w, h, off.x + x, off.y + y)
		for path in room.paths:
			for cell: Vector3i in path:
				_mark(walkable, w, h, off.x + cell.x, off.y + cell.z)

	_walls = PackedVector2Array()

	# Horizontal wall runs: boundary between row y-1 and row y
	for y in range(0, h + 1):
		var run_start: int = -1
		for x in range(0, w + 1):
			var edge: bool = x < w and (_is_walkable(walkable, w, h, x, y) != _is_walkable(walkable, w, h, x, y - 1))
			if edge and run_start == -1:
				run_start = x
			elif not edge and run_start != -1:
				_walls.append(Vector2(run_start, y))
				_walls.append(Vector2(x, y))
				run_start = -1

	# Vertical wall runs: boundary between column x-1 and column x
	for x in range(0, w + 1):
		var run_start: int = -1
		for y in range(0, h + 1):
			var edge: bool = y < h and (_is_walkable(walkable, w, h, x, y) != _is_walkable(walkable, w, h, x - 1, y))
			if edge and run_start == -1:
				run_start = y
			elif not edge and run_start != -1:
				_walls.append(Vector2(x, run_start))
				_walls.append(Vector2(x, y))
				run_start = -1

	queue_redraw()


func update_player_marker() -> void:
	_player_cell = (Vector2(_player.head.global_position.x, _player.head.global_position.z) - _origin) / _cell_size
	queue_redraw()


func _mark(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		grid[y * w + x] = 1


func _is_walkable(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and grid[y * w + x] == 1


# World-space XZ of the room's grid corner (matches cell_to_local's centering)
func _room_corner(room: Room) -> Vector2:
	var half := Vector2(room.grid_size.x, room.grid_size.z) * 0.5 * _cell_size
	return Vector2(room.global_position.x, room.global_position.z) - half
