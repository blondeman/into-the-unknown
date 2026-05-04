extends Attack

@export var arrow: PackedScene
@export var velocity: float = 10

func _attack(target: Node3D) -> void:
	var arrow_instance = arrow.instantiate()
	get_tree().root.add_child(arrow_instance)
	arrow_instance.hit_player.connect(func(): deal_damage(target))
	arrow_instance.global_position = enemy_controller.global_position
	
	var angle = _solve_angle(target.global_position)
	if is_nan(angle):
		return
	
	var to_target = target.global_position - enemy_controller.global_position
	var horizontal_dir = Vector3(to_target.x, 0, to_target.z).normalized()
	
	arrow_instance.linear_velocity = (horizontal_dir * cos(angle) + Vector3.UP * sin(angle)) * velocity
	arrow_instance.look_at(arrow_instance.global_position + arrow_instance.linear_velocity)

func _solve_angle(target_pos: Vector3) -> float:
	var to_target = target_pos - enemy_controller.global_position
	var dx = Vector2(to_target.x, to_target.z).length() # horizontal distance
	var dy = to_target.y                                 # vertical distance
	var g = ProjectSettings.get_setting("physics/3d/default_gravity")
	var v = velocity
	
	var discriminant = pow(v, 4) - g * (g * dx * dx + 2 * dy * v * v)
	if discriminant < 0:
		return NAN
	
	return atan((v * v - sqrt(discriminant)) / (g * dx))
