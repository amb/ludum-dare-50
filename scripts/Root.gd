extends Node2D

var timer: Timer
var timerTicks : int = 0

@export var text_dump_path: NodePath
@export var player_path: NodePath
var textDump: Node
var player: Node
signal scene_finished

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q):
		get_tree().quit()
	
func _timeout():
	textDump.setText(tr("Time"), "%02d:%02d" % [timerTicks/60, timerTicks % 60])
	timerTicks += 1

func _player_dead():
	emit_signal("scene_finished")

func _ready():
#	TranslationServer.set_locale("fi")

	textDump = get_node(text_dump_path)
	
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = 1.0
	add_child(timer)
	timer.connect("timeout", Callable(self, "_timeout"))

	player = get_node(player_path)
	
	# Player died, send signal
	if is_instance_valid(player):
		player.connect("death", Callable(self, "_player_dead"))
	
