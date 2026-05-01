extends Control

@export_file("*.txt") var text_path: String
@export var label: RichTextLabel
@export var level_to_load: int = 0

var _lines: PackedStringArray = []
var _current_line: int = 0

var _is_typing: bool = false
var _tween: Tween

var _finished: bool = false

func _ready() -> void:
	_load_text()
	_display_text()


func _load_text() -> void:
	if text_path:
		var file := FileAccess.open(text_path, FileAccess.READ)
		if file:
			_lines = file.get_as_text().split("\n")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if _is_typing:
			_tween.kill()
			label.visible_characters = -1
			_is_typing = false
		else:
			_current_line += 1
			_display_text()

func _display_text() -> void:
	if _current_line >= _lines.size() or _lines[_current_line].is_empty():
		_text_finished()
		return
	
	label.text = _lines[_current_line]
	label.visible_characters = 0
	_is_typing = true
	
	_tween = create_tween()
	_tween.tween_property(
		label,
		"visible_characters",
		len(_lines[_current_line]),  # target
		len(_lines[_current_line]) * 0.05  # 0.05s per character
	)
	_tween.tween_callback(func(): _is_typing = false)

func _text_finished() -> void:
	if !_finished:
		_finished = true
		GameManager.load_level(level_to_load)
