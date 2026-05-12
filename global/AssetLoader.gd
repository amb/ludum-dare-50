extends Node

var weaponList: Dictionary = {
	"garlic": preload("res://weapons/data/garlic.tres"),
	"missile": preload("res://weapons/data/missile.tres"),
}

var spawnItem = preload("res://weapons/WeaponGeneric.tscn")

func spawnWeapon(name, source):
	var weapon = spawnItem.instantiate()
	weapon.setup(weaponList[name], source)
	return weapon
