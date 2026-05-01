class_name Health
extends Node

@export var on_death_scene: PackedScene
@export var max_health: int = 100
var current_health: int

@export var hit_sounds: Array[AudioStream]

signal on_health_changed(amount: int, health: int, total: int)
signal on_die()

func _ready() -> void:
	current_health = max_health
	await get_tree().process_frame
	on_health_changed.emit(current_health, current_health, max_health)

func take_damage(amount: int):
	current_health -= amount
	on_health_changed.emit(amount, current_health, max_health)
	_play_sound()
	
	if current_health <= 0:
		die()

func take_healing(amount: int):
	take_damage(-amount)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		take_damage(100)

func die():
	on_die.emit()
	
	var parent = get_parent()
	var new_on_death_scene = on_death_scene.instantiate()
	parent.get_parent().add_child(new_on_death_scene)
	if parent is PlayerController:
		new_on_death_scene.transform = parent.head.transform
	else:
		new_on_death_scene.transform = parent.transform
	if new_on_death_scene.has_method("start"):
		new_on_death_scene.start()
	
	parent.queue_free()

func _play_sound():
	if hit_sounds.size() == 0:
		return
	
	var player = AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = hit_sounds[randi() % hit_sounds.size()]
	player.play()
	player.finished.connect(player.queue_free)
