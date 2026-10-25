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
	find_safe_mesh(target)
	if target is PlayerController:
		target = (target as PlayerController).head


func find_safe_mesh(body: Node3D) -> void:
	body.set_physics_process(false) # so it doesn't fall while there's nothing to stand on
 
	await get_tree().process_frame # let the generator finish building its rooms
	var room: Room = generator.rooms[0]
	room.load_mesh()
	await get_tree().physics_frame
	await get_tree().physics_frame
 
	var space_state := get_world_3d().direct_space_state
	var reach: float = room.size.y
	for point in _get_spawn_points(room):
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * reach, point + Vector3.DOWN * reach, 0b01)
		var result := space_state.intersect_ray(query)
		if result:
			body.global_position = result.position + Vector3.UP * 2.0
			if body is CharacterBody3D:
				(body as CharacterBody3D).velocity = Vector3.ZERO
			body.set_physics_process(true)
			return
 
	push_warning("GenerationTracker: no collision found in the first room to spawn on")
	body.set_physics_process(true)


func _get_spawn_points(room: Room) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var cell: float = room.scale_factor
	var half: Vector3 = room.size / 2.0
 
	var x: float = -half.x + cell / 2.0
	while x < half.x:
		var z: float = -half.z + cell / 2.0
		while z < half.z:
			points.append(room.global_position + Vector3(x, 0.0, z))
			z += cell
		x += cell
 
	points.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(room.global_position) < b.distance_squared_to(room.global_position))
	return points


func _process(_delta: float) -> void:
	if not target or not generator:
		return

	var target_pos: Vector3 = target.global_position
	var unload_dist: float = maxf(unload_radius, load_radius)

	if load_radius <= 0:
		for room in generator.rooms:
			room.load_mesh()
		return

	for room in generator.rooms:
		var dist: float = room.distance_to(target_pos)
		if dist <= load_radius:
			room.load_mesh()
		elif dist > unload_dist:
			room.unload_mesh()
