extends Node3D

@export var depth: float = 0.2
@export var period: float = 1

var _start_y: float
var _time: float = 0.0

func _ready():
	_start_y = position.y

func _process(delta: float) -> void:
	_time += delta
	position.y = _start_y + sin(_time * TAU / period) * depth
