extends VBoxContainer

var my_labels
var deferred_text = {}
var init_done = false

var timer
var timerTicks : int = 0

# Convert all child labels into function calls
func _ready():
	my_labels = {}
	for child in self.get_children():
		my_labels[child.name] = child

	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = 1.0
	add_child(timer)
	timer.connect("timeout", self, "_timeout")
	
	init_done = true
	# Player might init before this and call setText()
	# therefore deferred async text
	for k in deferred_text.keys():
		var v = deferred_text[k]
		setText(k, v)
		
func _timeout():
	setText("Time", "%02d:%02d" % [int(timerTicks/60), timerTicks % 60])
	timerTicks += 1

func setText(label, value):
	if my_labels.has(label):
		my_labels[label].text = label + ": " + str(value)
	else:
		print(my_labels, label, value)
	
func setTextDeferred(dd):
	if not init_done:
		deferred_text = dd
	else:
		for k in dd.keys():
			var v = dd[k]
			setText(k, v)
