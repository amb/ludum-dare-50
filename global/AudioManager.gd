extends Node

var sound = {}
var last_played = {}
var delay = 10

func play(res):
	if not sound.has(res):
		var p = AudioStreamPlayer.new()
		p.stream = load(res)
		add_child(p)
		sound[res] = p
		last_played[res] = OS.get_ticks_msec() - delay * 2
		
	if last_played[res] + delay < OS.get_ticks_msec():
		sound[res].play()
		last_played[res] = OS.get_ticks_msec()
