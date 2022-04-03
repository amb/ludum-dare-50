extends KinematicBody2D

var moveTarget : Vector2
var moving : bool = false
var moving_keyboard : bool = false
var movementVector : Vector2 = Vector2.ZERO
var previousLocation : Vector2
var movePath : Array

var entityAvatar

onready var health = 20.0
onready var maxHealth = 20.0
onready var energy = 100.0
onready var maxEnergy
onready var experience = 0.0
onready var level = 1
onready var levelCap = 20

var movementPath : PoolVector2Array

export(float) var movementSpeed
export(NodePath) var pathFinder
export(NodePath) var textDump
export(NodePath) var levelUpPanel
export(NodePath) var hpBar
var audioStreamPlayer

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
		
	movementVector = movementVector.normalized() * movementSpeed

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
	hpBar.value = health * 100.0 / maxHealth

func _ready():
	entityAvatar = get_node("Hero")
	textDump = get_node(textDump)
	levelUpPanel = get_node(levelUpPanel)
	hpBar = get_node(hpBar)
	
	_update_hp()

#	textDump.setText("Energy", energy)
#	pathFinder = get_node(pathFinder)

func _physics_process(_delta):
	previousLocation = self.global_position
	# TODO: keyboard input is sluggy
	get_input()
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
		
func takeDamage(amount, direction):
	health -= amount
	$DamageAS.play()
	if health < 0.0:
		health = 0.0
		SceneChanger.change_scene("res://default.tscn")
		queue_free()
	_update_hp()

func _levelup():
	level += 1
	levelCap *= 1.1
	textDump.setText("Level", level)
	levelUpPanel.activate()

func addExperience(amount):
#	print("exp:", amount)
	textDump.setText("Exp", "%.2f" % [experience*100.0/levelCap])
	experience += amount
	if experience > levelCap:
		experience = 0
		_levelup()
