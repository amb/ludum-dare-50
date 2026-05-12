class_name ModData
extends Resource

@export var id := ""
@export var description := ""
@export var multiply := 1.0
@export var increase := 0.0
@export var level := 0
@export var max_level := 1
@export var value := 1.0

func runtime_copy():
	return duplicate(true)

func can_level_up() -> bool:
	return level < max_level

func powerup() -> void:
	if can_level_up():
		level += 1
		value *= multiply
		value += increase
