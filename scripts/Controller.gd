extends CharacterBody3D

@export var snake: Snake
var angle: float

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (snake.camera.transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	direction.y = 0
	direction = direction.normalized()

	if direction.length() > 0.1:
		var target_angle = atan2(-direction.x, -direction.z)
		angle = lerp_angle(angle, target_angle, snake.rotation_speed * delta)

	var forward = -Vector3(sin(angle), 0, cos(angle))
	if direction.length() > 0.1:
		velocity.x = forward.x * snake.speed
		velocity.z = forward.z * snake.speed
	else:
		velocity.x = move_toward(velocity.x, 0, snake.speed)
		velocity.z = move_toward(velocity.z, 0, snake.speed)

	move_and_slide()
