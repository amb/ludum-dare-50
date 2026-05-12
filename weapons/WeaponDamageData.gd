class_name WeaponDamageData
extends Resource

@export var low: int = 0
@export var add: int = 0
@export var knockback: float = 0.0

func duplicate_damage():
	var copy = get_script().new()
	copy.low = low
	copy.add = add
	copy.knockback = knockback
	return copy
