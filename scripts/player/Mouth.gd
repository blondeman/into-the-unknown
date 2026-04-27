extends Area3D


func _ready() -> void:
	body_entered.connect(_on_area_entered)


func _on_area_entered(body: Node3D):
	if body is Destructible:
		body.destroy()
	
	for child in body.get_children():
		if child is Health:
			child.take_damage(100)
			break
