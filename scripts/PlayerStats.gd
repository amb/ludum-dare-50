class_name PlayerStats
extends Resource

@export var health := 20.0
@export var maxHealth := 20.0
@export var experience := 0.0
@export var level := 1
@export var levelCap := 10
@export var movementSpeed := 0.5

func runtime_copy():
	return duplicate(true)
