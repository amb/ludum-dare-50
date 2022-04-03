extends Camera2D

export(NodePath) var trackTarget

func _ready():
	trackTarget = get_node(trackTarget)

func _process(delta):
	global_position = trackTarget.global_position
