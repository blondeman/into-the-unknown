extends Node3D

@export var room_scene: PackedScene
var rooms: Array[Room]

func _ready():
	var exit1 = generate_room(Vector3.ZERO, Vector3i(1,0,0))
	var exit2 = generate_room(exit1[0],-exit1[1])
	var exit3 = generate_room(exit2[0],-exit2[1])


func generate_room(entrance_position: Vector3, entrance_direction: Vector3i) -> Array[Vector3]:
	var new_room: Room = room_scene.instantiate()
	add_child(new_room)
	return new_room.generate_room_bounds(entrance_position, entrance_direction)
