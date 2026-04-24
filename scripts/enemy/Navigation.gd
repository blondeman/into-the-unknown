extends NavigationAgent3D

@export var enemy_controller: EnemyController

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	
	var timer := Timer.new()
	add_child(timer)
	timer.wait_time = 0.2
	timer.timeout.connect(_update_path)
	timer.start()


func _update_path() -> void:
	if !enemy_controller.target:
		return
	
	if enemy_controller.target is PlayerController:
		target_position = enemy_controller.target.head.global_position
	else:
		target_position = enemy_controller.target.global_position


func _process(delta: float) -> void:
	if is_navigation_finished():
		enemy_controller.set_direction(Vector2.ZERO)
		return

	var next_pos: Vector3 = get_next_path_position()
	var direction: Vector3 = (next_pos - enemy_controller.global_position)
	enemy_controller.set_direction(Vector2(direction.x, direction.z).normalized())
