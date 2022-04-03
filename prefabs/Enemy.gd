extends RigidBody2D

var moveTarget : Vector2
var resting : bool = true
var restingTick = 0.0
var previousPosition : Vector2

var oldLayerMask
var oldCollisionMask

var movementTick = 0.0
var movementTickMax = 0.1
var movementVector = Vector2()
var moving : bool = false

var movementMinDistance = 10.0
var movementMaxSpeedSquared = 1000.0
var movementForce = 100.0

var entityAvatar
var sleepTimer : float = 0.0

var attackTarget
onready var touchingTarget = false

var spawner

var seekTimer
var attackTick

var health = 12.0

var rng = RandomNumberGenerator.new()

var rootNode

const TERRAIN_ID = 2

func takeDamage(amount):
	rootNode.emit_signal("spawn_damage_number", amount, global_position)
	health -= amount
	if health <= 0.0:
		_destroy()

func setTarget(target):
	attackTarget = target

func _ready():
	rootNode = get_tree().root.get_child(0)
	
	rng.randomize()
	entityAvatar = get_node("Sprite")

	seekTimer = Timer.new()
	seekTimer.autostart = true
	seekTimer.wait_time = 0.497
	seekTimer.connect("timeout", self, "_seekTarget")
	add_child(seekTimer)
	
	attackTick = Timer.new()
	attackTick.autostart = true
	attackTick.wait_time = 0.5
	attackTick.connect("timeout", self, "_attackTick")
	add_child(attackTick)
#
	resting = false
	
	# Lock rotation
	self.mode = self.MODE_CHARACTER 
	
	# Test if can move and not collide
	if self.test_motion(Vector2(2.0, 2.0), false):
		# Remove self
		_destroy()
	else:
		self.visible = true
		previousPosition = self.position

func _attackTick():
	if touchingTarget:
		var direction = attackTarget.global_position - global_position
		attackTarget.takeDamage(1.0, direction)
		attackTick.start(0)
	
# Called by prefab timer
func _seekTarget():
	var spr = $Sprite
#	spr.frame = 1 - spr.frame 

	if not is_instance_valid(attackTarget):
		attackTarget = null
	
	if attackTarget:
		moveTarget = attackTarget.global_position
		var diff = moveTarget - global_position
		var dlen = diff.length()
		
		var space_state = get_world_2d().direct_space_state
		
		# Collide with top tilemap (terrain)
		var result = space_state.intersect_ray(global_position, moveTarget, [], 1 << TERRAIN_ID)
		
		if not result:
			if dlen >= movementMinDistance:
				movementVector = diff/dlen * movementForce
			else:
				movementVector = Vector2.ZERO
#		else:
##			print(result)
#			var nextMove = attackTarget.pathFinder.find_move(global_position)
#			if nextMove != Vector2.ZERO:
#				movementVector = nextMove * movementForce
#			else:
#				movementVector = Vector2(rng.randf()*2.0-1.0, rng.randf()*2.0-1.0).normalized()
#
		spr.flip_h = movementVector.x < 0
				
		if dlen > 450.0 and self.visible == true:
			_go_to_sleep()
			
		elif dlen < 430.0 and self.visible == false:
			_wakeup()
			
	else:
		# Scan for player target
		pass
			
	if sleeping:
		# Seektimer usually ~0.5s
		sleepTimer += 0.5
		if sleepTimer > 25:
			# Player probably completely forgot this mob existed
			_destroy()
		
func _destroy():
#	spawner.mobCounterLabel.sub_mob_count()
	queue_free()
		
func _wakeup():
	self.mode = RigidBody2D.MODE_CHARACTER
	self.sleeping = false
	sleepTimer = 0.0
	self.visible = true
	set_process(true)
	
func _go_to_sleep():
	set_process(false)
	self.visible = false
	self.mode = RigidBody2D.MODE_STATIC
	self.sleeping = true

func _integrate_forces(_state):
	applied_force = movementVector

func _on_EnemyMob_body_entered(body):
	if not body.is_in_group("enemy"):
		if body.name == "Player":
			touchingTarget = true
			_attackTick()

func _on_EnemyMob_body_exited(body):
	if not body.is_in_group("enemy"):
		if body.name == "Player":
			touchingTarget = false

