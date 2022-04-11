extends RigidBody2D

var moveTarget : Vector2
var resting : bool = true
var previousPosition : Vector2

var movementVector = Vector2()
var movementMinDistance = 10.0
var movementForce = 100.0
var health = 12.0

var entityAvatar
var sleepTimer : float = 0.0

var attackTarget
var pathFinder
onready var touchingTarget = false

var seekTimer
var attackTick
var lastSeen
var attackOnBodyEnter : bool = true

const TERRAIN_ID = 2

export(PackedScene) var lootDrop

var currentMaterial

func _death():
	set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Spawn loots
	var ni = lootDrop.instance()
	ni.position.x = global_position.x
	ni.position.y = global_position.y
	get_parent().add_child(ni)
	
#		$Sprite.visible = false
#		$Shadow.visible = false

	AudioManager.play("res://audio/enemy_die.sfxr")
	yield(get_tree().create_timer(0.1), "timeout")

	_destroy()

func takeDamage(amount):
	health -= amount
	$Sprite.set_material(currentMaterial)
	if health <= 0.0:
		_death()
	else:
#		AudioManager.play("res://audio/enemy_take_damage.sfxr")
		# Got hit animation
		yield(get_tree().create_timer(0.1), "timeout")
		$Sprite.set_material(null)
	

func setTarget(target):
	attackTarget = target

func _ready():
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
#	pathFinder = attackTarget.get_node("PathFinder")
	if self.test_motion(Vector2(1.0, 1.0), false):
		# Remove self
		#_destroy()
		pass
#		queue_free()
	else:
		self.visible = true
		previousPosition = self.position
		
	# Save flash material
	currentMaterial = $Sprite.get_material()
	$Sprite.set_material(null)
	
	lastSeen = OS.get_ticks_msec()
	
func multiplyDifficulty(mm):
	health *= mm
	mass *= mm

func _attackTick():
	if touchingTarget:
		var direction = attackTarget.global_position - global_position
		attackTarget.takeDamage(1.0, direction)
		attackTick.start(0)
	
# Called by prefab timer
func _seekTarget():
	var spr = $Sprite

	if not is_instance_valid(attackTarget):
		attackTarget = null
		
	var totalForce = movementForce * mass
		
	if attackTarget:
		moveTarget = attackTarget.global_position
		var diff = moveTarget - global_position
		var dlen = diff.length()
		
		var space_state = get_world_2d().direct_space_state
		
		# Collide with top tilemap (terrain)
		var result = space_state.intersect_ray(global_position, moveTarget, [], 1 << TERRAIN_ID)
		
		if not result:
			if dlen >= movementMinDistance:
				movementVector = diff/dlen * totalForce
			else:
				movementVector = Vector2.ZERO
			lastSeen = OS.get_ticks_msec()
		else:
			if OS.get_ticks_msec() - lastSeen > 3000:
				var pos = global_position # + Vector2(8.0, 8.0)
				# Some tiles don't have full 100% filled collisions, which is why the minus
				var nextMove = attackTarget.get_node("PathFinder").find_move(Vector2(pos.x, pos.y-3.0))
				if nextMove != Vector2.ZERO:
					movementVector = nextMove * totalForce
				else:
					movementVector = Vector2(randf()*2.0-1.0, randf()*2.0-1.0).normalized() * totalForce
#					movementVector = nextMove
		
		spr.flip_h = movementVector.x < 0
				
#		if dlen > 450.0 and self.visible == true:
#			_go_to_sleep()
#
#		elif dlen < 430.0 and self.visible == false:
#			_wakeup()
			
	else:
		# Scan for player target
		pass
			
#	if sleeping:
#		# Seektimer usually ~0.5s
#		sleepTimer += 0.5
#		if sleepTimer > 25:
#			# Player probably completely forgot this mob existed
#			_destroy()
		
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
			if attackOnBodyEnter:
				_attackTick()

func _on_EnemyMob_body_exited(body):
	if not body.is_in_group("enemy"):
		if body.name == "Player":
			touchingTarget = false

func _on_Area2D_body_entered(body):
	# Drowning
	if not body.is_in_group("enemy"):
#		_death()
		_destroy()
		
