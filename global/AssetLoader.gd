extends Node

var garlic = {
	"use_instant":true,
	"use_timer":true,
#	"timer_delay":1.0, 
	"timer_delay":0.2, 
	
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
#		"low":3,
#		"add":3,
		"low":10,
		"add":10,
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
	
	"targeting":"area_nearest", 
	
	"spawner": {
	},
	
	"damage": {
		"low":10,
		"add":5,
		"knockback":0.0,
	},
}

var weaponList = {
	"garlic":garlic,
	"missile":missile,
}

var spawnItem = preload("res://weapons/WeaponGeneric.tscn")
var weapon_textures = {
	"white_circle_32":preload("res://weapons/textures/white_circle_32.png"),
	"missile":preload("res://weapons/textures/missile.png"),
}

# TODO: Doesn't work for some reason
#func _load_weapon_textures():
#	print("Load weapon textures")
#	var path = "res://weapons/textures"
#	var dir = Directory.new()
#	dir.open(path)
#	dir.list_dir_begin()
#	while true:
#		var file_name = dir.get_next()
#		if file_name == "":
#			break
#		elif !file_name.begins_with(".") and file_name.ends_with(".png"):
#			# Remove the .png part
#			var k = file_name.substr(0,file_name.length()-4)
#			weapon_textures[k] = load(path + "/" + file_name)
#	dir.list_dir_end()
#	print("Weapon textures: ", weapon_textures.keys())
#
#func _ready():
#	_load_weapon_textures()

func spawnWeapon(name, source):
	var weapon = spawnItem.instance()
	weapon.setup(weaponList[name], source)
	return weapon
