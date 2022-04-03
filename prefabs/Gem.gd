extends Area2D

var myExp : float
var startTime
var playerPickup

func _ready():
	myExp = 1.0
	startTime = OS.get_system_time_msecs()
	playerPickup = false
	add_to_group("gem")
	
func _disable_collision():
	$CollisionShape2D.set_deferred("disabled", true)

func _player_pickup(target):
	playerPickup = true
	target.addExperience(myExp)
	
	$AudioStreamPlayer2D.play()
	_disable_collision()
	$Shadow.set_deferred("disabled", true)
	
	var tween = get_node("Tween")
	tween.follow_property(self, "global_position", self.global_position, \
		target, "global_position", 0.5, \
		Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()

func _on_Gem_body_entered(body):
	if body.name == "Player":
		_player_pickup(body)

func addExp(amount):
	myExp += amount

func _on_Tween_tween_all_completed():
	queue_free()

func _on_Gem_area_entered(area):
#	_disable_collision()
	if area.is_in_group("gem") and area.startTime < self.startTime:
		area.addExp(myExp)
		queue_free()
		
	if area.is_in_group("player"):
		_player_pickup(area.target)
		
	

