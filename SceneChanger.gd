extends CanvasLayer

onready var animation_player = $AnimationPlayer
onready var fade_out = $Control/FadeOutCircle

func change_scene(path, delay = 0.5):
	print("Change scene...")
	yield(get_tree().create_timer(delay), "timeout")
	animation_player.play_backwards("FadeIn")
	yield(animation_player, "animation_finished")
	get_node("/root/Root").free()
	get_tree().change_scene(path)
	animation_player.play("FadeIn")
