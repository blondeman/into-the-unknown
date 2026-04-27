extends Node

func _on_start_button_pressed():
	GameManager.load_level(0)

func _on_quit_button_pressed():
	get_tree().quit()

func _on_level_button_pressed(level: int):
	GameManager.load_level(level)
