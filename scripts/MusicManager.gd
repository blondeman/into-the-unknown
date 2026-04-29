extends Node

@export var audio_stream_players: Array[AudioStreamPlayer]
@export var fade_speed = 0.1

var _tweens: Array[Tween] = []

func _ready() -> void:
	_tweens.resize(audio_stream_players.size())
	for id in audio_stream_players.size():
		audio_stream_players[id].volume_linear = 0
		audio_stream_players[id].play()
	
	audio_stream_players[0].volume_linear = 1

func _fade_track(id: int, target_volume: float):
	if id >= 0 and id < audio_stream_players.size():
		if _tweens[id]:
			_tweens[id].kill()
		_tweens[id] = create_tween()
		_tweens[id].tween_property(audio_stream_players[id], "volume_linear", target_volume, fade_speed)

func enable_track(id: int):
	_fade_track(id, 1.0)

func disable_track(id: int):
	_fade_track(id, 0.0)
