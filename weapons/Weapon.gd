extends Area2D

var attachment
var weapon
var wp_zero
var attackTimer
var collisionShape
var sprite
var target

func setup(wp, attach):
	weapon = wp.duplicate(true)
	attachment = attach
	assert (self is Area2D)
	wp_zero = weapon.duplicate(true)
	if not weapon.activate_on_detach:
		_activate()
		
func applyMods(mods):
	if mods.area.level > 0:
		scale.x = 2.0 * mods.area.value
		scale.y = scale.x
	if mods.damage.level > 0:
		weapon.damage.low = int(wp_zero.damage.low * mods.damage.value)
		weapon.damage.add = int(wp_zero.damage.add * mods.damage.value)
	if mods.cast.level > 0:
		weapon.timer_delay = wp_zero.timer_delay / mods.cast.value
		attackTimer.wait_time = weapon.timer_delay
#	if mods.knockback.level > 0:
#		weapon.damage.knockback = wp_zero.damage.knockback * mods.knockback.value
	
		

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
		body.takeDamage(_attack_damage())
		if is_instance_valid(body):
			var kbv = weapon.damage.knockback * 100.0
			body.apply_central_impulse(diff.normalized() * kbv)
		
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
			
