extends CharacterBody3D

@export var player_controller: PlayerController
@export var audio_stream_player: AudioStreamPlayer3D
@export var fade_speed = 0.1

@export var particles: CPUParticles3D

var _target_volume: float = 0.0
var _set_volume: float
var _dashing: bool = false

func _ready() -> void:
	if audio_stream_player:
		if !audio_stream_player.playing:
			_target_volume = 0.0
			_set_volume = audio_stream_player.volume_linear
			
			audio_stream_player.volume_linear = 0.0
			audio_stream_player.play()

func _physics_process(delta: float) -> void:
	var speed = player_controller.speed if not _dashing else player_controller.dash_speed
	var rotation_speed = player_controller.rotation_speed if not _dashing else player_controller.dash_rotation_speed
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var keyboard_angle = _process_keyboard_controls()
	var mouse_angle = _process_mouse_controls()
	
	var target_angle = mouse_angle if mouse_angle != null else keyboard_angle
	var is_moving = target_angle != null
	
	if is_moving:
		global_rotation.y = lerp_angle(global_rotation.y, target_angle, rotation_speed * delta)
		var forward = -Vector3(sin(global_rotation.y), 0, cos(global_rotation.y))
		velocity.x = forward.x * speed
		velocity.z = forward.z * speed
		particles.emitting = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		particles.emitting = false
	
	move_and_slide()


func _process(delta: float) -> void:
	if audio_stream_player:
		if Vector2(velocity.x, velocity.z).length() > 0.01:
			_target_volume = 1.0
		else:
			_target_volume = 0.0
		audio_stream_player.volume_linear = move_toward(audio_stream_player.volume_linear, _target_volume, fade_speed * delta)
	
	if Input.is_action_pressed("dash"):
		_dashing = true
	else:
		_dashing = false


func _process_keyboard_controls() -> Variant:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var cam_y_rotation = player_controller.camera.global_rotation.y
	var direction = Vector3(
		input_dir.x * cos(cam_y_rotation) + input_dir.y * sin(cam_y_rotation),
		0,
		-input_dir.x * sin(cam_y_rotation) + input_dir.y * cos(cam_y_rotation))
	direction = direction.normalized()
	
	if direction.length() > 0.1:
		return atan2(-direction.x, -direction.z)
	
	return null

func _process_mouse_controls() -> Variant:
	if not Input.is_action_pressed("mouse_move"):
		return null
	
	var mouse_world_pos = _get_mouse_world_position()
	if mouse_world_pos == null:
		return null
	
	var aim_dir = (mouse_world_pos - global_position)
	aim_dir.y = 0
	if aim_dir.length() > 0.1:
		return atan2(-aim_dir.x, -aim_dir.z)
	
	return null


func _get_mouse_world_position() -> Variant:
	var camera = player_controller.camera
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	if abs(ray_dir.y) < 0.001:
		return null
	var t = (global_position.y - ray_origin.y) / ray_dir.y
	if t < 0:
		return null
	return ray_origin + ray_dir * t
