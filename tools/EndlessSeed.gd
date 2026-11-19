extends Label

var seed: String = ""

func _ready() -> void:
	visible = false
	GameManager.on_level_loaded.connect(_level_changed)


func _level_changed(level_id: int):
	var endless_generator: EndlessGenerator = get_tree().get_first_node_in_group("endless_generator")
	if endless_generator != null:
		visible = true
		_seed_changed(endless_generator.seed)
		endless_generator.on_seed_changed.connect(_seed_changed)
	else:
		visible = false


func _seed_changed(_seed: String):
	seed = _seed
	text = "Seed: " + seed


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		DisplayServer.clipboard_set(seed)
