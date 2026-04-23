class_name Destructable
extends StaticBody3D

@export var destroyed_object: PackedScene

func destroy():
	var new_destroyed_object = destroyed_object.instantiate()
	get_parent().add_child(new_destroyed_object)
	new_destroyed_object.transform = transform
	queue_free()
