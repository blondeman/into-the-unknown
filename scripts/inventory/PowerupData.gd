class_name PowerupData
extends Resource

@export var name: String
@export var components: Array[ItemData]

func has_components(items: Array[ItemData]) -> bool:
	var available := {}
	for item in items:
		available[item] = available.get(item, 0) + 1

	for component in components:
		if available.get(component, 0) <= 0:
			return false
		available[component] -= 1

	return true
