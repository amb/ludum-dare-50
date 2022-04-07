extends Area2D

export(NodePath) var attachment

var weapon
var attackTimer
var collisionShape
var sprite
var target

var garlic = {
	"use_instant":false,
	"use_timer":true,
	"timer_delay":1.0, 
	
	# circle, beam
	"collision_type":"circle",
	"collision_radius":16.0,
	"initial_scale":2.0, 
	
	"texture":"white_circle_32",
	"opacity":0.2,
	"ground_sprite":true,
	
	"tracking":false,
	"split_on_strike":0,
	"velocity":1.0,
	"lifetime":-1.0,
	
	"attached":true,
	"activate_on_detach":false,
	
	"targeting":"area_all", 
	
	"spawner": {
	},
	
	"damage": {
		"low":3,
		"add":3,
		"knockback":0.5,
	},
}

var missile = {
	"use_instant":true,
	"use_timer":false,
	"timer_delay":1.0, 
	
	# circle, beam
	"collision_type":"circle",
	"collision_radius":4.0,
	"initial_scale":1.0, 
	
	"texture":"missile",
	"opacity":1.0,
	"ground_sprite":false,
	
	"velocity":1.0,
	"lifetime":10.0,
	
	"tracking":false,
	"split_on_strike":0,
	
	"attached":false,
	"activate_on_detach":false,
	
	"targeting":"area_all", 
	
	"spawner": {
	},
	
	"damage": {
		"low":10,
		"add":5,
		"knockback":0.0,
	},
}


func _ready():
	attachment = get_node(attachment)
	setup(
		{
			"use_instant":false,
			"use_timer":false,
			"timer_delay":1.0, 
			
			"collision_type":"circle",
			"collision_radius":32.0,
			"initial_scale":2.0, 
			
			"texture":null,
			"opacity":1.0,
			"ground_sprite":false,
			
			"tracking":false,
			"split_on_strike":0,
			"velocity":0.0,
			"lifetime":-1.0,
			
			"attached":true,
			"activate_on_detach":false,
			
			"targeting":"area_nearest", 
			
			"spawner": {
				"type":"missile",
				"spread":"arc",
			},
			
			"damage": {
			},
		}
	)
	
func setup(wp):
	weapon = wp
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
		sprite.set_texture(AssertLoader.weapon_textures[weapon.texture])
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
	for body in get_overlapping_bodies():
		# Area effect when bodies inside area
		if body.is_in_group("enemy"):
			_area_trigger(body)

func _attack_damage():
	return weapon.damage.low + randi() % weapon.damage.add

func _process(delta):
	if weapon.attached:
		if is_instance_valid(attachment):
			global_position = attachment.global_position
		else:
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
			
