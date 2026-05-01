class_name Destructible
extends StaticBody3D

@export var destroyed_object: PackedScene
@export var particle_system: CPUParticles3D

func destroy():
	CameraEffects.on_shake.emit(0.2, 0.6)
	
	if destroyed_object:
		var new_destroyed_object = destroyed_object.instantiate()
		get_parent().add_child(new_destroyed_object)
		new_destroyed_object.transform = transform
	
	if particle_system:
		_cleanup_particles()
	
	queue_free()
	await tree_exited
	GameManager.on_rebake.emit()


func _cleanup_particles() -> void:
	particle_system.reparent(get_parent())
	particle_system.emitting = false
	await get_tree().create_timer(particle_system.lifetime).timeout
	particle_system.queue_free()


func _exit_tree() -> void:
	GameManager.add_score()
