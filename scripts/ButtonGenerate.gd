extends Button

@export var map_generator_path: NodePath
var mapGenerator: Node

func _ready():
	mapGenerator = get_node(map_generator_path)

func _on_Generate_pressed():
	mapGenerator.create_new_map($"../MinRange".value, $"../MaxRange".value, $"../Iterations".value)	
