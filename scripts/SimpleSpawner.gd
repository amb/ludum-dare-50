extends Node2D

export(PackedScene) var spawnItem
export(float) var timerTick
export(float) var randomness = 5.0
export(bool) var isRunning
export(NodePath) var tracking

var itemPreload
var timer

func _ready():
	timer = Timer.new()
	timer.autostart = true
	# Add randomness to avoid race conditions
	timer.wait_time = timerTick + randf() * 0.1
	add_child(timer)
	timer.connect("timeout", self, "_timeout")
	
	if tracking:
		tracking = get_node(tracking)
	
func _process(_delta):
	if is_instance_valid(tracking):
		global_position = tracking.global_position

func _timeout():
	if isRunning:
		var ni = spawnItem.instance()
		
		var crange = 400.0
		var ca = randf() * 2.0 * PI
		var cx = sin(ca) * crange
		var cy = cos(ca) * crange * 0.55
		
		ni.position.x += randf() * randomness*2 - randomness + cx + global_position.x
		ni.position.y += randf() * randomness*2 - randomness + cy + global_position.y
		get_parent().add_child(ni)
		
		if tracking:
			ni.setTarget(tracking)
