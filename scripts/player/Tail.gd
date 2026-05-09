extends CharacterBody3D


func _exit_tree() -> void:
	GameManager.add_score()
