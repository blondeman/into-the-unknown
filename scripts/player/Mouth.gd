extends Area3D


func _ready() -> void:
	body_entered.connect(_on_area_entered)


func _on_area_entered(body: Node3D):
	if body is Destructable:
		body.destroy()
