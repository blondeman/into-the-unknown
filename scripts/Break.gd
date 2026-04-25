extends Node3D

@export var intensity: float = 8.0
@export var random_intensity: float = 2.0
@export var dissolve_duration: float = 1.0

func _ready() -> void:
	for piece: RigidBody3D in get_children():
		piece.angular_damp = 3
		var random_offset = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized() * random_intensity
		piece.apply_impulse(piece.get_child(0).position.normalized() * intensity + random_offset, global_position)
	
	await get_tree().create_timer(5).timeout
	
	dissolve()

func dissolve():
	var tween = create_tween()
	tween.set_parallel(true)
	
	for piece: RigidBody3D in get_children():
		for child in piece.get_children():
			if child is MeshInstance3D:
				tween.tween_property(child, "scale", Vector3.ZERO, dissolve_duration)
	
	await tween.finished
	queue_free()
