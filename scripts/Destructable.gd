class_name Destructable
extends StaticBody3D

@export var destroyed_object: PackedScene

func destroy():
	CameraEffects.on_shake.emit(0.2, 0.6)
	
	var new_destroyed_object = destroyed_object.instantiate()
	get_parent().add_child(new_destroyed_object)
	new_destroyed_object.transform = transform
	queue_free()
