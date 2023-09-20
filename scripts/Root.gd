extends Node2D

var timer
var timerTicks : int = 0

@export var textDump: NodePath
@export var player: NodePath

signal scene_finished
	
func _timeout():
	textDump.setText(tr("Time"), "%02d:%02d" % [timerTicks/60, timerTicks % 60])
	timerTicks += 1

func _player_dead():
	print("Signal: Player dead, end scene")
	emit_signal("scene_finished")

func _ready():
#	TranslationServer.set_locale("fi")

	textDump = get_node(textDump)
	
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = 1.0
	add_child(timer)
	timer.connect("timeout", Callable(self, "_timeout"))

	player = get_node(player)
	
	# Player died, send signal
	if is_instance_valid(player):
		player.connect("death", Callable(self, "_player_dead"))
	
