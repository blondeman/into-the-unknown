extends NavigationRegion3D

var is_baking: bool = false

func _ready() -> void:
	GameManager.on_rebake.connect(rebake)

func rebake():
	if is_baking:
		return
	is_baking = true
	bake_navigation_mesh(true)
	await bake_finished
	is_baking = false
