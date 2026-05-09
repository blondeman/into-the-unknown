extends Node

@export var menu_container: Control
@export var controls_container: Control

func _ready():
	_on_back_pressed()

func _on_start_button_pressed():
	GameManager.load_intro()


func _on_quit_button_pressed():
	get_tree().quit()


func _on_level_button_pressed(level: int):
	GameManager.load_level(level)


func _on_back_pressed() -> void:
	menu_container.visible = true
	controls_container.visible = false


func _on_controls_pressed() -> void:
	menu_container.visible = false
	controls_container.visible = true
