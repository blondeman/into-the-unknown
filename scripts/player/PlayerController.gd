class_name PlayerController
extends Node3D

@export var speed = 5.0
@export var rotation_speed = 10.0
@export var camera: Camera3D

@export var head: CharacterBody3D
@export var body: PhysicsBody3D

var segments: Array[PlayerSegment]
var _saved_positions: Array[Vector3]
var segment_lengths: Array[float]

func _ready() -> void:
	create_body()


func create_body():
	for child in get_children():
		if child is PlayerSegment:
			segments.append(child)
			_saved_positions.append(child.global_position)
	
	segment_lengths.append(head.global_position.distance_to(segments[0].global_position))
	for i in range(segments.size() - 1):
		segment_lengths.append(segments[i].global_position.distance_to(segments[i + 1].global_position))


func _process(_delta: float) -> void:
	_follow(0, head.global_position)
	for i in range(1, segments.size()):
		_follow(i, segments[i - 1].global_position)


func _follow(i: int, target: Vector3):
	var segment := segments[i]
	var diff := segment.global_position - target
	var length := segment_lengths[i]

	if diff.length() > length:
		_saved_positions[i] = target + diff.normalized() * length
	else:
		_saved_positions[i] = segment.global_position

	segment.global_position = _saved_positions[i]
	segment.look_at(target)


func get_head_and_segments() -> Array[Node3D]:
	var list: Array[Node3D] = []
	list.append(head)
	list.append_array(segments)
	return list
