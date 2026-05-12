extends Camera2D

@export var trackTarget = null
func _ready():
	trackTarget = get_node(trackTarget)

func _process(delta):
	if is_instance_valid(trackTarget):
		global_position = trackTarget.global_position
