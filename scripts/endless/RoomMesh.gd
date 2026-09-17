class_name RoomMesh
extends Node3D

const FLOOR_THICKNESS := 1.0
const WALL_HEIGHT := 10
const WALL_THICKNESS := 0.5
const WALL_HEIGHT_SHRINK := 0.2
const RAMP_XY_RATIO := 5.0 / 3.0
const MIN_RAMP_HEIGHT := 0.1

@export var floor_mesh: MeshInstance3D
@export var floor_collision: CollisionShape3D

@export var ramp_mesh: MeshInstance3D
@export var ramp_collision: CollisionShape3D

@export var wall_meshes: Array[MeshInstance3D]
@export var wall_collisions: Array[CollisionShape3D]

var _ramp_instances: Array[MeshInstance3D] = []
var _ramp_collision_instances: Array[CollisionShape3D] = []


func set_room_mesh(room: Room):
	var floor_top_y: float = room.entrance.position.y

	_set_floor_mesh(room, floor_top_y)
	_set_ramp_mesh(room, floor_top_y)
	_set_wall_mesh(room, floor_top_y)


func _set_wall_mesh(room: Room, floor_top_y: float):
	var directions: Array[Vector3i] = Doorway.cardinals.duplicate()
	if len(wall_meshes) != len(wall_collisions) || len(wall_meshes) != len(directions):
		return

	for i in range(len(directions)):
		var direction = directions[i]
		var wall_mesh = wall_meshes[i]
		var wall_collision = wall_collisions[i]

		if direction == room.entrance.direction:
			wall_mesh.queue_free()
			wall_collision.queue_free()
			continue

		var exit_id = room.exits.find_custom(func(e): return e.direction == direction)
		var wall_height: float = WALL_HEIGHT
		if exit_id != -1:
			wall_height = room.exits[exit_id].position.y - floor_top_y
			if abs(wall_height) < 0.1:
				wall_mesh.queue_free()
				wall_collision.queue_free()
				continue

		_place_wall(wall_mesh, wall_collision, -direction, room, wall_height, floor_top_y)


func _place_wall(wall_mesh: MeshInstance3D, wall_collision: CollisionShape3D, direction: Vector3i, room: Room, wall_height: float, floor_top_y: float) -> void:
	var wall_position_y = floor_top_y + wall_height / 2
	var dir_vec = direction as Vector3

	var box_size: Vector3
	if abs(dir_vec.x) > 0.5:
		box_size = Vector3(WALL_THICKNESS, abs(wall_height) - WALL_HEIGHT_SHRINK, room.size.z)
	else:
		box_size = Vector3(room.size.x, abs(wall_height) - WALL_HEIGHT_SHRINK, WALL_THICKNESS)

	var position = dir_vec * (room.size / 2)
	position.y = wall_position_y - WALL_HEIGHT_SHRINK / 2

	wall_mesh.position = position
	(wall_mesh.mesh as BoxMesh).size = box_size
	(wall_collision.shape as BoxShape3D).size = box_size


func _set_floor_mesh(room: Room, floor_top_y: float):
	var size = room.size
	size.y = FLOOR_THICKNESS
	(floor_mesh.mesh as BoxMesh).size = size
	(floor_collision.shape as BoxShape3D).size = size
	
	floor_mesh.position.y = floor_top_y - FLOOR_THICKNESS / 2.0


func _set_ramp_mesh(room: Room, floor_top_y: float):
	_clear_extra_ramps()

	var ramp_index: int = 0
	for exit in room.exits:
		if abs(exit.position.y - floor_top_y) < MIN_RAMP_HEIGHT:
			continue

		var mesh_node: MeshInstance3D
		var collision_node: CollisionShape3D

		if ramp_index == 0:
			mesh_node = ramp_mesh
			collision_node = ramp_collision
			mesh_node.visible = true
		else:
			mesh_node = ramp_mesh.duplicate()
			mesh_node.mesh = ramp_mesh.mesh.duplicate()
			add_child(mesh_node)
			_ramp_instances.append(mesh_node)

			var body_index: int = ramp_mesh.get_children().find(ramp_collision.get_parent())
			if body_index == -1:
				push_error("RoomMesh: ramp_collision's parent is not a child of ramp_mesh - check scene structure")
				continue
			var body_node: Node = mesh_node.get_child(body_index)

			var collision_index: int = ramp_collision.get_parent().get_children().find(ramp_collision)
			collision_node = body_node.get_child(collision_index)

		_set_ramp(room, exit, floor_top_y, mesh_node, collision_node)
		ramp_index += 1

	if ramp_index == 0:
		ramp_mesh.visible = false


func _clear_extra_ramps() -> void:
	for r in _ramp_instances:
		r.queue_free()
	_ramp_instances.clear()


func _set_ramp(room: Room, exit: Doorway, floor_top_y: float, mesh_node: MeshInstance3D, collision_node: CollisionShape3D) -> void:
	var exit_y: float = exit.position.y
	var is_down: bool = exit_y < floor_top_y

	var ramp_height: float = abs(exit_y - floor_top_y)
	var ramp_width: float = ramp_height * RAMP_XY_RATIO

	var to_interior: Vector3 = -Vector3(exit.direction.x, 0, exit.direction.z).normalized()

	var yaw: float = atan2(-to_interior.z, to_interior.x)
	if is_down:
		yaw += PI

	mesh_node.position = exit.position
	mesh_node.position.y = (floor_top_y + exit_y) / 2.0
	mesh_node.rotation = Vector3.ZERO
	mesh_node.rotation.y = yaw

	var ramp_mesh_prism: PrismMesh = mesh_node.mesh as PrismMesh
	ramp_mesh_prism.size.y = ramp_height
	ramp_mesh_prism.size.x = ramp_width

	var offset_sign: float = 1.0 if is_down else -1.0
	var local_shift: Vector3 = to_interior * (ramp_width / 2.0) * offset_sign
	mesh_node.position += local_shift

	var convex_shape: ConvexPolygonShape3D = ramp_mesh_prism.create_convex_shape()
	if convex_shape and convex_shape.points.size() >= 3:
		collision_node.shape = convex_shape
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(ramp_width, ramp_height, ramp_mesh_prism.size.z)
		collision_node.shape = box
