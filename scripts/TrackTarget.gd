extends Camera2D

@export var track_target_path: NodePath
var trackTarget: Node2D

func _ready():
	trackTarget = get_node(track_target_path) as Node2D

func _process(delta):
	if is_instance_valid(trackTarget):
		global_position = trackTarget.global_position
