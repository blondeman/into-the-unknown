extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3.ZERO
var shake_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	CameraEffects.on_shake.connect(shake)
	
	if offset != Vector3.ZERO:
		return
	
	if !target:
		offset = global_position
	elif target is PlayerController:
		offset = global_position - target.head.global_position
	else:
		offset = global_position - target.global_position


func _process(_delta: float) -> void:
	if !target:
		return
	
	if target is PlayerController:
		global_position = target.head.global_position + offset + shake_offset
	else:
		global_position = target.global_position + offset + shake_offset


func shake(intensity: float, length: float):
	var elapsed := 0.0

	while elapsed < length:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / length, 0.0, 1.0)
		var damped := intensity * (1.0 - t)

		shake_offset = Vector3(
			randf_range(-damped, damped),
			randf_range(-damped, damped),
			0.0
		)
		await get_tree().process_frame

	shake_offset = Vector3.ZERO
