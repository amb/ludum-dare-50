extends Button

@export var mapGenerator: Node

func _ready():
	pass
#	mapGenerator = get_node(mapGenerator)

func _on_Generate_pressed():
	mapGenerator.create_new_map($"../MinRange".value, $"../MaxRange".value, $"../Iterations".value)	
