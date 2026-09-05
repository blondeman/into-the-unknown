class_name Room
extends Node3D

var size: Vector3
var entrance: Doorway
var exits: Array[Doorway]

@export var test_bound: MeshInstance3D
@export var test_entrance: MeshInstance3D

func get_doorway_local_to_global(pos: Vector3) -> Vector3:
	return pos + global_position


func get_doorways_local_to_global(doorways: Array[Doorway]) -> Array[Doorway]:
	var global_exits: Array[Doorway]
	for exit in exits:
		global_exits.append(Doorway.new(get_doorway_local_to_global(exit.position), exit.direction * -1))
	return global_exits


func get_doorway_direction(pos: Vector3) -> Vector3i:
	if pos.x == size.x / 2:
		return Vector3i(1,0,0)
	elif pos.x == -size.x / 2:
		return Vector3i(-1,0,0)
	elif pos.z == size.z / 2:
		return Vector3i(0,0,1)
	elif pos.z == -size.z / 2:
		return Vector3i(0,0,-1)
	return Vector3i.ZERO


func generate_room_bounds(_entrance_position: Vector3, _entrance_direction: Vector3i) -> Array[Doorway]:
	size = Vector3(randi_range(5,20),randi_range(3,8),randi_range(5,20))
	global_position = _entrance_position + ((_entrance_direction as Vector3) * size / 2)
	entrance = Doorway.new(_entrance_position - global_position, _entrance_direction)
	(test_bound.mesh as BoxMesh).size = size
	
	var directions: Array[Vector3i] = Doorway.cardinals
	directions.remove_at(directions.find(_entrance_direction))

	for i in randi_range(0,2):
		directions.remove_at(directions.find(create_exit(directions)))
	
	test_entrance.position = entrance.position
	
	return get_doorways_local_to_global(exits)


func create_exit(directions: Array[Vector3i]) -> Vector3i:
	var exit_direction: Vector3i = directions[randi_range(0, len(directions) - 1)]
	var exit_position = ((exit_direction as Vector3) * size / 2) * -1

	exit_position.y = randi_range(-floor(size.y/2), floor(size.y/2))
	
	if abs(exit_direction.x) > 0:
		exit_position.z = randi_range(-floor(size.z/2), floor(size.z/2))
	else:
		exit_position.x = randi_range(-floor(size.x/2), floor(size.x/2))
	
	exits.append(Doorway.new(exit_position, exit_direction))
	
	return exit_direction


func _to_string() -> String:
	return "["+name+"] (" + \
	"global_position: "+ str(global_position) + ", " + \
	"size: "+ str(size) + ", " + \
	"entrance_position: "+ str(get_doorway_local_to_global(entrance.position)) + ", " + \
	"entrance_direction: "+ str(entrance.direction) + ", " + \
	"exits: "+ str(len(exits)) + ", " + \
	")"
