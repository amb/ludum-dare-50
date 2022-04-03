extends VBoxContainer

var my_labels = {}

#var timer
#var timerTicks : int = 0

#	timer = Timer.new()
#	timer.autostart = true
#	timer.wait_time = 1.0
#	add_child(timer)
#	timer.connect("timeout", self, "_timeout")
	
#func _timeout():
#	setText("Time", "%02d:%02d" % [int(timerTicks/60), timerTicks % 60])
#	timerTicks += 1

func setText(label, value):
	var outputText = "%s: %s" % [label, str(value)]
	if not my_labels.has(label):
		var newLabel = Label.new()
		my_labels[label] = newLabel
		newLabel.text = outputText
		add_child(newLabel)
	else:
		my_labels[label].text = outputText
