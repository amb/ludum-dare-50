extends Area2D

export(NodePath) var target

func _ready():
	target = get_node(target)

func _process(delta):
	if is_instance_valid(target):
		global_position = target.global_position
