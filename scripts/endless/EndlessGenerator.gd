class_name EndlessGenerator
extends Node3D

@export var global_scale: float = 1.0

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


func generate_maze():
	clear_rooms()

	if seed == "":
		random_seed()
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(seed)

	branch_room(generate_room())


func generate_room(entrance: Doorway = Doorway.new(), depth: int = 0) -> Room:
	var new_room: Room = room_scene.instantiate()
	new_room.set_rng(rng)
	new_room.set_scale_factor(global_scale)
	add_child(new_room)
	new_room.generate_room(entrance, depth)
	
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


func branch_room(room: Room):
	if !room:
		return
	
	for exit in room.exits:
		var new_entrance: Doorway = Doorway.new(room.get_doorway_local_to_global(exit.position), exit.direction * -1)
		var room_id = rooms.find_custom(func(r): return r.get_doorway_local_to_global(r.entrance.position) == new_entrance.position)
		if room_id == -1:
			generate_room(new_entrance, room.depth + 1)
		else:
			print("room already exists")
