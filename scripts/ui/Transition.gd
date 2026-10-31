extends Node

@export var background: ColorRect
@export var fade_duration: float = 1

signal on_fade_in_finished()
signal on_fade_out_finished()


func fade_in() -> void:
	background.modulate.a = 0.0
	background.show()
	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 1.0, fade_duration)
	tween.tween_callback(func(): on_fade_in_finished.emit())

func fade_out() -> void:
	background.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func(): on_fade_out_finished.emit())
