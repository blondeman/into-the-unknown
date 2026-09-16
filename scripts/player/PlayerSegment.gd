class_name PlayerSegment
extends AnimatableBody3D

@export var target: Node3D
@export var follow_distance: float

var _saved_position: Vector3
var _vertical_velocity: float = 0.0

func _ready() -> void:
	_saved_position = global_position


func _process(delta: float) -> void:
	if target == null:
		return
	_apply_gravity(delta)
	_follow(target.global_position)


func _apply_gravity(delta: float) -> void:
	_vertical_velocity += ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	global_position.y -= _vertical_velocity * delta


func _follow(target_position: Vector3) -> void:
	var diff := global_position - target_position

	if diff.length() > follow_distance:
		_saved_position = target_position + diff.normalized() * follow_distance
	else:
		_saved_position = global_position

	global_position = _saved_position
	_depenetrate()
	_safe_look_at(target_position)


func _depenetrate() -> void:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = global_transform
	params.motion = Vector3.ZERO
	params.recovery_as_collision = true

	var result := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		var push := result.get_travel()
		if push.length_squared() > 0.0:
			global_position += push
			_saved_position = global_position
			if push.y > 0.001:
				_vertical_velocity = 0.0  # landed on something


func _safe_look_at(target_position: Vector3) -> void:
	var direction = (target_position - global_position).normalized()

	if direction.length() < 0.001:
		return  # target is too close or identical position

	var up = Vector3.UP
	if abs(direction.dot(up)) > 0.999:
		up = Vector3.FORWARD

	look_at(target_position, up)


func take_damage():
	#blink red
	pass
