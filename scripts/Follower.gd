extends Area2D

@export var target: NodePath

func _ready():
	target = get_node(target)

func _process(delta):
	if is_instance_valid(target):
		global_position = target.global_position
