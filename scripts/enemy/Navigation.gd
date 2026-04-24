## tenative script for a navmesh enemy that just moves towards the head
## please tell me if there's a nicer way to do this lol

extends CharacterBody3D

@export var speed := 3.5
@export var gravity := 9.8
@onready var nav_agent := $NavigationAgent3D

## based on current player structure, we look for the head of the player node
@export var target: Node3D

func _ready() -> void:
	await get_tree().physics_frame
	var timer := Timer.new()
	add_child(timer)
	timer.wait_time = 0.2
	## wait some amt. of time to update instead of each frame (can be changed)
	timer.timeout.connect(_update_path)
	timer.start()

func _update_path() -> void:
	## find the pos of player head and set as new target pos
	nav_agent.target_position = target.head.global_position
	print("Updated target to: ", target.head.global_position)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if nav_agent.is_navigation_finished():
		move_and_slide()
		return

	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = (next_pos - global_position).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
