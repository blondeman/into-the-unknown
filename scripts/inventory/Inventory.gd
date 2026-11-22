class_name Inventory
extends Node

const POWERUP_RESOURCE_PATH: String = "res://resources/inventory/powerups/"
var powerup_resources: Array[PowerupData]

var items: Array[ItemData]
var powerups: Array[PowerupData]

signal on_inventory_changed(inventory: Inventory)

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
	on_inventory_changed.emit(self)


func try_craft():
	for powerup_resource in powerup_resources:
		if powerup_resource.has_components(items):
			powerups.append(powerup_resource)
			for item in powerup_resource.components:
				var item_index = items.find(item)
				items.remove_at(item_index)


func get_item_counts() -> Dictionary:
	var unique_items = {}
	for item in items:
		if unique_items.has(item):
			unique_items[item] += 1
		else:
			unique_items[item] = 1
	return unique_items


func get_powerup_counts() -> Dictionary:
	var unique_powerups = {}
	for powerup in powerups:
		if unique_powerups.has(powerup):
			unique_powerups[powerup] += 1
		else:
			unique_powerups[powerup] = 1
	return unique_powerups
