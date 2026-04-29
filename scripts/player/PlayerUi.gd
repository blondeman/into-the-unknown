extends Control
@export var health_fill_right: TextureProgressBar
@export var health_fill_left: TextureProgressBar
@export var smooth_time: float = 1.0

func _ready() -> void:
	health_fill_right.value = 0
	health_fill_left.value = 0

func _set_health(amount: int, health: int, total: int):
	health_fill_right.max_value = total
	health_fill_left.max_value = total
	
	var right_degrees := health_fill_right.radial_initial_angle - 180.0
	var left_degrees  := health_fill_left.radial_initial_angle - 180.0
	
	var scaled_smooth_time = smooth_time * (float(amount) / float(total))

	var tween := create_tween().set_parallel(true)
	tween.tween_property(health_fill_right, "value", health, scaled_smooth_time)
	tween.tween_property(health_fill_left, "value", health * (left_degrees / right_degrees), scaled_smooth_time)
