class_name WeaponData
extends Resource

@export var use_instant := true
@export var use_timer := false
@export var timer_delay := 1.0

@export_enum("circle", "beam") var collision_type := "circle"
@export var collision_radius := 16.0
@export var initial_scale := 1.0

@export var texture: Texture2D
@export var opacity := 1.0
@export var ground_sprite := false

@export var tracking := false
@export var split_on_strike := 0
@export var velocity := 1.0
@export var lifetime := -1.0

@export var attached := false
@export var activate_on_detach := false

@export var targeting := "area_all"
@export var spawner := false

@export var damage: Resource

func runtime_copy():
	var copy = duplicate(true)
	if damage != null:
		copy.damage = damage.duplicate_damage()
	return copy
