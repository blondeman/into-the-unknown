class_name PlayerController
extends Node3D

const PLAYER_PARTICLES_DEATH = "death"
const PLAYER_PARTICLES_FIRE = "fire"

@export var speed = 5.0
@export var rotation_speed = 10.0
@export var step_up_height: float = 0.2

@export var dash_speed = 10.0
@export var dash_rotation_speed = 4.0

@export var camera: Camera3D

@export var head: CharacterBody3D

var segments: Array[PlayerSegment]

@export var player_particles: Dictionary = {
	PLAYER_PARTICLES_DEATH: "res://scenes/player/player_death_particles.tscn",
	PLAYER_PARTICLES_FIRE: "res://scenes/player/player_burn_particles.tscn"
}

func _ready() -> void:
	create_body()


func create_body():
	for child in get_children():
		if child is PlayerSegment:
			segments.append(child)

	if segments.is_empty():
		return

	var head_pos := head.global_position
	segments.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(head_pos) \
			< b.global_position.distance_squared_to(head_pos)
	)

	_link_segment(segments[0], head)
	for i in range(1, segments.size()):
		_link_segment(segments[i], segments[i - 1])

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
