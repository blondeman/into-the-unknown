extends Node

var global_scenes: Array[PackedScene] = [
	preload("res://scenes/performance_monitor.tscn"),
	preload("res://scenes/music_manager.tscn"),
]


var transition: PackedScene = preload("res://scenes/levels/transition.tscn")
var menu: PackedScene = preload("res://scenes/levels/menu.tscn")
var levels: Array[PackedScene] = [
	preload("res://scenes/testing/test_environment.tscn"),
	preload("res://scenes/testing/navmesh-testing.tscn"),
	preload("res://scenes/testing/tile_test.tscn"),
]

signal on_rebake()

var _current_scene: Node = null
var _transition_instance: Node = null

func _ready() -> void:
	for scene in global_scenes:
		var new_scene = scene.instantiate()
		get_tree().root.add_child.call_deferred(new_scene)
	
	_current_scene = get_tree().current_scene


func load_level(level: int) -> void:
	var level_to_load: PackedScene

	if level == -1:
		level_to_load = menu
	elif level >= 0 and level < levels.size():
		level_to_load = levels[level]
	else:
		return

	# Spawn transition and fade in
	_transition_instance = transition.instantiate()
	get_tree().root.add_child(_transition_instance)

	_transition_instance.on_fade_in_finished.connect(
		_on_fade_in_finished.bind(level_to_load), CONNECT_ONE_SHOT
	)
	_transition_instance.fade_in()


func _on_fade_in_finished(level_to_load: PackedScene) -> void:
	# Swap the scene
	if _current_scene:
		_current_scene.queue_free()

	_current_scene = level_to_load.instantiate()
	get_tree().root.add_child(_current_scene)

	_transition_instance.on_fade_out_finished.connect(
		_on_fade_out_finished, CONNECT_ONE_SHOT
	)
	_transition_instance.fade_out()


func _on_fade_out_finished() -> void:
	_transition_instance.queue_free()
	_transition_instance = null
