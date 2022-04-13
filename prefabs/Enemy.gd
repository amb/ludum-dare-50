extends RigidBody2D

var movementVector = Vector2()
var movementMinDistance = 10.0
var movementForce = 100.0
var health = 12.0

var attackTarget
var pathFinder
onready var touchingTarget = false

enum EnemyState {IDLE, CHASING, TRACKING}
var _state : int = EnemyState.IDLE
var _tracking_range : int = 5
var _aggro_range : int = 10
var _predict_move : float = 1.0

var _ai_difficulty = [
	{
		"tracking":0,
		"aggro":15,
		"speed":80.0,
		"predict":0.0,
		"state":EnemyState.IDLE, 
	},
	{
		"tracking":5,
		"aggro":15,
		"speed":90.0,
		"predict":0.0,
		"state":EnemyState.IDLE, 
	},
	{
		"tracking":10,
		"aggro":20,
		"speed":100.0,
		"predict":0.4,
		"state":EnemyState.IDLE, 
	},
	{
		"tracking":15,
		"aggro":25,
		"speed":100.0,
		"predict":0.8,
		"state":EnemyState.TRACKING, 
	},
	{
		"tracking":50,
		"aggro":30,
		"speed":100.0,
		"predict":1.2,
		"state":EnemyState.TRACKING, 
	},
	{
		"tracking":100,
		"aggro":50,
		"speed":110.0,
		"predict":1.6,
		"state":EnemyState.TRACKING, 
	},
	# 6
	{
		"tracking":100,
		"aggro":100,
		"speed":120.0,
		"predict":2.0,
		"state":EnemyState.TRACKING, 
	},
	{
		"tracking":100,
		"aggro":100,
		"speed":130.0,
		"predict":2.0,
		"state":EnemyState.TRACKING, 
	},
	{
		"tracking":100,
		"aggro":100,
		"speed":140.0,
		"predict":2.0,
		"state":EnemyState.TRACKING, 
	},
	{
		"tracking":100,
		"aggro":100,
		"speed":150.0,
		"predict":2.0,
		"state":EnemyState.TRACKING, 
	},
]

var entityAvatar
var sleepTimer : float = 0.0

var seekTimer
var attackTick
var lastSeen
var attackOnBodyEnter : bool = true

const TERRAIN_ID = 2

export(PackedScene) var lootDrop

var currentMaterial

func setAIDifficulty(val):
	var d 
	if _ai_difficulty.size() > val:
		d = _ai_difficulty[val]
	else:
		d = _ai_difficulty[-1]
	_tracking_range = d.tracking
	_aggro_range = d.aggro
	_predict_move = d.predict
	movementForce = d.speed
	_state = d.state

func _death():
	set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Spawn loots
	var ni = lootDrop.instance()
	ni.position.x = global_position.x
	ni.position.y = global_position.y
	get_parent().add_child(ni)
	
	AudioManager.play("res://audio/enemy_die.sfxr")
	
	# Delay enough to show some hit animation/flashing
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
	if is_instance_valid(target):
		attackTarget = target
		pathFinder = attackTarget.get_node("PathFinder")

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
		
	# Save flash material
	currentMaterial = $Sprite.get_material()
	$Sprite.set_material(null)
	
	lastSeen = OS.get_ticks_msec()
	setAIDifficulty(0)
	
func multiplyDifficulty(mm):
	health *= mm
	mass *= mm

func _attackTick():
	if touchingTarget:
		var direction = attackTarget.global_position - global_position
		attackTarget.takeDamage(1.0, direction)
		attackTick.start(0)
	
func _seekTarget():
	var totalForce = movementForce * mass
	
	if not is_instance_valid(attackTarget):
		attackTarget = null
		_state = EnemyState.IDLE
		return
		
	var diff = attackTarget.global_position - global_position
	var dlen = diff.length()
	var space_state = get_world_2d().direct_space_state
	var pos = global_position
	
	# Collide with top tilemap (terrain)
	var result = space_state.intersect_ray(global_position, \
		attackTarget.global_position, [], 1 << TERRAIN_ID)
	var player_in_sight = not result
	# TODO: magic numbers
	var tracking_distance = 99 - pathFinder.get_grid_value(pos)
	
	match _state:
		EnemyState.IDLE:
			if player_in_sight and _aggro_range * 16.0 > dlen:
				_state = EnemyState.CHASING
			else:
				movementVector = Vector2(randf()*2.0-1.0, randf()*2.0-1.0).normalized() * totalForce
			
			if OS.get_ticks_msec() - lastSeen > 60000 and dlen > 20.0 * 16.0:
				# If idle more than a minute, go away
				_destroy()
				
		EnemyState.TRACKING:
			# Some tiles don't have full 100% filled collisions, which is why the minus
			var nextMove = pathFinder.find_move(Vector2(pos.x, pos.y-3.0))
			if nextMove != Vector2.ZERO:
				movementVector = nextMove * totalForce
			
			if not player_in_sight and _tracking_range < tracking_distance:
				_state = EnemyState.IDLE
				
			if player_in_sight:
				_state = EnemyState.CHASING
				
		EnemyState.CHASING:
			if player_in_sight:
				var predictedLocation = attackTarget.global_position + \
					attackTarget.movementVector * dlen * _predict_move
				diff = predictedLocation - global_position
				movementVector = diff/diff.length() * totalForce
				lastSeen = OS.get_ticks_msec()
				
			elif tracking_distance < _tracking_range:
				_state = EnemyState.TRACKING
			
			elif OS.get_ticks_msec() - lastSeen > 3000:
				_state = EnemyState.IDLE
		
	$Sprite.flip_h = movementVector.x < 0
				
#		if dlen > 450.0 and self.visible == true:
#			_go_to_sleep()
#
#		elif dlen < 430.0 and self.visible == false:
#			_wakeup()
			
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
		
