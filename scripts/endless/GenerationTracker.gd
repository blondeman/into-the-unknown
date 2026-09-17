class_name GenerationTracker
extends Node3D

@export var generator: EndlessGenerator
@export var target: Node3D
var current_room: Room = null

func _ready() -> void:
	if target is PlayerController:
		target = (target as PlayerController).head


func get_current_room() -> Room:
	for room in generator.rooms:
		if room.is_in_bounds(target.global_position):
			return room
	return null


func _process(delta: float) -> void:
	var _current_room: Room = get_current_room()
	if _current_room != current_room:
		current_room = _current_room
		generator.branch_room(current_room)
