extends NavigationRegion3D

func _ready() -> void:
	GameManager.on_rebake.connect(_on_rebake_requested)

func _on_rebake_requested():
	call_deferred("rebake")

func rebake():
	if is_baking():
		print("Already baking, skipping.")
		return
	
	print("Starting navigation mesh bake...")
	bake_navigation_mesh(true) 
	
	await bake_finished
	print("Navigation mesh bake finished successfully!")
