@tool
@abstract
class_name Attack
extends Node

@export var damage: int = 5
@export var attack_rate: float = 1.0
@export var range: float = 1.0

@export var attack_sounds: Array[AudioStream]

var cooldown: float = 0.0
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


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	cooldown -= delta
	if cooldown <= 0.0:
		_on_attack()

func _on_attack():
	if !enemy_controller.target:
		return
	
	if enemy_controller.target is PlayerController:
		var segments: Array[Node3D] = enemy_controller.target.get_head_and_segments()
		var closest_segment = get_closest_segment(segments)
		if closest_segment == null:
			return
		if enemy_controller.global_position.distance_to(closest_segment.global_position) < range:
			_attack(closest_segment)
			_play_sound()
			cooldown = attack_rate


@abstract func _attack(target: Node3D)


func _play_sound():
	var player = AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = attack_sounds[randi() % attack_sounds.size()]
	player.play()
	player.finished.connect(player.queue_free)

## target should be a collider of player
## it will check its sibilings for the health node
func deal_damage(target: Node3D):
	for child in target.get_parent().get_children():
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
