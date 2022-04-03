extends Node2D

export(PackedScene) var spawnItem
export(float) var timerTick

var itemPreload
var timer

func _ready():
#	itemPreload = preload(spawnItem)
	
	timer = Timer.new()
	timer.autostart = true
	# Add randomness to avoid race conditions
	timer.wait_time = timerTick + randf() * 0.1
	add_child(timer)
	timer.connect("timeout", self, "_timeout")

func _timeout():
	var ni = spawnItem.instance()
	ni.position.x += randf() * 100.0 - 50.0
	ni.position.y += randf() * 100.0 - 50.0
	add_child(ni)
