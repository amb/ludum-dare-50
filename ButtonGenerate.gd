extends Button

export(NodePath) var mapGenerator

func _ready():
	mapGenerator = get_node(mapGenerator)

func _on_Generate_pressed():
	mapGenerator.create_new_map($"../MinRange".value, $"../MaxRange".value, $"../Iterations".value)	
