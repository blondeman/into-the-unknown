extends Node3D

@export var intensity: float = 8.0
@export var random_intensity: float = 2.0
@export var dissolve_duration: float = 1.0

@export var sound_list_1: Array[AudioStream]
@export var sound_list_2: Array[AudioStream]

var rigidbody_pieces: Array[RigidBody3D]

func _ready() -> void:
	for piece in get_children():
		if piece is RigidBody3D:
			rigidbody_pieces.append(piece as RigidBody3D)
		if piece is CPUParticles3D:
			piece.emitting = true
	
	for piece: RigidBody3D in rigidbody_pieces:
		piece.angular_damp = 3
		var random_offset = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized() * random_intensity
		piece.apply_impulse(piece.get_child(0).position.normalized() * intensity + random_offset, global_position)
	
	_play_random_sound(sound_list_1)
	_play_random_sound(sound_list_2)
	
	await get_tree().create_timer(5).timeout
	
	dissolve()

func dissolve():
	var tween = create_tween()
	tween.set_parallel(true)
	
	for piece: RigidBody3D in rigidbody_pieces:
		for child in piece.get_children():
			if child is MeshInstance3D:
				tween.tween_property(child, "scale", Vector3.ZERO, dissolve_duration)
	
	await tween.finished
	queue_free()

func _play_random_sound(list: Array[AudioStream]) -> void:
	if list.is_empty():
		return
	var player = AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = list[randi() % list.size()]
	player.play()
	await player.finished
	player.queue_free()
