class_name Inventory
extends Node

const POWERUP_RESOURCE_PATH: String = "res://resources/inventory/powerups/"
var powerup_resources: Array[PowerupData]

var items: Array[ItemData]
var powerups: Array[PowerupData]


func _ready() -> void:
	_load_powerups()


func _load_powerups():
	for file_name in DirAccess.get_files_at(POWERUP_RESOURCE_PATH):
		if (file_name.get_extension() == "tres"):
			var resource = ResourceLoader.load(POWERUP_RESOURCE_PATH+file_name)
			if resource is PowerupData:
				powerup_resources.append(resource)


func add_item(item: ItemData):
	items.append(item)
	try_craft()


func try_craft():
	for powerup_resource in powerup_resources:
		if powerup_resource.has_components(items):
			powerups.append(powerup_resource)
			for item in powerup_resource.components:
				var item_index = items.find(item)
				items.remove_at(item_index)
