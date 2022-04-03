extends Area2D

export(NodePath) var target

func _ready():
	target = get_node(target)

func _process(delta):
	global_position = target.global_position
