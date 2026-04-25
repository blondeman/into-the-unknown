extends Label

@export var monitors: Array[Performance.Monitor]

func _process(_delta: float) -> void:
	text = _build_monitor_text()

func _build_monitor_text() -> String:
	var parts: Array[String] = []
	for monitor in monitors:
		var label := _monitor_label(monitor)
		var value := _monitor_value(monitor)
		parts.append("%s: %s" % [label, value])
	return " | ".join(parts)

func _monitor_value(monitor: Performance.Monitor) -> String:
	var raw := Performance.get_monitor(monitor)
	match monitor:
		Performance.TIME_FPS:
			return str(int(raw))
		Performance.MEMORY_STATIC, \
		Performance.MEMORY_STATIC_MAX:
			return "%.1f MB" % (raw / 1_048_576.0)
		Performance.RENDER_TOTAL_OBJECTS_IN_FRAME:
			return str(int(raw))
		_:
			return "%.2f" % raw

func _monitor_label(monitor: Performance.Monitor) -> String:
	match monitor:
		Performance.TIME_FPS:             return "FPS"
		Performance.TIME_PROCESS:         return "Process"
		Performance.TIME_PHYSICS_PROCESS: return "Physics"
		Performance.MEMORY_STATIC:        return "Memory Usage"
		Performance.MEMORY_STATIC_MAX:    return "Memory Peak"
		Performance.RENDER_TOTAL_OBJECTS_IN_FRAME: return "Object Count"
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME: return "Draw Calls"
		Performance.RENDER_VIDEO_MEM_USED: return "Video Mem"
		Performance.PHYSICS_2D_ACTIVE_OBJECTS: return "2D Objects"
		Performance.PHYSICS_3D_ACTIVE_OBJECTS: return "3D Objects"
		_: return "Monitor %d" % monitor
