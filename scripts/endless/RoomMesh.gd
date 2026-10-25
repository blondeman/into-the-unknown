class_name RoomMesh
extends Node3D


@export var mesh_thickness: float = 0.1
var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var wall_height: int = 1
@export var floor_material: Material
@export var wall_material: Material

@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1
@export var debug_path: bool = false


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
var _debug_planes: Array[MeshInstance3D] = []


func load_mesh(room: Room) -> void:
	_clear_geometry()
	_clear_debug_path()

	var maze := room as Room
	if not maze:
		push_error("RoomMesh can only build Room rooms")
		return

	_build_geometry(maze)
	if debug_path:
		_draw_debug_path(maze)


func unload_mesh() -> void:
	_clear_geometry()
	_clear_debug_path()


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


# --- Geometry ---

func _build_geometry(maze: Room) -> void:
	var columns: Dictionary = _collect_tiles(maze)
	var open_sides: Dictionary = _get_open_sides(maze)

	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floor_count: int = 0
	var wall_count: int = 0

	for column in columns.values():
		for tile in column:
			_add_floor(floor_st, maze, tile)
			floor_count += 1
			for side in sides:
				if _is_connected(tile, side, columns, open_sides):
					continue
				_add_wall(wall_st, maze, tile, side)
				wall_count += 1

	var mesh := ArrayMesh.new()
	if floor_count > 0:
		floor_st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _prepare_material(floor_material))
	if wall_count > 0:
		wall_st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _prepare_material(wall_material))
	if mesh.get_surface_count() == 0:
		return

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


func _add_floor(st: SurfaceTool, maze: Room, tile: Tile) -> void:
	var p00: Vector3 = _corner_position(maze, tile.cell, 0, 0, tile.corners[0])
	var p10: Vector3 = _corner_position(maze, tile.cell, 1, 0, tile.corners[1])
	var p01: Vector3 = _corner_position(maze, tile.cell, 0, 1, tile.corners[2])
	var p11: Vector3 = _corner_position(maze, tile.cell, 1, 1, tile.corners[3])

	# Top face vertices
	var t0 = p00
	var t1 = p10
	var t2 = p11
	var t3 = p01

	# Bottom face vertices (extruded downwards by mesh_thickness)
	var drop = Vector3(0, mesh_thickness, 0)
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
	_add_quad(st, [t0, t1, b1, b0], [Vector2(0, 0), Vector2(1, 0), Vector2(1, mesh_thickness), Vector2(0, mesh_thickness)], (t1 - t0).cross(b0 - t0).normalized(), false)
	_add_quad(st, [t1, t2, b2, b1], [Vector2(0, 0), Vector2(1, 0), Vector2(1, mesh_thickness), Vector2(0, mesh_thickness)], (t2 - t1).cross(b1 - t1).normalized(), false)
	_add_quad(st, [t2, t3, b3, b2], [Vector2(0, 0), Vector2(1, 0), Vector2(1, mesh_thickness), Vector2(0, mesh_thickness)], (t3 - t2).cross(b2 - t2).normalized(), false)
	_add_quad(st, [t3, t0, b0, b3], [Vector2(0, 0), Vector2(1, 0), Vector2(1, mesh_thickness), Vector2(0, mesh_thickness)], (t0 - t3).cross(b3 - t3).normalized(), false)


func _add_wall(st: SurfaceTool, maze: Room, tile: Tile, side: Vector2i) -> void:
	var s: float = maze.scale_factor
	var x0: float = (tile.cell.x - maze.grid_size.x / 2.0) * s
	var z0: float = (tile.cell.y - maze.grid_size.z / 2.0) * s

	var p0: Vector2
	var p1: Vector2
	var outward_normal: Vector3
	if side.x > 0:
		p0 = Vector2(x0 + s, z0)
		p1 = Vector2(x0 + s, z0 + s)
		outward_normal = Vector3.RIGHT
	elif side.x < 0:
		p0 = Vector2(x0, z0)
		p1 = Vector2(x0, z0 + s)
		outward_normal = Vector3.LEFT
	elif side.y > 0:
		p0 = Vector2(x0, z0 + s)
		p1 = Vector2(x0 + s, z0 + s)
		outward_normal = Vector3.BACK
	else:
		p0 = Vector2(x0, z0)
		p1 = Vector2(x0 + s, z0)
		outward_normal = Vector3.FORWARD

	# Inward facing normal (pointing into the room/tile)
	var inward_normal = -outward_normal

	var edge: Vector2i = tile.edge(side)
	var y0: float = (edge.x - maze.floor_level) * s
	var y1: float = (edge.y - maze.floor_level) * s
	var top: float = maxf(y0, y1) + wall_height * s

	# Inward-facing front vertices
	var f_v0 = Vector3(p0.x, y0, p0.y)
	var f_v1 = Vector3(p1.x, y1, p1.y)
	var f_v2 = Vector3(p1.x, top, p1.y)
	var f_v3 = Vector3(p0.x, top, p0.y)

	# Extruded back vertices (outward direction)
	var offset = outward_normal * mesh_thickness
	var b_v0 = f_v0 + offset
	var b_v1 = f_v1 + offset
	var b_v2 = f_v2 + offset
	var b_v3 = f_v3 + offset

	var along0: float = p0.y if side.x != 0 else p0.x
	var along1: float = p1.y if side.x != 0 else p1.x
	var uv_front: Array[Vector2] = [
		Vector2(along0, y0 / 2.0), Vector2(along1, y1 / 2.0),
		Vector2(along1, top / 2.0), Vector2(along0, top / 2.0)]

	# 1. Inward Face (facing into the room)
	_add_quad(st, [f_v3, f_v2, f_v1, f_v0], uv_front, inward_normal, false)

	# 2. Outward Face (facing out of the room)
	_add_quad(st, [b_v0, b_v1, b_v2, b_v3], uv_front, outward_normal, false)

	# 3. Top Cap
	_add_quad(st, [f_v3, f_v2, b_v2, b_v3], [Vector2(0, 0), Vector2(1, 0), Vector2(1, mesh_thickness), Vector2(0, mesh_thickness)], Vector3.UP, false)

	# 4. Side Caps (Start and End)
	_add_quad(st, [f_v0, f_v3, b_v3, b_v0], [Vector2(0, 0), Vector2(1, 0), Vector2(1, wall_height), Vector2(0, wall_height)], (f_v3 - f_v0).cross(b_v0 - f_v0).normalized(), false)
	_add_quad(st, [f_v1, b_v1, b_v2, f_v2], [Vector2(0, 0), Vector2(1, 0), Vector2(1, wall_height), Vector2(0, wall_height)], (b_v1 - f_v1).cross(f_v2 - f_v1).normalized(), false)


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
		node.queue_free()
	_geometry.clear()


# --- Debug Path ---

func _draw_debug_path(maze: Room) -> void:
	var chamber_material := _make_debug_material(Color(0.2, 0.5, 1.0))
	var path_material := _make_debug_material(Color(1.0, 0.6, 0.1))

	for chamber in maze.chambers:
		var plane := PlaneMesh.new()
		plane.size = Vector2(chamber.footprint.size.x, chamber.footprint.size.y) * maze.scale_factor

		var center: Vector3 = maze.chamber_center_local(chamber) - Vector3.UP * maze.scale_factor * 0.02
		_add_debug_plane(plane, chamber_material, Transform3D(Basis.IDENTITY, center))

	for tile in maze.path_tiles:
		var dir: Vector3i = tile.direction
		var slope: float = tile.slope

		var forward := Vector3(dir.x, slope, dir.z).normalized()
		var normal := Vector3(-slope * dir.x, 1.0, -slope * dir.z).normalized()

		var plane := PlaneMesh.new()
		plane.size = Vector2(maze.scale_factor, maze.scale_factor * sqrt(1.0 + slope * slope))

		_add_debug_plane(plane, path_material,
			Transform3D(Basis(normal.cross(forward), normal, forward), tile.position))


func _make_debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _add_debug_plane(plane: PlaneMesh, material: Material, plane_transform: Transform3D) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = material
	add_child(instance)
	instance.transform = plane_transform
	_debug_planes.append(instance)


func _clear_debug_path() -> void:
	for plane in _debug_planes:
		plane.queue_free()
	_debug_planes.clear()
