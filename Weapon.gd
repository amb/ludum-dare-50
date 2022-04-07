extends Area2D

var attachment
var weapon
var attackTimer
var collisionShape
var sprite
var target

func setup(wp, attach):
	weapon = wp.duplicate()
	attachment = attach
	assert (self is Area2D)
	if not weapon.activate_on_detach:
		_activate()

func _activate():
	if weapon.collision_type == "circle":
		collisionShape = CollisionShape2D.new()
		collisionShape.shape = CircleShape2D.new()
		collisionShape.shape.radius = weapon.collision_radius
		add_child(collisionShape)
		
	if weapon.texture:
		sprite = Sprite.new()
		sprite.set_texture(AssetLoader.weapon_textures[weapon.texture])
		scale.x = weapon.initial_scale
		scale.y = weapon.initial_scale
		if weapon.ground_sprite:
			sprite.z_index = -1
		sprite.modulate.a = weapon.opacity
		add_child(sprite)
		
	if weapon.use_timer:
		attackTimer = Timer.new()
		attackTimer.autostart = true
		attackTimer.wait_time = weapon.timer_delay
		attackTimer.connect("timeout", self, "_timer_effect")
		add_child(attackTimer)
	

func _area_trigger(body):
	if weapon.damage:
		var diff = body.global_position - global_position
		body.apply_central_impulse(diff.normalized() * weapon.damage.knockback * 100.0)
		body.takeDamage(_attack_damage())
		
	if weapon.spawner:
		target = body
		print("spawn")

func _timer_effect():
#	print("Timer: ", global_position)
	for body in get_overlapping_bodies():
		# Area effect when bodies inside area
		if body.is_in_group("enemy"):
			_area_trigger(body)

func _attack_damage():
	return weapon.damage.low + randi() % weapon.damage.add

func _process(_delta):
	if weapon.attached:
		if not is_instance_valid(attachment):
			print("Weapon detach")
			weapon.attached = false
			
			# TODO: figure out. lifetime?
			if weapon.activate_on_detach:
				_activate()
			else:
				queue_free()

func _on_weapon_body_entered(body):
	if weapon.use_instant:
		# Instant damage when entering weapon area
		if body.is_in_group("enemy"):
			_area_trigger(body)
			
