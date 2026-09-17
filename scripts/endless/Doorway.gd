class_name Doorway

const cardinals: Array[Vector3i] = [Vector3i(1,0,0),Vector3i(0,0,1),Vector3i(-1,0,0),Vector3i(0,0,-1)]

@export var position: Vector3
@export var direction: Vector3i

func _init(_position := Vector3.ZERO, _direction := Vector3i(1,0,0)):
	if _direction not in cardinals:
		_direction = cardinals[0]
	position = _position
	direction = _direction
