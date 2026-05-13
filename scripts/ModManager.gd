extends Node2D

@export var mod_resources: Array[Resource] = [
	preload("res://mods/area.tres"),
	preload("res://mods/damage.tres"),
	preload("res://mods/cast.tres"),
	preload("res://mods/speed.tres"),
	preload("res://mods/pickup.tres"),
	preload("res://mods/health.tres"),
]

var mods: Dictionary = {}

func _ready():
	mods.clear()
	for mod_resource in mod_resources:
		var mod = mod_resource.runtime_copy()
		mods[mod.id] = mod

func _get_mods_keys_with_levelups() -> Array:
	var res := []
	for k in mods.keys():
		if mods[k].can_level_up():
			res.append(k)
	return res

func getRandomPowerupName():
	return mods.keys()[randi() % mods.size()]

func getPowerupNames():
	var res := {}
	for k in _get_mods_keys_with_levelups():
		res[k] = tr(mods[k].description)
	return res
	
func getActivatedMods():
	var res := []
	for k in mods.keys():
		if mods[k].level > 0:
			res.append([k, mods[k]])
	return res
			
func getActiveModsDict():
	var res := {}
	for k in mods.keys():
		if mods[k].level > 0:
			res[k] = mods[k]
	return res
	
func powerupMod(mod_name):
	mods[mod_name].powerup()
