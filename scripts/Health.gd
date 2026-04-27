class_name Health
extends Node

@export var on_death_scene: PackedScene
@export var max_health: int = 100
var current_health: int

signal on_take_damage(amount: int, health: int, total: int)
signal on_die()

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int):
	current_health -= amount
	on_take_damage.emit(amount, current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	on_die.emit()
	
	var parent = get_parent()
	var new_on_death_scene = on_death_scene.instantiate()
	parent.get_parent().add_child(new_on_death_scene)
	new_on_death_scene.transform = parent.transform
	if new_on_death_scene.has_method("start"):
		new_on_death_scene.start()
	
	parent.queue_free()
