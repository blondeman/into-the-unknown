class_name GenerationTracker
extends Node3D

@export var generator: EndlessGenerator
@export var target: Node3D

## Rooms whose bounds are within this distance of the target get their mesh loaded.
@export var load_radius: float = 30.0

## Loaded rooms are only unloaded once they're farther than this. Keep it above load_radius so
## a room right at the edge doesn't load and unload every frame.
@export var unload_radius: float = 40.0


func _ready() -> void:
	if target is PlayerController:
		target = (target as PlayerController).head


func _process(_delta: float) -> void:
	if not target:
		return

	var target_pos: Vector3 = target.global_position
	var unload_dist: float = maxf(unload_radius, load_radius)

	if load_radius <= 0:
		for room in generator.rooms:
			var dist: float = room.distance_to(target_pos)
			if dist <= load_radius:
				room.load_mesh()
		return

	for room in generator.rooms:
		var dist: float = room.distance_to(target_pos)
		if dist <= load_radius:
			room.load_mesh()
		elif dist > unload_dist:
			room.unload_mesh()
