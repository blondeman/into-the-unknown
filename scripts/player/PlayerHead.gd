extends CharacterBody3D

@export var player_controller: PlayerController
@export var audio_stream_player: AudioStreamPlayer3D
@export var fade_speed = 0.1

var _target_volume: float = 0.0
var _set_volume: float

func _ready() -> void:
	if audio_stream_player:
		if !audio_stream_player.playing:
			_target_volume = 0.0
			_set_volume = audio_stream_player.volume_linear
			
			audio_stream_player.volume_linear = 0.0
			audio_stream_player.play()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var cam_y_rotation = player_controller.camera.global_rotation.y
	var direction = Vector3(
		input_dir.x * cos(cam_y_rotation) + input_dir.y * sin(cam_y_rotation),
		0,
		-input_dir.x * sin(cam_y_rotation) + input_dir.y * cos(cam_y_rotation))
	direction = direction.normalized()

	if direction.length() > 0.1:
		var target_angle = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, player_controller.rotation_speed * delta)

	var forward = -Vector3(sin(rotation.y), 0, cos(rotation.y))
	if direction.length() > 0.1:
		velocity.x = forward.x * player_controller.speed
		velocity.z = forward.z * player_controller.speed
	else:
		velocity.x = move_toward(velocity.x, 0, player_controller.speed)
		velocity.z = move_toward(velocity.z, 0, player_controller.speed)

	move_and_slide()


func _process(delta: float) -> void:
	if audio_stream_player:
		if Vector2(velocity.x, velocity.z).length() > 0.01:
			_target_volume = 1.0
		else:
			_target_volume = 0.0
		audio_stream_player.volume_linear = move_toward(audio_stream_player.volume_linear, _target_volume, fade_speed * delta)
