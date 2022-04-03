extends Panel

func _ready():
	pass
	
func activate():
	get_tree().paused = true
	visible = true
