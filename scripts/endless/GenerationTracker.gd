class_name GenerationTracker
extends Node3D

@export var generator: EndlessGenerator
@export var target: Node3D

## How many rooms away (by connectivity, not raw generation order) from the player's current
## room should have a built, visible mesh. Rooms farther than this get their mesh torn down
## via hide_mesh() - the room itself (bounds/exits/path) stays loaded either way.
@export var mesh_depth: int = 2

## How many rooms away should exist structurally (bounds, exits, path generated - no mesh)
## so other systems generating ahead of the player already know what's coming. Should be
## >= mesh_depth, or there'd be nothing structural to reveal the mesh of once in range.
@export var structure_depth: int = 5

var current_room: Room = null


func _ready() -> void:
	if target is PlayerController:
		target = (target as PlayerController).head


func get_current_room() -> Room:
	for room in generator.rooms:
		if room.is_in_bounds(target.global_position):
			return room
	return null


# Breadth-first search over Room.connected_rooms, returning {room: distance_in_rooms} for every
# room reachable within max_depth steps of start (start itself included at distance 0).
func get_rooms_within_depth(start: Room, max_depth: int) -> Dictionary:
	var visited: Dictionary = {start: 0}
	var queue: Array[Room] = [start]
	var head: int = 0
	while head < queue.size():
		var room: Room = queue[head]
		head += 1
		var d: int = visited[room]
		if d >= max_depth:
			continue
		for neighbor in room.connected_rooms:
			if not visited.has(neighbor):
				visited[neighbor] = d + 1
				queue.append(neighbor)
	return visited


func _process(_delta: float) -> void:
	var _current_room: Room = get_current_room()
	if _current_room == current_room:
		return
	current_room = _current_room
	if !current_room:
		return

	# make sure the maze exists this far ahead structurally, without building mesh for any of it
	generator.branch_room(current_room, structure_depth, false)

	# of whatever now exists, figure out which rooms are close enough to actually show
	var rooms_in_range: Dictionary = get_rooms_within_depth(current_room, mesh_depth)

	for room in rooms_in_range.keys():
		room.show_mesh()

	for room in generator.rooms:
		if room.has_mesh and not rooms_in_range.has(room):
			room.hide_mesh()
