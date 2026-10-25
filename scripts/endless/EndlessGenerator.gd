class_name EndlessGenerator
extends Node3D

@export var global_scale: float = 1.0
@export var max_depth: int = 10

@export var seed: String
var rng: RandomNumberGenerator

@export var room_scene: PackedScene
var rooms: Array[Room]

func _ready():
	generate_maze()


func random_seed():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	seed = str(rng.seed)
	rng.seed = hash(seed)


## Generates the whole maze up front. No meshes are built here - GenerationTracker loads and
## unloads them later based on where the target is.
func generate_maze():
	clear_rooms()

	if seed == "":
		random_seed()
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(seed)

	# breadth-first, so sibling branches get space before any one branch runs deep
	var queue: Array[Room] = [generate_room()]
	while not queue.is_empty():
		queue.append_array(branch_room(queue.pop_front()))
	
	rooms.get(len(rooms) - 1)._generate_hole()


func generate_room(entrance: Doorway = null, depth: int = 0, previous_room: Room = null) -> Room:
	var new_room: Room = room_scene.instantiate()
	new_room.set_rng(rng)
	new_room.set_scale_factor(global_scale)
	new_room.set_max_depth(max_depth)
	add_child(new_room)
	new_room.generate(entrance, depth, previous_room)

	for room in rooms:
		var pct: float = new_room.get_overlap_percent(room)
		if pct > 0.0:
			if pct < 0.10:
				if not new_room.shrink_to_fit(room, entrance.direction):
					new_room.queue_free()
					return null
			else:
				new_room.queue_free()
				return null
	rooms.append(new_room)
	return new_room


func clear_rooms():
	for room in rooms:
		room.queue_free()
	rooms.clear()


func get_room_index_at(new_entrance: Doorway) -> int:
	return rooms.find_custom(func(r): return r.entrance and r.get_doorway_local_to_global(r.entrance.position) == new_entrance.position)


## Generates a room behind each of room's exits and returns the newly created rooms.
## Exits that can't fit a room are removed from room.
func branch_room(room: Room) -> Array[Room]:
	var new_rooms: Array[Room] = []
	var failed_exits: Array[Doorway] = []

	for exit in room.exits:
		var new_entrance: Doorway = Doorway.new(room.get_doorway_local_to_global(exit.position), exit.direction * -1)
		if get_room_index_at(new_entrance) != -1:
			continue # a room already exists at this doorway

		var new_room: Room = generate_room(new_entrance, room.depth + 1, room)
		if new_room:
			new_rooms.append(new_room)
		else:
			failed_exits.append(exit)

	for exit in failed_exits:
		room.remove_exit(exit)

	return new_rooms
