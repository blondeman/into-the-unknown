class_name RoomLayout
extends RefCounted

var depth: int = 0
var size: Vector3 = Vector3.ZERO
var position: Vector3 = Vector3.ZERO    # this room's global center position
var entrance: Doorway
var exits: Array[Doorway] = []
var scale_factor: float = 1.0
var rejected: bool = false              # true if this layout couldn't be placed (unresolved overlap)
