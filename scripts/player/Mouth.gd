extends Area3D


@export var health: Health


func _ready() -> void:
	body_entered.connect(_on_area_entered)


func _on_area_entered(body: Node3D):
	if body is Destructible:
		body.destroy()
		if body.is_in_group("fire"):
			health.take_healing(20)
	
	for child in body.get_children():
		if child is Health:
			child.take_damage(100)
			break
