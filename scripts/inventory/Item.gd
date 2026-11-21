class_name Item
extends RigidBody3D

@export var data: ItemData

func destroy():
	queue_free()
