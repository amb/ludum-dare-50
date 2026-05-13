extends Node

var weaponList: Dictionary = {
	"garlic": preload("res://weapons/data/garlic.tres"),
	"missile": preload("res://weapons/data/missile.tres"),
}

var spawnItem = preload("res://weapons/WeaponGeneric.tscn")

func spawnWeapon(weapon_name, source):
	var weapon = spawnItem.instantiate()
	weapon.setup(weaponList[weapon_name], source)
	return weapon
