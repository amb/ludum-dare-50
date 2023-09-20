extends Node2D

var mods = {}

func _json_parse(file_loc):
	var file = FileAccess.open(file_loc, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var test_json_conv = JSON.new()
	test_json_conv.parse(text)
	mods = test_json_conv.get_parsed_text()
	
func _hardcoded_mods():
	return {

		"area": {
			"description":tr("Bigger area"),
			"multiply":1.0,
			"increase":0.1,
			"level":0,
			"max_level":4,
			"value":1.0
		},
		"damage": {
			"description":tr("Increase damage"),
			"multiply":1.0,
			"increase":0.2,
			"level":0,
			"max_level":4,
			"value":1.0
		},
#		"knockback": {
#			"description":tr("Knockback force"),
#			"multiply":1.0,
#			"increase":0.25,
#			"level":0,
#			"max_level":4,
#			"value":1.0
#		},
		"cast": {
			"description":tr("Lower cast time"),
			"multiply":1.0,
			"increase":0.1,
			"level":0,
			"max_level":4,
			"value":1.0
		},
		"speed": {
			"description":tr("Faster movement"),
			"multiply":1.0,
			"increase":0.1,
			"level":0,
			"max_level":4,
			"value":1.0
		},
#		"projectiles": {
#			"description":tr("More projectiles"),
#			"multiply":1.0,
#			"increase":1.0,
#			"level":0,
#			"max_level":10,
#			"value":1.0
#		},
#		"duration": {
#			"description":tr("Longer duration"),
#			"multiply":1.0,
#			"increase":0.25,
#			"level":0,
#			"max_level":10,
#			"value":1.0
#		},
		"pickup": {
			"description":tr("Pickup range"),
			"multiply":1.0,
			"increase":0.7,
			"level":0,
			"max_level":4,
			"value":1.0
		},
		"health": {
			"description":tr("Health pickup"),
			"multiply":1.0,
			"increase":1.0,
			"level":0,
			"max_level":10,
			"value":0.0
		},
#		"armor": {
#			"description":tr("Thicker armor"),
#			"multiply":1.0,
#			"increase":1.0,
#			"level":0,
#			"max_level":10,
#			"value":0.0
#		},
	}

func _get_mods_keys_with_levelups():
	var res = []
	for k in mods.keys():
		if mods[k]["level"] < mods[k]["max_level"]:
			res.append(k)
	return res

func _ready():
	print("Init: Modmanager")
	mods = _hardcoded_mods()
	print(mods.keys())
#	mods = {}
#	_json_parse("res://assets/values/mods.json")

func getRandomPowerupName():
	return mods.keys()[randi() % mods.size()]

func getPowerupNames():
	var res = {}
	for k in _get_mods_keys_with_levelups():
		res[k] = mods[k]["description"]
	return res
	
func getActivatedMods():
	var res = []
	for k in mods.keys():
		if mods[k].level > 0:
			res.append([k, mods[k]])
	return res
			
func getActiveModsDict():
	var res = {}
	for k in mods.keys():
		if mods[k].level > 0:
			res[k] = mods[k]
	return res
	
func powerupMod(name):
	print("Powerup:", name)
	var mn = mods[name]
	# TODO: test mn.level etc
	if mn["level"] < mn["max_level"]:
		mn["level"] += 1
		mn["value"] *= mn["multiply"]
		mn["value"] += mn["increase"]
