extends ColorRect

func _ready() -> void:
	material.set_shader_parameter("rect_size", size)
