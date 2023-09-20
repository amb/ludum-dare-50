extends Node2D

@onready var animation_player = $FadeOut/AnimationPlayer
@onready var fade_out = $FadeOut/Control/FadeOutCircle

var mainScene = preload("res://levels/default.tscn")
var current_root
	
func _ready():
	_init_scene()
	fade_out.material.set_shader_parameter("Radius", 600)
#	animation_player.play("FadeIn")
#	yield(animation_player, "animation_finished")
	
func _init_scene():
	current_root = mainScene.instantiate()
	add_child(current_root)
	current_root.connect("scene_finished", Callable(self, "changer"))
	
func changer():
	print("Scene change")
	var delay = 0.5
	
	await get_tree().create_timer(delay).timeout
	animation_player.play_backwards("FadeIn")
	await animation_player.animation_finished
	
	current_root.queue_free()
	_init_scene()
	
	animation_player.play("FadeIn")
	await animation_player.animation_finished
