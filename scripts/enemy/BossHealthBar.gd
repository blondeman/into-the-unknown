extends Control

@export var health_fill: TextureProgressBar
@export var smooth_time: float = 1.0
var _health_tween: Tween

func _set_health(amount: int, health: int, total: int):
	health_fill.max_value = total
	
	var scaled_smooth_time = smooth_time * (float(amount) / float(total))

	if _health_tween:
		_health_tween.kill()

	_health_tween = create_tween().set_parallel(true)
	_health_tween.tween_property(health_fill, "value", health, scaled_smooth_time)
