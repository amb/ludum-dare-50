extends KinematicBody2D

var moveTarget : Vector2
var moving : bool = false
var movementVector : Vector2 = Vector2.ZERO

var previousLocation : Vector2
var movePath : Array
var moving_keyboard : bool = false

var entityAvatar

onready var stats = {
	"health":20.0,
	"maxHealth":20.0,
	"experience":0.0,
	"level":1,
	"levelCap":10,
	"movementSpeed":0.5,
}

var weapons = []

onready var inWater = false
var updateTimer

var movementPath : PoolVector2Array

export(NodePath) var pathFinder
export(NodePath) var modManager
export(NodePath) var textDump
export(NodePath) var levelUpPanel
export(NodePath) var hpBar

signal death

#var mainScene = load("res://default.tscn")

func get_input():
	movementVector = Vector2.ZERO
	
	# Detect up/down/left/right keystate and only move when pressed.
	if Input.is_action_pressed('ui_right'):
		movementVector.x += 1
		entityAvatar.flip_h = false
	if Input.is_action_pressed('ui_left'):
		movementVector.x -= 1
		entityAvatar.flip_h = true
	if Input.is_action_pressed('ui_down'):
		movementVector.y += 1
	if Input.is_action_pressed('ui_up'):
		movementVector.y -= 1
		
	movementVector = movementVector.normalized() * stats.movementSpeed

func setTargetLocation(newLoc):
	# Pathfinding here, therefore separate function
	movePath = pathFinder.find_path(newLoc)
	movePath.invert()
	# Result took a while, global_position already changed if moving
	movePath[0] = global_position

func setTargetDirection(newLoc):
	# Try to move hear on a straight line, no matter what, no path finding
	setMovementDirection(newLoc)
	movePath.clear()

func setMovementDirection(newLoc):
	moveTarget = newLoc
	moving = true

func _update_hp():
#	textDump.setText("Health", health)
	hpBar.value = max(stats.health, 0.0) * 100.0 / stats.maxHealth

func _ready():
	entityAvatar = get_node("Hero")
	textDump = get_node(textDump)
	levelUpPanel = get_node(levelUpPanel)
	hpBar = get_node(hpBar)
	modManager = get_node(modManager)
	
	updateTimer = Timer.new()
	updateTimer.autostart = true
	updateTimer.wait_time = 0.2
	updateTimer.connect("timeout", self, "_updateTick")
	add_child(updateTimer)
	
	_update_hp()
	
	weapons.append(AssetLoader.spawnWeapon("garlic", self))
	add_child(weapons[-1])

func _updateTick():
	# This is to fix the occasional bug where running into
	# water stops the health decrease after not moving
	move_and_slide(Vector2(randf()-0.5, randf()-0.5))

func _process(delta):
	if inWater:
		takeDamage(5.0 * delta, Vector2(0, 0), false)
	get_input()

func _physics_process(_delta):
	previousLocation = self.global_position
	# TODO: keyboard input is sluggy
	if moving:
		var diff = moveTarget - self.position
		var dlen = diff.length()
		if dlen > 5.0:
			move_and_slide(120.0 * diff / dlen)
		else:
			moving = false
			
	if not movePath.empty():
		if movePath[0].distance_squared_to(global_position) < 32.0:
			movePath.pop_front()
		if movePath.size() > 0:
			setMovementDirection(movePath[0])
			
	if movementVector != Vector2.ZERO:
		# Only keyboard move
		moving = false
		move_and_slide(120.0 * movementVector)
		
func _death():
	# Death
	stats.movementSpeed = 0.0
	$DieAS.play()
	stats.health = 0.0
	hpBar.visible = false
	yield($DieAS, "finished")
	emit_signal("death")
	queue_free()
	
func takeDamage(amount, _direction, playsound=true):
	if stats.health > 0:
		stats.health -= amount
		if stats.health <= 0:
			_death()
		else:
			if playsound:
				$DamageAS.play()
			_update_hp()

func _levelup():
	stats.level += 1
	stats.levelCap += 10
	textDump.setText(tr("Level"), stats.level)
	levelUpPanel.activate()
	yield(levelUpPanel, "panelFinished")
	
	# After pause return here
	for i in modManager.getActivatedMods():
		textDump.setText(i[0].capitalize(), str(i[1].value))
		
	var mods = modManager.mods
		
	# Levelup weapons
	for w in weapons:
		w.applyMods(mods)

	# Levelup self
	if mods.health.level > 0:
		stats.health += mods.health.value
		if stats.health > stats.maxHealth:
			stats.health = stats.maxHealth
		_update_hp()
	
	if mods.speed.level > 0:
		stats.movementSpeed = 0.5 * mods.speed.value

	if mods.pickup.level > 0:
		$GemPickup.scale.x = mods.pickup.value
		$GemPickup.scale.y = mods.pickup.value


func addExperience(amount):
#	print("exp:", amount)
	textDump.setText(tr("Exp"), "%.2f" % [stats.experience*100.0 / stats.levelCap])
	stats.experience += amount
	if stats.experience > stats.levelCap:
		stats.experience -= stats.levelCap
		_levelup()

func _on_Area2D_body_entered(body):
	# Water Area2D entered
	if body.name != "Player":
		inWater = true
		stats.movementSpeed *= 0.5

func _on_Area2D_body_exited(body):
	if body.name != "Player":
		inWater = false
		stats.movementSpeed *= 2.0
