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
	offset = global_position - _get_target_position()


func _process(_delta: float) -> void:
	if !target:
		return

	global_position = _get_target_position() + offset + shake_offset
	
	set_occlusion_cutout()


func set_occlusion_cutout():
	if is_position_behind(_get_target_position()):
		return
	var screen_pos := unproject_position(_get_target_position())
	
	RenderingServer.global_shader_parameter_set("cutout_position", screen_pos)


func _get_target_position() -> Vector3:
	if target is PlayerController:
		return target.head.global_position
	return target.global_position


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
