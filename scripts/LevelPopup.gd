extends PanelContainer

var powerups = {}
#var mutex
@export var modManager: NodePath

signal panelFinished

func _ready():
	modManager = get_node(modManager)
	visible = false
#	mutex = Mutex.new()

func _button_press(foo):
	modManager.powerupMod(foo)
	_deactivate()

func activate():
#	mutex.lock()
	get_tree().paused = true
	visible = true
	
	# Pick random mods
	var mods = modManager.getPowerupNames()
	var picked = mods.keys()
	picked.shuffle()
	picked = picked.slice(0, 2)
	
	print("Modmanager: Activate")
	print(picked)
	
	# Create buttons
#	var box_width = 0.0
	var total_height = 0.0
	for m in picked:
		var new_button = Button.new()
		$VBoxContainer.add_child(new_button)
		new_button.text = mods[m]
		new_button.name = m
		new_button.connect("pressed", Callable(self, "_button_press").bind(m))
		total_height += new_button.size.y
		total_height += 3
#		if box_width < new_button.rect_size.x:
#			box_width = new_button.rect_size.x
#		total_height += $VBoxContainer.theme.separation
#	$VBoxContainer.emit_signal("item_rect_changed")
	
#	self.rect_min_size.y = total_height + 20
#	self.rect_min_size.x = box_width + 40
#	print(total_height + 20, ", ", box_width + 40)
	if picked.size() > 0:
		$VBoxContainer.get_node(picked[0]).grab_focus()
	else:
		_deactivate()

func _deactivate():
	for child in $VBoxContainer.get_children():
		child.queue_free()
	get_tree().paused = false
	visible = false
	emit_signal("panelFinished")
#	mutex.unlock()
	
func _input(ev):
	if visible:
		if ev is InputEventKey and ev.pressed and \
		ev.keycode == KEY_ESCAPE and not ev.echo:
			_deactivate()


