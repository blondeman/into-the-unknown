extends RigidBody3D

@export var timeout: float = 20

signal hit_player()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer = get_tree().create_timer(timeout)
	timer.timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.get_parent().is_in_group("player"):
		hit_player.emit()
	
	freeze = true
	
	var old_transform = global_transform
	reparent.call_deferred(body)
	global_transform = old_transform
