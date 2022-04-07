extends Area2D

var myExp : float
var startTime
#var playerPickup

func _ready():
	myExp = 1.0
	startTime = OS.get_system_time_msecs()
#	playerPickup = false
	add_to_group("gem")
	
func _player_pickup(target):
#	playerPickup = true
	if is_instance_valid(target):
		target.addExperience(myExp)
		
		$CollisionShape2D.set_deferred("disabled", true)
		$Shadow.set_deferred("disabled", true)
		
		var tween = get_node("Tween")
		tween.follow_property(self, "global_position", self.global_position, \
			target, "global_position", 0.5, \
			Tween.TRANS_LINEAR, Tween.EASE_OUT)
		tween.start()
		
		yield(tween, "tween_completed")
		$Gemsprite.visible = false
		$GemPickupAS.play()
		yield($GemPickupAS, "finished")
		queue_free()

func _on_Gem_body_entered(body):
	if body.name == "Player":
		_player_pickup(body)
	else:
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
		_player_pickup(area.target)
		
	

