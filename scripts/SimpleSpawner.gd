extends Node2D

export(PackedScene) var spawnItem
export(float) var randomness = 5.0
export(bool) var isRunning
export(NodePath) var tracking
export(NodePath) var mapSource

var timerTick = 1.0
var itemPreload
var startTime
var timer

func _ready():
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = timerTick
	add_child(timer)
	timer.connect("timeout", self, "_timeout")
	
	if tracking:
		tracking = get_node(tracking)
		
	mapSource = get_node(mapSource)
	startTime = OS.get_ticks_msec()
	
func _process(_delta):
	if is_instance_valid(tracking):
		global_position = tracking.global_position

func _timeout():
	if isRunning:
		var secs = (OS.get_ticks_msec() - startTime) / 1000.0
		var next_to_5 = 1.0 / pow(2.0, 1.0 + secs/120)
		if next_to_5 > 1.0:
			next_to_5 = 1.0
		if next_to_5 < 0.001:
			next_to_5 = 0.001
#		print(next_to_5)
		timer.wait_time = next_to_5 * 0.5
#		print(timer.wait_time)

		
		var ni = spawnItem.instance()
#		print(0.4/next_to_5)
		ni.multiplyDifficulty(0.1/next_to_5)
		var wck = mapSource.getWaterCells()
		if wck.size() > 0:
			var rpick = wck[randi() % wck.size()]
			
			ni.position.x = rpick.x + 8.0
			ni.position.y = rpick.y + 8.0
			
		# Circle spawner:
		if false:
			var crange = 400.0
			var ca = randf() * 2.0 * PI
			var cx = sin(ca) * crange
			var cy = cos(ca) * crange * 0.55
			
			ni.position.x += randf() * randomness*2 - randomness + cx + global_position.x
			ni.position.y += randf() * randomness*2 - randomness + cy + global_position.y
			
		# Add to world
		get_parent().add_child(ni)
		if tracking:
			ni.setTarget(tracking)
