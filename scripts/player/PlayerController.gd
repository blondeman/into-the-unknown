class_name PlayerController
extends Node3D

const PLAYER_PARTICLES_DEATH = "death"
const PLAYER_PARTICLES_FIRE = "fire"

@export_group("Segments")
## Length from the head. A length of 1 will be a head and the end piece.
## A length of 0 will be calculated at runtime
@export var snake_length: int = 0
@export var segments_scenes: Array[PackedScene]
@export var segment_spacing: float = 1.1

@export_group("Movement")
@export var speed = 5.0
@export var rotation_speed = 10.0
@export var step_up_height: float = 0.2

@export var dash_speed = 10.0
@export var dash_rotation_speed = 4.0

@export_group("References")
@export var camera: Camera3D
@export var head: CharacterBody3D

var segments: Array[PlayerSegment]

var player_particles: Dictionary = {
	PLAYER_PARTICLES_DEATH: "res://scenes/player/player_death_particles.tscn",
	PLAYER_PARTICLES_FIRE: "res://scenes/player/player_burn_particles.tscn"
}

func _ready() -> void:
	create_body()


func create_body():
	segments.clear()
	
	if snake_length <= 0:
		snake_length = len(segments_scenes)
	
	var non_tail_segments = len(segments_scenes) - 1
	var last_segment = head
	head.process_priority = 0
	
	for i in snake_length:
		# loops the segments until the last one which is set to the tail piece
		var segment_id = i % non_tail_segments if i < snake_length - 1 else non_tail_segments
		var new_segment = segments_scenes[segment_id].instantiate() as PlayerSegment
		
		add_child(new_segment)
		
		new_segment.process_priority = i + 1
		new_segment.global_position = last_segment.global_position
		new_segment.position.z -= segment_spacing
		
		_link_segment(new_segment, last_segment)
		segments.append(new_segment)
		
		last_segment = new_segment


func add_segment() -> PlayerSegment:
	var tail_index = len(segments) - 1
	var tail_segment = segments[tail_index]
	var last_segment = segments[tail_index - 1]

	var non_tail_segments = len(segments_scenes) - 1
	var segment_id = tail_index % non_tail_segments
	var new_segment = segments_scenes[segment_id].instantiate() as PlayerSegment
	add_child(new_segment)

	new_segment.process_priority = tail_index
	new_segment.global_position = last_segment.global_position
	new_segment.position.z -= segment_spacing
	_link_segment(new_segment, last_segment)

	tail_segment.process_priority = tail_index + 1
	tail_segment.global_position = new_segment.global_position
	tail_segment.position.z -= segment_spacing
	_link_segment(tail_segment, new_segment)

	segments.insert(tail_index, new_segment)

	return new_segment


func _link_segment(segment: PlayerSegment, target: Node3D) -> void:
	segment.target = target
	segment.follow_distance = segment.global_position.distance_to(target.global_position)


func get_head_and_segments() -> Array[Node3D]:
	var list: Array[Node3D] = []
	list.append(head)
	list.append_array(segments)
	return list


func create_player_particles(particles: String):
	if !player_particles.has(particles):
		return
	
	var scene: PackedScene = load(player_particles[particles])
	var played_sound: bool = false
	
	for segment in get_head_and_segments():
		var instance = scene.instantiate()
		get_parent().add_child(instance)
		instance.global_transform = segment.global_transform
		if instance.has_method("start"):
			if !played_sound:
				instance.start()
				played_sound = true
			else:
				instance.start_no_audio()
	
	queue_free()
