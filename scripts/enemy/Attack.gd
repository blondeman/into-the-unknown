@tool
extends Node

@export var damage: int = 5
@export var range: float = 1.0
@export var attack_rate: float = 1.0

var enemy_controller: EnemyController

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not get_parent() is EnemyController:
		warnings.append("This node must be a child of EnemyController")
	return warnings

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	enemy_controller = get_parent()


var cooldown: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	cooldown -= delta
	if cooldown <= 0.0:
		_attack()

func _attack():
	if !enemy_controller.target:
		return
	
	if enemy_controller.target is PlayerController:
		var segments: Array[Node3D] = enemy_controller.target.get_head_and_segments()
		var closest_segment = get_closest_segment(segments)
		if closest_segment == null:
			return
		if enemy_controller.global_position.distance_to(closest_segment.global_position) < range:
			deal_damage(enemy_controller.target)
			cooldown = attack_rate


func deal_damage(target: Node3D):
	for child in target.get_children():
		if child is Health:
			child.take_damage(damage)
			break


func get_closest_segment(segments: Array[Node3D]) -> Node3D:
	if segments.is_empty():
		return null
	var min_distance: float = enemy_controller.global_position.distance_to(segments[0].global_position)
	var min_index: int = 0
	for i in range(1, segments.size()):
		var distance: float = enemy_controller.global_position.distance_to(segments[i].global_position)
		if distance < min_distance:
			min_distance = distance
			min_index = i
	return segments[min_index]
