extends Node3D

@export var seed: TextEdit
@export var depth: TextEdit

@export var room_scene: PackedScene
var rooms: Array[Room]

func _ready():
	generate_maze()


var rng: RandomNumberGenerator

func generate_maze():
	clear_rooms()

	rng = RandomNumberGenerator.new()
	var _seed_text: String = seed.text
	if _seed_text.is_empty():
		rng.randomize()          # no seed given -> nondeterministic
	else:
		rng.seed = hash(_seed_text)   # deterministic from the string

	var exits = generate_room()
	var _depth = depth.text.to_int()

	for i in _depth:
		var new_exits: Array[Doorway]
		for exit in exits:
			new_exits.append_array(generate_room(exit))
		exits = new_exits


func generate_room(entrance: Doorway = Doorway.new()) -> Array[Doorway]:
	var new_room: Room = room_scene.instantiate()
	new_room.set_rng(rng)
	add_child(new_room)
	var exits: Array[Doorway] = new_room.generate_room_bounds(entrance)
	for room in rooms:
		var pct: float = new_room.get_overlap_percent(room)
		if pct > 0.0:
			if pct < 0.10:
				if not new_room.shrink_to_fit(room, entrance.direction):
					new_room.queue_free()
					return []
			else:
				new_room.queue_free()
				return []
	rooms.append(new_room)
	return exits


func clear_rooms():
	for room in rooms:
		room.queue_free()
	rooms.clear()
