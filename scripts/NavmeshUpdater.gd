extends NavigationRegion3D

var is_baking: bool = false

func _ready() -> void:
	GameManager.on_rebake.connect(_on_rebake_requested)

func _on_rebake_requested():
	call_deferred("rebake")

func rebake():
	if is_baking:
		print("Already baking, skipping.")
		return
		
	is_baking = true
	print("Starting navigation mesh bake...")
	
	# Pass 'false' temporarily. If there's an error in your geometry/mesh, 
	# single-threaded mode will print it to the console instead of hanging.
	bake_navigation_mesh(true) 
	
	await bake_finished
	is_baking = false
	print("Navigation mesh bake finished successfully!")
