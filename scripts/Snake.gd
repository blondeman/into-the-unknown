class_name Snake
extends Node3D

@export var speed = 5.0
@export var rotation_speed = 10.0
@export var camera: Camera3D

@export var head: CharacterBody3D
@export var body: PhysicsBody3D

@export var segments: int = 4
@export var segment_length: float = 1.2

var body_nodes: Array[PhysicsBody3D]
var _saved_positions: Array[Vector3]

func _ready() -> void:
	create_body()


func create_body():
	for i in range(segments):
		var segment: PhysicsBody3D = body.duplicate()
		segment.name = "BodySegment_%d" % i
		add_child(segment)
		segment.global_position = head.global_position - head.transform.basis.z * segment_length * (i + 1)
		body_nodes.append(segment)
		_saved_positions.append(segment.global_position)
	body.queue_free()


func _physics_process(_delta: float) -> void:
	_follow(0, head.global_position)
	for i in range(1, body_nodes.size()):
		_follow(i, body_nodes[i - 1].global_position)


func _follow(i: int, target: Vector3):
	var segment := body_nodes[i]
	var diff := segment.global_position - target
	if diff.length() > segment_length:
		_saved_positions[i] = target + diff.normalized() * segment_length
	segment.global_position = _saved_positions[i]
	
	segment.look_at(target)
