extends AnimationPlayer

@export var animation_name: String

func _ready() -> void:
	play(animation_name)
