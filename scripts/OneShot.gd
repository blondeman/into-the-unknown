extends CPUParticles3D

@export var timer: float = 2
@export var sounds: Array[AudioStream]
@export var audio_stream_player: AudioStreamPlayer3D

func start() -> void:
	emitting = true
	audio_stream_player.stream = sounds[randi() % sounds.size()]
	audio_stream_player.play()
	await get_tree().create_timer(timer).timeout
	queue_free()
