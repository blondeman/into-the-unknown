class_name PlayerController
extends Node3D

@export var speed = 5.0
@export var rotation_speed = 10.0
@export var step_up_height: float = 0.2

@export var dash_speed = 10.0
@export var dash_rotation_speed = 4.0

@export var camera: Camera3D

@export var head: CharacterBody3D
@export var body: PhysicsBody3D

var segments: Array[PlayerSegment]

func _ready() -> void:
	create_body()


func create_body():
	for child in get_children():
		if child is PlayerSegment:
			segments.append(child)

	if segments.is_empty():
		return

	_link_segment(segments[0], head)
	for i in range(1, segments.size()):
		_link_segment(segments[i], segments[i - 1])

	# Guarantee follow order within a frame: head must update before
	# segment 0 reads it, segment 0 before segment 1, etc.
	head.process_priority = 0
	for i in range(segments.size()):
		segments[i].process_priority = i + 1


func _link_segment(segment: PlayerSegment, target: Node3D) -> void:
	segment.target = target
	segment.follow_distance = segment.global_position.distance_to(target.global_position)


func get_head_and_segments() -> Array[Node3D]:
	var list: Array[Node3D] = []
	list.append(head)
	list.append_array(segments)
	return list
