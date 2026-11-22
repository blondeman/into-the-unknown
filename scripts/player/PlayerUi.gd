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
@export var stats_parent: Control
@export var score_fill_right: TextureProgressBar
@export var score_fill_left: TextureProgressBar
var _score_tween: Tween

@export_group("Endless")
@export var endless_parent: Control
const endless_score_label: String = "Depth: "
@export var endless_score_text: Label

@export_group("Inventory")
@export var inventory_parent: Control
@export var item_box: Control
@export var powerup_box: Control
@export var item_ui: PackedScene

func _ready() -> void:
	stats_parent.visible = false
	endless_parent.visible = false
	inventory_parent.visible = false
	
	health_fill_right.value = 0
	health_fill_left.value = 0
	
	score_fill_right.value = 0
	score_fill_left.value = 0
	GameManager.on_score_changed.connect(_set_score)
	
	endless_score_text.text = endless_score_label + "0"
	GameManager.on_endless_score_changed.connect(_set_endless_score)
	
	death_screen.hide()


func _set_health(amount: int, health: int, total: int):
	health_fill_right.max_value = total
	health_fill_left.max_value = total
	
	var right_degrees := health_fill_right.radial_initial_angle - 180.0
	var left_degrees  := health_fill_left.radial_initial_angle - 180.0
	
	var scaled_smooth_time = smooth_time * (float(abs(amount)) / float(total))

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
	
	if GameManager.current_level_id == GameManager.LEVEL_ID_ENDLESS:
		GameManager.load_menu()
	else:
		GameManager.reload_level()


func _set_score(amount: int, score: int, total: int):
	stats_parent.visible = true
	endless_parent.visible = false
	
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


func _set_endless_score(score: int):
	stats_parent.visible = false
	endless_parent.visible = true
	if score == 0:
		endless_score_text.text = endless_score_label + str(score)
	else:
		endless_score_text.text = endless_score_label + "-" + str(score)


func _on_inventory_on_inventory_changed(inventory: Inventory) -> void:
	inventory_parent.visible = true
	
	for child in item_box.get_children():
		child.queue_free()
	
	for child in powerup_box.get_children():
		child.queue_free()
	
	var inventory_items = inventory.get_item_counts()
	for item in inventory_items.keys():
		var item_texture: TextureRect = item_ui.instantiate()
		item_texture.texture = load("res://icon.svg")
		var item_label = item_texture.get_child(0) as Label
		item_label.text = str(inventory_items[item]) + "x"
		item_box.add_child(item_texture)
	
	var inventory_powerups = inventory.get_powerup_counts()
	for powerup in inventory_powerups.keys():
		var powerup_texture: TextureRect = item_ui.instantiate()
		powerup_texture.texture = load("res://icon.svg")
		var powerup_label = powerup_texture.get_child(0) as Label
		powerup_label.text = str(inventory_powerups[powerup]) + "x"
		powerup_box.add_child(powerup_texture)
