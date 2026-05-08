extends Node
const LEVEL_ID_MENU: int = -1
const LEVEL_ID_INTRO: int = -2
const LEVEL_ID_OUTRO: int = -3

var global_scene_paths: Array[String] = [
	"res://scenes/performance_monitor.tscn",
	"res://scenes/music_manager.tscn",
]
var transition_path: String = "res://scenes/levels/transition.tscn"
var menu_path: String = "res://scenes/levels/menu.tscn"
var intro_path: String = "res://scenes/levels/intro.tscn"
var outro_path: String = "res://scenes/levels/outro.tscn"

var levels: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/testing/test_environment.tscn",
	"res://scenes/levels/level_3.tscn",
]

@warning_ignore("unused_signal")
signal on_rebake()
signal on_score_changed(amount: int, score: int, total: int)
signal on_max_score()

var current_scene: Node = null
var current_level_id: int = LEVEL_ID_MENU
var _transition_instance: Node = null
var is_loading: bool = false
var enemy_count: int = 0
var building_count: int = 0
var score: int = 0

func _ready() -> void:
	for path in global_scene_paths:
		var new_scene = (load(path) as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(new_scene)
	current_scene = get_tree().current_scene
	_level_loaded()

func load_intro():
	load_level(LEVEL_ID_INTRO)

func load_outro():
	load_level(LEVEL_ID_OUTRO)

func load_next_level():
	if current_level_id < levels.size():
		load_level(current_level_id + 1)
	else:
		load_outro()

func load_level(level: int) -> void:
	if is_loading:
		return

	is_loading = true
	current_level_id = level
	var level_path: String

	if current_level_id == LEVEL_ID_MENU:
		print("Loading menu")
		level_path = menu_path
	elif current_level_id == LEVEL_ID_INTRO:
		print("Loading intro")
		level_path = intro_path
	elif current_level_id == LEVEL_ID_OUTRO:
		print("Loading outro")
		level_path = outro_path
	elif current_level_id >= 0 and current_level_id < levels.size():
		print("Loading level " + str(level))
		level_path = levels[current_level_id]
	else:
		is_loading = false
		return

	_abort_transition()
	_transition_instance = (load(transition_path) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_transition_instance)
	_transition_instance.on_fade_in_finished.connect(
		_on_fade_in_finished.bind(level_path), CONNECT_ONE_SHOT
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

func _on_fade_in_finished(level_path: String) -> void:
	if current_scene:
		current_scene.queue_free()
		await current_scene.tree_exited
	current_scene = (load(level_path) as PackedScene).instantiate()
	get_tree().root.add_child(current_scene)
	_transition_instance.on_fade_out_finished.connect(
		_on_fade_out_finished, CONNECT_ONE_SHOT
	)
	_transition_instance.fade_out()
	_level_loaded()

func _on_fade_out_finished() -> void:
	_transition_instance.queue_free()
	_transition_instance = null

func _level_loaded():
	score = 0
	building_count = 0
	enemy_count = 0
	is_loading = false
	await get_tree().process_frame
	_set_score_total()

func _set_score_total():
	enemy_count = get_tree().get_nodes_in_group("enemy").size()
	building_count = get_tree().get_nodes_in_group("destructible").size()
	on_score_changed.emit(0, score, _max_score())

func add_score():
	if is_loading or _max_score() == 0:
		return
	score += 1
	on_score_changed.emit(1, score, _max_score())
	if score >= _max_score():
		on_max_score.emit()
		load_next_level()

func _max_score() -> int:
	return building_count + enemy_count
