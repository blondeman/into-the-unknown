extends Node

var performance_monitor: PackedScene = preload("res://scenes/performance_monitor.tscn")

signal on_rebake()

func _ready() -> void:
	var instance = performance_monitor.instantiate()
	get_tree().root.add_child.call_deferred(instance)
