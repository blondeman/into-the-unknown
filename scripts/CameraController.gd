extends Camera3D

@export var target: Node3D
var offset: Vector3


func _ready() -> void:
	offset = global_position


func _process(_delta: float) -> void:
	if !target:
		return
	
	if target is Snake:
		global_position = target.head.global_position + offset
	else:
		global_position = target.global_position + offset
