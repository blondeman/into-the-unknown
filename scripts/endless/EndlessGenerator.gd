extends Node3D

@export var room_scene: PackedScene
var rooms: Array[Room]

func _ready():
	var exits = generate_room(Doorway.new())
	for i in 3:
		var new_exits: Array[Doorway]
		for exit in exits:
			new_exits.append_array(generate_room(exit))
		exits = new_exits


func generate_room(entrance: Doorway) -> Array[Doorway]:
	var new_room: Room = room_scene.instantiate()
	add_child(new_room)
	rooms.append(new_room)
	return new_room.generate_room_bounds(entrance.position, entrance.direction)
