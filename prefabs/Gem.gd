extends Area2D

var myExp : float
var startTime
var checkTimer = null
var timerTarget = null
var pickupTarget = null
var pickupStart := Vector2.ZERO
var pickupDuration := 0.5
var pickupElapsed := 0.0

var WALL = 2

func _ready():
	myExp = 5.0
	startTime = Time.get_ticks_msec()
	add_to_group("gem")
	
func _gem_pickup(target):
	target.addExperience(myExp)
	pickupTarget = target
	pickupStart = global_position
	pickupElapsed = 0.0
	
	$CollisionShape2D.set_deferred("disabled", true)
	$Shadow.set_deferred("disabled", true)
	set_process(true)
	
func _player_pickup(target):
	if is_instance_valid(target):
		# Gem must be visible to be picked up
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(position, target.position, 1 << WALL)
		var result = space_state.intersect_ray(query)
		if not result:
			_gem_pickup(target)
		elif checkTimer == null:
			checkTimer = Timer.new()
			checkTimer.autostart = true
			checkTimer.wait_time = 0.5
			add_child(checkTimer)
			checkTimer.connect("timeout", Callable(self, "_timeout"))
			timerTarget = target

func _timeout():
	# Periodically check for player visibility for gem pickup
	_player_pickup(timerTarget)
	
func _process(delta):
	if not is_instance_valid(pickupTarget):
		return
	pickupElapsed += delta
	var weight = clamp(pickupElapsed / pickupDuration, 0.0, 1.0)
	global_position = pickupStart.lerp(pickupTarget.global_position, weight)
	if pickupElapsed >= pickupDuration or global_position.distance_squared_to(pickupTarget.global_position) < 4.0:
		$Gemsprite.visible = false
		AudioManager.play("res://audio/gem_pickup.sfxr")
		queue_free()
	

func _on_Gem_body_entered(body):
	# Collision with terrain, remove
	if body.is_in_group("world"):
		queue_free()

func addExp(amount):
	myExp += amount

func _on_Gem_area_entered(area):
	# Collect nearby gems into one
	if area.is_in_group("gem") and area.startTime < self.startTime:
		area.addExp(myExp)
		queue_free()
		
	# Gem picked up by player when close enough
	if area.is_in_group("player"):
		_player_pickup($"../Player")
		
	

