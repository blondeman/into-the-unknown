class_name EnemyController
extends CharacterBody3D

@export var speed = 5.0
@export var target: Node3D
@export var mesh: Node3D
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	if !target:
		target = get_tree().get_first_node_in_group("player")

func set_direction(_direction: Vector2):
	direction = _direction

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.y * speed
		_rotate_mesh(delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func _rotate_mesh(delta: float) -> void:
	if not mesh:
		return
	var move_dir := Vector3(velocity.x, 0, velocity.z)
	if move_dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(-move_dir.normalized(), Vector3.UP)
	var from_q := mesh.global_basis.get_rotation_quaternion()
	var to_q := target_basis.get_rotation_quaternion()
	mesh.global_basis = Basis(from_q.slerp(to_q, delta * 10.0))


func _exit_tree() -> void:
	GameManager.add_score()
