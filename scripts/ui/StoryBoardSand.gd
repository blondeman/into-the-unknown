extends Control

@export_file("*.txt") var text_path: String
@export var label: RichTextLabel
@export var level_to_load: int = 0
@export var audio_stream_player: AudioStreamPlayer
@export var sand: ColorRect
@export var duration := 2.5

var _lines: PackedStringArray = []
var _current_line: int = 0
var _is_typing: bool = false
var _tween: Tween
var _finished: bool = false

func _ready() -> void:
	sand.material = sand.material.duplicate()
	_update_sand_size()
	sand.resized.connect(_update_sand_size)

	_load_text()
	_display_text()

func _update_sand_size() -> void:
	sand.material.set_shader_parameter("rect_size", sand.size)

func _load_text() -> void:
	if text_path:
		var file := FileAccess.open(text_path, FileAccess.READ)
		if file:
			_lines = file.get_as_text().replace("\r", "").split("\n")

func _unhandled_key_input(event: InputEvent) -> void:
	if _finished or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if _is_typing:
		_tween.kill()
		_is_typing = false

		var progress: float = sand.material.get_shader_parameter("progress")
		if progress >= 0.8:
			_current_line += 1
			_display_text()
		else:
			_set_progress(1.0)
	else:
		_current_line += 1
		_display_text()

func _display_text() -> void:
	if _current_line >= _lines.size() or _lines[_current_line].is_empty():
		_text_finished()
		return

	audio_stream_player.play()
	label.text = _lines[_current_line]

	_set_progress(0.0)
	sand.material.set_shader_parameter("seed", randf_range(0.0, 100.0))
	sand.material.set_shader_parameter("wind", Vector2(1.0, randf_range(-0.5, 0.5)))
	sand.show()
	_is_typing = true

	_tween = create_tween()
	_tween.tween_property(sand.material, "shader_parameter/progress", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func(): _is_typing = false)

func _set_progress(value: float) -> void:
	sand.material.set_shader_parameter("progress", value)

func _text_finished() -> void:
	if not _finished:
		_finished = true
		sand.hide()
		GameManager.load_level(level_to_load)
