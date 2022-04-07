extends Node

var weapon_textures = {}

func _load_weapon_textures():
	print("Load weapon textures")
	var path = "res://weapons/textures"
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		elif !file_name.begins_with(".") and file_name.ends_with(".png"):
			# Remove the .png part
			var k = file_name.substr(0,file_name.length()-4)
			weapon_textures[k] = load(path + "/" + file_name)
	dir.list_dir_end()
	print("Weapon textures: ", weapon_textures.keys())

func _ready():
	_load_weapon_textures()
