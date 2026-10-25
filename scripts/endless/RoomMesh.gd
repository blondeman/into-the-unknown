class_name RoomMesh
extends Node3D

@export var floor_material: Material
var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var wall: PackedScene
@export var wall_rotation_offset: float = 0.0 # Rotation offset in degrees around the Y-axis
@export var manual_exit_holes: Array[Vector2i] = [] # Optional manual drop-hole coordinates

@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1

var _current_maze: Room = null
var _active_hole_cell: Vector2i = Vector2i(-999, -999)


class Tile extends RefCounted:
	var cell: Vector2i
	var corners: Array[int] = [0, 0, 0, 0]

	func is_flat() -> bool:
		return corners.min() == corners.max()

	func edge(side: Vector2i) -> Vector2i:
		if side.x > 0:
			return Vector2i(corners[1], corners[3])
		if side.x < 0:
			return Vector2i(corners[0], corners[2])
		if side.y > 0:
			return Vector2i(corners[2], corners[3])
		return Vector2i(corners[0], corners[1])


var _geometry: Array[Node] = []


func load_mesh(room: Room) -> void:
	_clear_geometry()

	_current_maze = room as Room
	if not _current_maze:
		push_error("RoomMesh can only build Room rooms")
		return

	_build_geometry(_current_maze)


func unload_mesh() -> void:
	_current_maze = null
	_active_hole_cell = Vector2i(-999, -999)
	_clear_geometry()


# --- Exit Hole Interface ---

func carve_exit_hole(cell: Vector2i) -> void:
	_active_hole_cell = cell
	print("RoomMesh: Carving exit hole at cell: ", cell)
	
	# If geometry is already built, rebuild it immediately to strip the floor mesh and collision
	if _current_maze:
		_build_geometry(_current_maze)
		GameManager.on_rebake.emit()


# --- Tiles ---

func _collect_tiles(maze: Room) -> Dictionary:
	var columns: Dictionary = {}

	var chamber_levels: Dictionary = {}
	for chamber in maze.chambers:
		var fp: Rect2i = chamber.footprint
		for x in range(fp.position.x, fp.end.x):
			for z in range(fp.position.y, fp.end.y):
				chamber_levels[Vector2i(x, z)] = chamber.level
	for cell in chamber_levels:
		_add_tile(columns, _make_flat_tile(cell, chamber_levels[cell]))

	for path in maze.paths:
		var first: Vector3i = path[0]
		_add_tile(columns, _make_flat_tile(Vector2i(first.x, first.z), first.y))

		for i in range(1, path.size()):
			var from: Vector3i = path[i - 1]
			var to: Vector3i = path[i]
			var cell := Vector2i(to.x, to.z)
			if to.y == from.y:
				_add_tile(columns, _make_flat_tile(cell, to.y))
			else:
				var dir := Vector2i(signi(to.x - from.x), signi(to.z - from.z))
				_add_tile(columns, _make_ramp_tile(cell, from.y, to.y, dir))

	for cell in columns:
		var tiles: Array = columns[cell]
		var ramp_levels: Array[int] = []
		for tile in tiles:
			if not tile.is_flat():
				ramp_levels.append(tile.corners.min())
				ramp_levels.append(tile.corners.max())
		if ramp_levels.is_empty():
			continue
		var kept: Array = []
		for tile in tiles:
			if tile.is_flat() and tile.corners[0] in ramp_levels:
				continue
			kept.append(tile)
		columns[cell] = kept

	return columns


func _add_tile(columns: Dictionary, tile: Tile) -> void:
	var column: Array = columns.get(tile.cell, [])
	for existing in column:
		if existing.corners == tile.corners:
			return
	column.append(tile)
	columns[tile.cell] = column


func _make_flat_tile(cell: Vector2i, level: int) -> Tile:
	var tile := Tile.new()
	tile.cell = cell
	tile.corners.fill(level)
	return tile


func _make_ramp_tile(cell: Vector2i, entry: int, exit: int, dir: Vector2i) -> Tile:
	var tile := Tile.new()
	tile.cell = cell
	var c: Array[int] = tile.corners
	if dir.x > 0:
		c[0] = entry; c[2] = entry; c[1] = exit; c[3] = exit
	elif dir.x < 0:
		c[1] = entry; c[3] = entry; c[0] = exit; c[2] = exit
	elif dir.y > 0:
		c[0] = entry; c[1] = entry; c[2] = exit; c[3] = exit
	else:
		c[2] = entry; c[3] = entry; c[0] = exit; c[1] = exit
	return tile


func _get_open_sides(maze: Room) -> Dictionary:
	var doorways: Array[Doorway] = []
	doorways.append_array(maze.exits)
	if maze.entrance:
		doorways.append(maze.entrance)

	var open: Dictionary = {}
	for doorway in doorways:
		var cell: Vector3i = maze.local_to_cell(doorway.position)
		open[Vector4i(cell.x, cell.z, -doorway.direction.x, -doorway.direction.z)] = cell.y
	return open


func _get_exit_hole_cells() -> Dictionary:
	var holes: Dictionary = {}
	
	# Add any manually configured exit holes from the inspector
	for cell in manual_exit_holes:
		holes[cell] = true

	# Add the dynamically generated hole cell if set by generate_hole()
	if _active_hole_cell != Vector2i(-999, -999):
		holes[_active_hole_cell] = true

	return holes


func _is_connected(tile: Tile, side: Vector2i, columns: Dictionary, open_sides: Dictionary) -> bool:
	var edge: Vector2i = tile.edge(side)

	var door_key := Vector4i(tile.cell.x, tile.cell.y, side.x, side.y)
	if open_sides.has(door_key):
		var level: int = open_sides[door_key]
		if edge == Vector2i(level, level):
			return true

	for other in columns.get(tile.cell + side, []):
		if other.edge(-side) == edge:
			return true
	return false


# --- Geometry & Tiling ---

func _build_geometry(maze: Room) -> void:
	# Clear any previously generated geometry before rebuilding
	_clear_geometry()

	# Compute wall dimensions dynamically by temporarily instantiating the PackedScene
	var wall_aabb = AABB(Vector3.ZERO, Vector3(1.0, 2.5, 0.1))
	if wall:
		var temp_node = wall.instantiate() as Node3D
		if temp_node:
			wall_aabb = _get_node_aabb(temp_node)
			temp_node.queue_free()

	var wall_size = wall_aabb.size
	if wall_size.x <= 0.0: wall_size.x = 1.0
	if wall_size.y <= 0.0: wall_size.y = 2.5
	if wall_size.z <= 0.0: wall_size.z = 0.1

	var columns: Dictionary = _collect_tiles(maze)
	var open_sides: Dictionary = _get_open_sides(maze)
	var exit_holes: Dictionary = _get_exit_hole_cells()

	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floor_count: int = 0

	for column in columns.values():
		for tile in column:
			var is_hole: bool = exit_holes.has(tile.cell)

			# Only add floor mesh if this tile is NOT a hole
			if not is_hole:
				_add_floor(floor_st, maze, tile, wall_size.z)
				floor_count += 1

			# Always build walls normally around the cell (framing the hole)
			for side in sides:
				if _is_connected(tile, side, columns, open_sides):
					continue
				_instantiate_wall(maze, tile, side, wall_size)

	# Commit Floor Mesh & Collider
	var mesh := ArrayMesh.new()
	if floor_count > 0:
		floor_st.commit(mesh)
		if floor_material:
			mesh.surface_set_material(mesh.get_surface_count() - 1, _prepare_material(floor_material))

	if mesh.get_surface_count() > 0:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		add_child(instance)
		_geometry.append(instance)

		var body := StaticBody3D.new()
		body.collision_layer = collision_layer
		body.collision_mask = collision_mask
		add_child(body)
		_geometry.append(body)

		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)


func _corner_position(maze: Room, cell: Vector2i, ix: int, iz: int, level: int) -> Vector3:
	var s: float = maze.scale_factor
	return Vector3(
		(cell.x + ix - maze.grid_size.x / 2.0) * s,
		(level - maze.floor_level) * s,
		(cell.y + iz - maze.grid_size.z / 2.0) * s)


func _add_floor(st: SurfaceTool, maze: Room, tile: Tile, thickness: float) -> void:
	var p00: Vector3 = _corner_position(maze, tile.cell, 0, 0, tile.corners[0])
	var p10: Vector3 = _corner_position(maze, tile.cell, 1, 0, tile.corners[1])
	var p01: Vector3 = _corner_position(maze, tile.cell, 0, 1, tile.corners[2])
	var p11: Vector3 = _corner_position(maze, tile.cell, 1, 1, tile.corners[3])

	# Top face vertices
	var t0 = p00
	var t1 = p10
	var t2 = p11
	var t3 = p01

	# Bottom face vertices (extruded downwards by thickness derived from wall depth)
	var drop = Vector3(0, thickness, 0)
	var b0 = p00 - drop
	var b1 = p10 - drop
	var b2 = p11 - drop
	var b3 = p01 - drop

	# Top Face
	var top_normal: Vector3 = (t3 - t0).cross(t1 - t0).normalized()
	_add_quad(st, [t0, t1, t2, t3], [Vector2(t0.x, t0.z), Vector2(t1.x, t1.z), Vector2(t2.x, t2.z), Vector2(t3.x, t3.z)], top_normal, false)

	# Bottom Face
	var bot_normal = -top_normal
	_add_quad(st, [b3, b2, b1, b0], [Vector2(b3.x, b3.z), Vector2(b2.x, b2.z), Vector2(b1.x, b1.z), Vector2(b0.x, b0.z)], bot_normal, false)

	# Side Edge Faces connecting top and bottom
	_add_quad(st, [t0, t1, b1, b0], [Vector2(0, 0), Vector2(1, 0), Vector2(1, thickness), Vector2(0, thickness)], (t1 - t0).cross(b0 - t0).normalized(), false)
	_add_quad(st, [t1, t2, b2, b1], [Vector2(0, 0), Vector2(1, 0), Vector2(1, thickness), Vector2(0, thickness)], (t2 - t1).cross(b1 - t1).normalized(), false)
	_add_quad(st, [t2, t3, b3, b2], [Vector2(0, 0), Vector2(1, 0), Vector2(1, thickness), Vector2(0, thickness)], (t3 - t2).cross(b2 - t2).normalized(), false)
	_add_quad(st, [t3, t0, b0, b3], [Vector2(0, 0), Vector2(1, 0), Vector2(1, thickness), Vector2(0, thickness)], (t0 - t3).cross(b3 - t3).normalized(), false)


func _instantiate_wall(maze: Room, tile: Tile, side: Vector2i, wall_size: Vector3) -> void:
	if not wall:
		return

	var s: float = maze.scale_factor
	var x0: float = (tile.cell.x - maze.grid_size.x / 2.0) * s
	var z0: float = (tile.cell.y - maze.grid_size.z / 2.0) * s

	var p0: Vector2
	var p1: Vector2
	if side.x > 0:
		p0 = Vector2(x0 + s, z0)
		p1 = Vector2(x0 + s, z0 + s)
	elif side.x < 0:
		p0 = Vector2(x0, z0)
		p1 = Vector2(x0, z0 + s)
	elif side.y > 0:
		p0 = Vector2(x0, z0 + s)
		p1 = Vector2(x0 + s, z0 + s)
	else:
		p0 = Vector2(x0, z0)
		p1 = Vector2(x0 + s, z0)

	var edge: Vector2i = tile.edge(side)
	var y0: float = (edge.x - maze.floor_level) * s
	var y1: float = (edge.y - maze.floor_level) * s
	var base_y: float = minf(y0, y1)
	
	var top: float = maxf(y0, y1) + wall_size.y
	var segment_height = top - base_y

	var start_3d = Vector3(p0.x, y0, p0.y)
	var end_3d = Vector3(p1.x, y1, p1.y)
	var segment_vector = end_3d - start_3d
	var segment_length = segment_vector.length()

	var count_x = maxi(1, roundi(segment_length / wall_size.x))
	var count_y = maxi(1, roundi(segment_height / wall_size.y))

	var actual_step_x = segment_length / count_x
	var actual_step_y = segment_height / count_y

	var forward_dir = segment_vector.normalized()
	var up_dir = Vector3.UP
	var right_dir = up_dir.cross(forward_dir).normalized()
	var basis = Basis(right_dir, up_dir, forward_dir)

	# Apply rotation offset around the Y axis if configured
	if wall_rotation_offset != 0.0:
		basis = basis.rotated(Vector3.UP, deg_to_rad(wall_rotation_offset))

	for i in range(count_x):
		for j in range(count_y):
			var instance = wall.instantiate() as Node3D
			if not instance:
				continue
			
			instance.show()
			_apply_collision_settings(instance, collision_layer, collision_mask)

			var pos = start_3d + forward_dir * ((i + 0.5) * actual_step_x) + Vector3.UP * (base_y + (j + 0.5) * actual_step_y)
			
			add_child(instance)
			instance.transform = Transform3D(basis, pos)
			_geometry.append(instance)


func _get_node_aabb(node: Node, accumulated_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var aabb := AABB()
	var has_aabb := false

	if node is VisualInstance3D:
		var local_aabb = node.get_aabb()
		var global_aabb = _transform_aabb(accumulated_transform * node.transform, local_aabb)
		aabb = global_aabb
		has_aabb = true
	elif node is CollisionShape3D and node.shape:
		var shape_aabb = _get_shape_aabb(node.shape)
		if shape_aabb.has_volume():
			var global_aabb = _transform_aabb(accumulated_transform * node.transform, shape_aabb)
			if has_aabb:
				aabb = aabb.merge(global_aabb)
			else:
				aabb = global_aabb
				has_aabb = true

	for child in node.get_children():
		var child_transform = accumulated_transform
		if node is Node3D:
			child_transform = accumulated_transform * (node as Node3D).transform
		var child_aabb = _get_node_aabb(child, child_transform)
		if child_aabb.has_volume():
			if has_aabb:
				aabb = aabb.merge(child_aabb)
			else:
				aabb = child_aabb
				has_aabb = true

	return aabb


func _transform_aabb(trans: Transform3D, aabb: AABB) -> AABB:
	var points = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, aabb.size.z)
	]
	var res = AABB()
	for i in range(points.size()):
		var p = trans * points[i]
		if i == 0:
			res = AABB(p, Vector3.ZERO)
		else:
			res = res.expand(p)
	return res


func _get_shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		return AABB(-shape.size / 2.0, shape.size)
	elif shape is SphereShape3D:
		var r = shape.radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	elif shape is CylinderShape3D:
		var r = shape.radius
		var h = shape.height
		return AABB(Vector3(-r, -h / 2.0, -r), Vector3(r * 2.0, h, r * 2.0))
	return AABB(-Vector3.ONE * 0.5, Vector3.ONE)


func _apply_collision_settings(node: Node, layer: int, mask: int) -> void:
	if node is CollisionObject3D:
		node.collision_layer = layer
		node.collision_mask = mask
	for child in node.get_children():
		_apply_collision_settings(child, layer, mask)


func _add_quad(st: SurfaceTool, verts: Array[Vector3], uvs: Array[Vector2], normal: Vector3, invert: bool = false) -> void:
	var final_normal: Vector3 = -normal if invert else normal
	var v: Array[Vector3] = verts.duplicate()
	var u: Array[Vector2] = uvs.duplicate()
	if invert:
		v.reverse()
		u.reverse()

	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(final_normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(final_normal)
		st.set_uv(u[i])
		st.add_vertex(v[i])


func _prepare_material(material: Material) -> Material:
	if material is ShaderMaterial:
		var copy: ShaderMaterial = material.duplicate()
		copy.set_shader_parameter("uv_scale", Vector2.ONE)
		copy.set_shader_parameter("uv_offset", Vector2.ZERO)
		return copy
	return material


func _clear_geometry() -> void:
	for node in _geometry:
		if node and is_instance_valid(node):
			node.queue_free()
	_geometry.clear()
