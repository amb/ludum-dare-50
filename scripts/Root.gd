extends Node2D

var timer
var timerTicks : int = 0

export(NodePath) var textDump

	
func _timeout():
	textDump.setText("Time", "%02d:%02d" % [int(timerTicks/60), timerTicks % 60])
	timerTicks += 1


func _ready():
	textDump = get_node(textDump)
	
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = 1.0
	add_child(timer)
	timer.connect("timeout", self, "_timeout")

