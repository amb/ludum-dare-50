extends Node2D

var mods = {}

func _json_parse(file_loc):
	var file = File.new()
	file.open(file_loc, file.READ)
	var text = file.get_as_text()
	file.close()
	mods = JSON.parse(text).result

func _ready():
	print("Init: Modmanager")
	mods = {}
	_json_parse("res://assets/values/mods.json")

func getPowerupNames():
	var res = {}
	for k in mods.keys():
		res[k] = mods[k]["description"]
	return res
	
func powerupMod(name):
	print("Powerup:", name)
