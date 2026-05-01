extends Control
@export_group("Health")
@export var health_fill_right: TextureProgressBar
@export var health_fill_left: TextureProgressBar
@export var smooth_time: float = 1.0
var _health_tween: Tween

@export_group("Death")
@export var death_screen: CanvasItem
@export var death_timer: float = 1.0
@export var fade_duration: float = 1.0
@export var restart_timer: float = 3.0

@export_group("Stats")
@export var score_fill_right: TextureProgressBar
@export var score_fill_left: TextureProgressBar
var _score_tween: Tween

func _ready() -> void:
	health_fill_right.value = 0
	health_fill_left.value = 0
	
	score_fill_right.value = 0
	score_fill_left.value = 0
	GameManager.on_score_changed.connect(_set_score)
	
	death_screen.hide()


func _set_health(amount: int, health: int, total: int):
	health_fill_right.max_value = total
	health_fill_left.max_value = total
	
	var right_degrees := health_fill_right.radial_initial_angle - 180.0
	var left_degrees  := health_fill_left.radial_initial_angle - 180.0
	
	var scaled_smooth_time = smooth_time * (float(amount) / float(total))

	if _health_tween:
		_health_tween.kill()

	_health_tween = create_tween().set_parallel(true)
	_health_tween.tween_property(health_fill_right, "value", health, scaled_smooth_time)
	_health_tween.tween_property(health_fill_left, "value", health * (left_degrees / right_degrees), scaled_smooth_time)


func _on_die():
	reparent(GameManager.current_scene)
	
	await get_tree().create_timer(death_timer).timeout
	
	death_screen.modulate.a = 0.0
	death_screen.show()
	var tween := create_tween()
	tween.tween_property(death_screen, "modulate:a", 1.0, fade_duration)
	
	await get_tree().create_timer(restart_timer).timeout
	
	GameManager.reload_level()


func _set_score(amount: int, score: int, total: int):
	score_fill_right.max_value = total
	score_fill_left.max_value = total
	
	var right_degrees := score_fill_right.radial_initial_angle - 180.0
	var left_degrees  := score_fill_left.radial_initial_angle - 180.0

	var scaled_smooth_time = smooth_time * (float(amount) / float(total))

	if _score_tween:
		_score_tween.kill()

	_score_tween = create_tween().set_parallel(true)
	_score_tween.tween_property(score_fill_right, "value", score, scaled_smooth_time)
	_score_tween.tween_property(score_fill_left, "value", score * (left_degrees / right_degrees), scaled_smooth_time)
