extends Node3D

@export var seed_edit: TextEdit
var use_random_seed: bool = false
var last_seed_value: int = 0

@export var depth_edit: TextEdit
@export var room_bound_check: CheckBox
@export var room_path_check: CheckBox

@export var room_scene: PackedScene
var rooms: Array[Room]

func _ready():
	generate_maze()


var rng: RandomNumberGenerator

func generate_maze():
	clear_rooms()

	var _seed_text: String = seed_edit.text

	if _seed_text.is_empty() or (use_random_seed and _seed_text.to_int() == last_seed_value):
		rng = RandomNumberGenerator.new()
		rng.randomize()
		use_random_seed = true
		last_seed_value = rng.seed
		seed_edit.text = str(rng.seed)
	else:
		use_random_seed = false
		rng = RandomNumberGenerator.new()
		rng.seed = hash(_seed_text)
		last_seed_value = rng.seed

	var exits = generate_room()
	var _depth = depth_edit.text.to_int()

	for i in _depth:
		var new_exits: Array[Doorway]
		for exit in exits:
			new_exits.append_array(generate_room(exit))
		exits = new_exits
	
	_on_room_bound_toggled(room_bound_check.button_pressed)
	_on_room_path_toggled(room_path_check.button_pressed)


func generate_room(entrance: Doorway = Doorway.new()) -> Array[Doorway]:
	var new_room: Room = room_scene.instantiate()
	new_room.set_rng(rng)
	add_child(new_room)
	var exits: Array[Doorway] = new_room.generate_room(entrance)
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


func _on_room_bound_toggled(toggled_on: bool) -> void:
	for room in rooms:
		room.debug_room_bound.visible = toggled_on
		room.debug_room_entrance.visible = toggled_on


func _on_room_path_toggled(toggled_on: bool) -> void:
	for room in rooms:
		room.room_path._debug_mesh_instance.visible = toggled_on
