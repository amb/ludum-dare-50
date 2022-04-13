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

var debugTimer

var pathFinder

func _ready():
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = timerTick
	add_child(timer)
	timer.connect("timeout", self, "_timeout")
	
	debugTimer = Timer.new()
	debugTimer.autostart = true
	debugTimer.wait_time = 1.0
	add_child(debugTimer)
	debugTimer.connect("timeout", self, "_print_debug")
	
	
	tracking = get_node(tracking)
		
	mapSource = get_node(mapSource)
	startTime = OS.get_ticks_msec()
	
	pathFinder = tracking.get_node("PathFinder")
	
func _print_debug():
	var wck = mapSource.getWaterCells()
	print(wck.size())
	print(_calculate_spawn_rate((OS.get_ticks_msec() - startTime) / 1000.0, wck.size()))
	
func _process(_delta):
	if is_instance_valid(tracking):
		global_position = tracking.global_position

func _calculate_spawn_rate(secs, available_tiles):
	var next_to_5 = 1.0 / pow(2.0, 1.0 + secs/120)
	if next_to_5 > 1.0:
		next_to_5 = 1.0
	if next_to_5 < 0.02:
		next_to_5 = 0.02
	# Max 0.5s spawn per tile
	if available_tiles > 0:
		if next_to_5 < 8.0/available_tiles:
			next_to_5 = 8.0/available_tiles
	else:
		next_to_5 = 8.0
	return next_to_5
		
func _timeout():
	if isRunning:
		var wck = mapSource.getWaterCells()
		var secs = (OS.get_ticks_msec() - startTime) / 1000.0
		var next_to_5 = _calculate_spawn_rate(secs, wck.size())
		timer.wait_time = next_to_5 * 0.5

		var pos = Vector2.ZERO
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
			
		# Add to world
		var ni = spawnItem.instance()
		ni.global_position = pos
		get_parent().add_child(ni)

		var ai_diff = int(secs / 60)
		ni.setAIDifficulty(ai_diff)
#		ni.multiplyDifficulty(0.1/next_to_5)

		if tracking:
			ni.setTarget(tracking)
