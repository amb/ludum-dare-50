extends Area2D

export(NodePath) var target

var weapon

func _ready():
	target = get_node(target)
	weapon = {
		"damageLow":5,
		"damageAdd":5,
	}

func _attack_damage():
	return weapon.damageLow + randi() % weapon.damageAdd

func _process(delta):
	if is_instance_valid(target):
		global_position = target.global_position

func _on_weapon_body_entered(body):
	if body.is_in_group("enemy"):
		body.takeDamage(_attack_damage())
