@tool
extends NavigationAgent3D

var enemy_controller: EnemyController
@export var probability_curve: Curve

@export var follow_range: float = 50

var current_target: Node3D = null

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not get_parent() is EnemyController:
		warnings.append("This node must be a child of EnemyController")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	enemy_controller = get_parent()
	
	await get_tree().process_frame
	await get_tree().physics_frame
	
	_get_follow_target()
	
	var target_timer := Timer.new()
	add_child(target_timer)
	target_timer.wait_time = 5
	target_timer.timeout.connect(_get_follow_target)
	target_timer.start()
	
	var path_timer := Timer.new()
	add_child(path_timer)
	path_timer.wait_time = 0.2
	path_timer.timeout.connect(_update_path)
	path_timer.start()


func _update_path() -> void:
	if !current_target:
		return
	
	target_position = current_target.global_position


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_navigation_finished() or distance_to_target() > follow_range:
		enemy_controller.set_direction(Vector2.ZERO)
		return

	var next_pos: Vector3 = get_next_path_position()
	var direction: Vector3 = (next_pos - enemy_controller.global_position)
	enemy_controller.set_direction(Vector2(direction.x, direction.z).normalized())


func _get_follow_target():
	if !enemy_controller.target:
		return null
	
	if enemy_controller.target is not PlayerController:
		current_target = enemy_controller.target
	else:
		var segments: Array[Node3D] = enemy_controller.target.get_head_and_segments()
		current_target = pick_target_segment(segments)


func pick_target_segment(segments: Array[Node3D]) -> Node3D:
	if segments.is_empty():
		return null

	var weights: Array[float] = []
	var total_weight := 0.0
	var distances: Array[float] = []

	for seg in segments:
		distances.append(enemy_controller.global_position.distance_to(seg.global_position))

	var max_dist: float = distances.max()

	for d in distances:
		var t: float = d / max(max_dist, 0.001)
		var w: float = probability_curve.sample_baked(t)
		weights.append(max(w, 0.0))
		total_weight += max(w, 0.0)

	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in weights.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return segments[i]

	return segments[-1]
