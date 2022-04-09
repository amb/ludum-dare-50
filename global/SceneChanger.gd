extends Node2D

onready var animation_player = $FadeOut/AnimationPlayer
onready var fade_out = $FadeOut/Control/FadeOutCircle

var mainScene = preload("res://levels/default.tscn")
var current_root
	
func _ready():
	_init_scene()
	fade_out.material.set_shader_param("Radius", 600)
	
func _init_scene():
	current_root = mainScene.instance()
	add_child(current_root)
	current_root.connect("scene_finished", self, "changer")
	
func changer():
	print("New scene")
	var delay = 0.5
	
	print("Change scene...")
	yield(get_tree().create_timer(delay), "timeout")
	animation_player.play_backwards("FadeIn")
	yield(animation_player, "animation_finished")
	
	current_root.queue_free()
	_init_scene()
	
	animation_player.play("FadeIn")
	yield(animation_player, "animation_finished")
