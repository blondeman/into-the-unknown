extends Control

@export var health_fill: TextureProgressBar
@export var smooth_time: float = 1.0
@export var navigation: Navigation
var _health_tween: Tween

func _ready() -> void:
	visible = false


func _set_health(amount: int, health: int, total: int):
	health_fill.max_value = total
	
	var scaled_smooth_time = smooth_time * (float(amount) / float(total))

	if _health_tween:
		_health_tween.kill()

	_health_tween = create_tween().set_parallel(true)
	_health_tween.tween_property(health_fill, "value", health, scaled_smooth_time)


func _process(delta: float) -> void:
	if navigation.distance_to_target() < navigation.follow_range:
		visible = true
	else:
		visible = false
