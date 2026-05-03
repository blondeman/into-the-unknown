@tool
extends Attack

@onready var anim_player = $"../Mesh/AnimationPlayer"

func _ready():
	print(anim_player.get_animation_list())

func _attack(target: Node3D):
	if anim_player.current_animation != "RedTeam_SwordsMen_Armature|Atack_SwordsMen":
		anim_player.play("RedTeam_SwordsMen_Armature|Atack_SwordsMen")
	deal_damage(target)
