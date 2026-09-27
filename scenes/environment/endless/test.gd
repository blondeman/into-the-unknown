extends Node3D

@export var ramp: MeshInstance3D
@export var target: Node3D  # the player

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam.is_position_behind(target.global_position):
		return  # don't update while the target is behind the camera itself
	var screen_pos := cam.unproject_position(target.global_position)
	var mat := ramp.get_surface_override_material(0) as ShaderMaterial
	mat.set_shader_parameter("CircleCentre", screen_pos)
