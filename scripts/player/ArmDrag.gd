extends Node3D
class_name ArmDrag

@export var initial_target: Node3D
@export var max_distance: float = 4
@export var step_sound: AudioStreamPlayer3D
@export var step_sounds: Array[AudioStream]

var _pinned_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_pinned_position = get_floor_position()

func _process(delta: float) -> void:
	var distance_to_target = global_position.distance_to(initial_target.global_position)
	
	if distance_to_target < max_distance:
		global_position = _pinned_position
	else:
		global_position = initial_target.global_position
		_pinned_position = get_floor_position()
		if step_sound:
			step_sound.stream = step_sounds[randi() % step_sounds.size()]
			step_sound.play()

func get_floor_position() -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = Vector3(global_position.x, initial_target.global_position.y + 1.0, global_position.z)
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + Vector3.DOWN * 1.5
	)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position

	return global_position
