extends CPUParticles3D

@export var timer: float = 2

func start() -> void:
	emitting = true
	await get_tree().create_timer(timer).timeout
	queue_free()
