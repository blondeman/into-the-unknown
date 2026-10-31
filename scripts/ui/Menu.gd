extends Node

@export var menu_container: Control
@export var controls_container: Control
@export var levels_container: Control
@export var credits_container: Control

func _get_containers() -> Array[Control]:
	return [
		menu_container,
		controls_container,
		levels_container,
		credits_container
	]


func _hide_containers():
	for container in _get_containers():
		container.visible = false


func _ready():
	_on_back_pressed()

func _on_start_button_pressed():
	GameManager.load_intro()


func _on_quit_button_pressed():
	get_tree().quit()


func _on_level_button_pressed(level: int):
	GameManager.load_level(level)


func _on_endless_pressed() -> void:
	GameManager.load_endless()


func _on_back_pressed() -> void:
	_hide_containers()
	menu_container.visible = true


func _on_controls_pressed() -> void:
	_hide_containers()
	controls_container.visible = true


func _on_credits_pressed() -> void:
	_hide_containers()
	credits_container.visible = true


func _on_levels_pressed() -> void:
	levels_container.visible = !levels_container.visible
