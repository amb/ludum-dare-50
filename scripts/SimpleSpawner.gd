extends Node2D

export(PackedScene) var spawnItem
#export(float) var randomness = 5.0
export(bool) var isRunning
export(NodePath) var tracking
export(NodePath) var mapSource

var timerTick = 1.0
var itemPreload
var startTime
var timer

var pathFinder

func _ready():
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = timerTick
	add_child(timer)
	timer.connect("timeout", self, "_timeout")
	
	tracking = get_node(tracking)
		
	mapSource = get_node(mapSource)
	startTime = OS.get_ticks_msec()
	
	pathFinder = tracking.get_node("PathFinder")
	
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


#		print(0.4/next_to_5)
#		ni.multiplyDifficulty(0.1/next_to_5)
		var pos = Vector2.ZERO
		var wck = mapSource.getWaterCells()
		if wck.size() > 0:
			var rpick = wck[randi() % wck.size()]
			
			pos.x = rpick.x + 8.0
			pos.y = rpick.y + 8.0
			
		# Circle spawner:
		if false:
			var crange = 400.0
			var ca = randf() * 2.0 * PI
			var cx = sin(ca) * crange
			var cy = cos(ca) * crange * 0.55
			
			pos.x += global_position.x - cx
			pos.y += global_position.y - cy
			
		# If no path to player, don't spawn
#		if is_instance_valid(pathFinder):
#			if pathFinder.get_grid_value(pos) < 1:
#				pass
#			else:
		# Add to world
		var ni = spawnItem.instance()
		ni.global_position = pos
		get_parent().add_child(ni)
		if tracking:
			ni.setTarget(tracking)
