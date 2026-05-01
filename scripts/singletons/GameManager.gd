extends Node

const LEVEL_ID_MENU: int = -1
const LEVEL_ID_INTRO: int = -2
const LEVEL_ID_OUTRO: int = -3

var global_scenes: Array[PackedScene] = [
	preload("res://scenes/performance_monitor.tscn"),
	preload("res://scenes/music_manager.tscn"),
]

var transition: PackedScene = preload("res://scenes/levels/transition.tscn")
var menu: PackedScene = preload("res://scenes/levels/menu.tscn")
var intro: PackedScene = preload("res://scenes/levels/intro.tscn")
var outro: PackedScene = preload("res://scenes/levels/outro.tscn")

var levels: Array[PackedScene] = [
	preload("res://scenes/testing/test_environment.tscn"),
	preload("res://scenes/testing/navmesh-testing.tscn"),
	preload("res://scenes/testing/tile_test.tscn"),
]

signal on_rebake()

var current_scene: Node = null
var current_level_id: int = LEVEL_ID_MENU
var _transition_instance: Node = null


func _ready() -> void:
	for scene in global_scenes:
		var new_scene = scene.instantiate()
		get_tree().root.add_child.call_deferred(new_scene)
	current_scene = get_tree().current_scene


func load_intro():
	load_level(LEVEL_ID_INTRO)


func load_level(level: int) -> void:
	current_level_id = level
	var level_to_load: PackedScene
	
	if current_level_id == LEVEL_ID_MENU:
		level_to_load = menu
	elif current_level_id == LEVEL_ID_INTRO:
		level_to_load = intro
	elif current_level_id == LEVEL_ID_OUTRO:
		level_to_load = outro
	elif current_level_id >= 0 and current_level_id < levels.size():
		level_to_load = levels[current_level_id]
	else:
		return

	_abort_transition()

	_transition_instance = transition.instantiate()
	get_tree().root.add_child(_transition_instance)
	_transition_instance.on_fade_in_finished.connect(
		_on_fade_in_finished.bind(level_to_load), CONNECT_ONE_SHOT
	)
	_transition_instance.fade_in()


func reload_level():
	load_level(current_level_id)


func _abort_transition() -> void:
	if not _transition_instance:
		return

	if _transition_instance.on_fade_in_finished.is_connected(_on_fade_in_finished):
		_transition_instance.on_fade_in_finished.disconnect(_on_fade_in_finished)
	if _transition_instance.on_fade_out_finished.is_connected(_on_fade_out_finished):
		_transition_instance.on_fade_out_finished.disconnect(_on_fade_out_finished)
	_transition_instance.queue_free()
	_transition_instance = null


func _on_fade_in_finished(level_to_load: PackedScene) -> void:
	if current_scene:
		current_scene.queue_free()
	current_scene = level_to_load.instantiate()
	get_tree().root.add_child(current_scene)
	_transition_instance.on_fade_out_finished.connect(
		_on_fade_out_finished, CONNECT_ONE_SHOT
	)
	_transition_instance.fade_out()


func _on_fade_out_finished() -> void:
	_transition_instance.queue_free()
	_transition_instance = null
