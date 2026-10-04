class_name RoomPlanner
extends RefCounted

var base_seed: String = ""
var scale_factor: float = 1.0
var direction_bias_curve: Curve
var exit_count_curve: Curve

var _layouts: Dictionary = {}       # RoomGen.quantize(entrance position) -> RoomLayout
var _accepted: Array[RoomLayout] = []  # non-rejected layouts, checked against for new overlaps


# Returns the layout for this entrance position, computing and caching it on first request.
# Every later call with the same (quantized) entrance position returns the exact same layout
# object - so it doesn't matter whether this is a real generation, a speculative lookahead
# from a far-off structure pass, or a mesh pass asking about a room that already exists.
func get_or_compute_layout(entrance: Doorway, depth: int) -> RoomLayout:
	var key: Vector3 = RoomGen.quantize(entrance.position)
	if _layouts.has(key):
		return _layouts[key]

	var layout: RoomLayout = RoomGen.compute_layout(entrance, depth, scale_factor, base_seed, direction_bias_curve, exit_count_curve)

	for other in _accepted:
		var pct: float = RoomGen.overlap_percent(layout.position, layout.size, other.position, other.size)
		if pct > 0.0:
			if pct < 0.10:
				if not RoomGen.try_shrink(layout, other.position, other.size):
					layout.rejected = true
					break
			else:
				layout.rejected = true
				break

	if not layout.rejected:
		_accepted.append(layout)

	_layouts[key] = layout
	return layout


func clear() -> void:
	_layouts.clear()
	_accepted.clear()
