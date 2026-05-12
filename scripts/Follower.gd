extends Area2D

@export var target_path: NodePath
var target: Node2D

func _ready():
	target = get_node(target_path) as Node2D

func _process(delta):
	if is_instance_valid(target):
		global_position = target.global_position
