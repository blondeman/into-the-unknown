class_name EndlessGenerator
extends Node3D

@export var global_scale: float = 1.0

@export var seed: String

@export var room_scene: PackedScene
@export var direction_bias_curve: Curve
@export var exit_count_curve: Curve

var rooms: Array[Room]
var room_planner: RoomPlanner

var _room_by_key: Dictionary = {}   # RoomGen.quantize(entrance position) -> Room


func _ready():
	generate_maze()


func random_seed():
	var r := RandomNumberGenerator.new()
	r.randomize()
	seed = str(r.seed)


func generate_maze():
	clear_rooms()

	if seed == "":
		random_seed()

	room_planner = RoomPlanner.new()
	room_planner.base_seed = seed
	room_planner.scale_factor = global_scale
	room_planner.direction_bias_curve = direction_bias_curve
	room_planner.exit_count_curve = exit_count_curve

	branch_room(generate_room())


# Decides this room's full layout (deterministically, purely from its entrance position) before
# ever creating a Node — overlap/rejection is resolved entirely from data via room_planner. Only
# once a layout is accepted does an actual Room get instantiated.
func generate_room(entrance: Doorway = Doorway.new(), depth: int = 0, previous_room: Room = null, build_mesh: bool = true) -> Room:
	var layout: RoomLayout = room_planner.get_or_compute_layout(entrance, depth)
	if layout.rejected:
		return null

	var new_room: Room = room_scene.instantiate()
	add_child(new_room)
	new_room.previous_room = previous_room
	new_room.apply_layout(layout, seed, build_mesh)

	if previous_room:
		if not previous_room.connected_rooms.has(new_room):
			previous_room.connected_rooms.append(new_room)
		if not new_room.connected_rooms.has(previous_room):
			new_room.connected_rooms.append(previous_room)

	_room_by_key[RoomGen.quantize(entrance.position)] = new_room
	rooms.append(new_room)
	return new_room


func clear_rooms():
	for room in rooms:
		room.queue_free()
	rooms.clear()
	_room_by_key.clear()
	if room_planner:
		room_planner.clear()


# build_mesh controls whether newly generated rooms along this branch get a visible mesh.
# Rooms that already exist are left exactly as they are (mesh or no mesh) - this function only
# ever builds structure for rooms that don't exist yet. Use GenerationTracker's show_mesh()/
# hide_mesh() sweep to manage mesh visibility on already-existing rooms as the player moves.
func branch_room(room: Room, iterations: int = 1, build_mesh: bool = true):
	if !room:
		return
	if iterations <= 0:
		return

	var failed_exits: Array[Doorway] = []

	for exit in room.exits:
		var new_entrance: Doorway = Doorway.new(room.get_doorway_local_to_global(exit.position), exit.direction * -1)
		var key: Vector3 = RoomGen.quantize(new_entrance.position)

		if _room_by_key.has(key):
			# room already exists via a different path - still link connectivity so distance
			# searches (e.g. GenerationTracker's BFS) see the loop
			var existing_room: Room = _room_by_key[key]
			if not room.connected_rooms.has(existing_room):
				room.connected_rooms.append(existing_room)
			if not existing_room.connected_rooms.has(room):
				existing_room.connected_rooms.append(room)
			continue

		var new_room: Room = generate_room(new_entrance, room.depth + 1, room, build_mesh)
		if not new_room:
			failed_exits.append(exit)
		elif iterations > 1:
			branch_room(new_room, iterations - 1, build_mesh)

	for exit in failed_exits:
		room.remove_exit(exit)
