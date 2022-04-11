extends Node2D


var drawTimer

var djkPath : Array
var djkDirection : PoolVector2Array

export(int) var djkSide

var djkWidth : int
var tileWidth : int
var tileWidthf : float

export(Array, NodePath) var djkTiles
export(NodePath) var target
export(bool) var debugDraw
#export(int) var collisionLayer

var font = preload("res://assets/fonts/Minecraft.tres")

var pathToDestination : Array

var builder_thread : Thread
var builder_mutex : Mutex

var target_position : Vector2

var blocker_tiles

# NOTE: If target speed over more than 1 cell per 0.1 seconds
#       may cause issues by pathfinding going back to history locations
#       causing jerky movement

# NOTE: does not support tilemap tiles with unequal width and height

func _ready():
	# Use the layer index from the Godot GUI
#	assert (collisionLayer >= 1)
#	collisionLayer -= 1
	
	for dt in djkTiles.size():
		djkTiles[dt] = get_node(djkTiles[dt])
	
	
	tileWidth = djkTiles[0].cell_size.x
	tileWidthf = float(tileWidth)
	
	djkWidth = djkSide * 2 + 1
	
	target = get_node(target)
	target_position = target.global_position

	# Init necessary arrays
	djkPath = Array()
	djkDirection = PoolVector2Array()
	for i in range(djkWidth*djkWidth):
		djkPath.append(i % djkWidth)
		djkDirection.append(Vector2.ZERO)
		
	# Get all tiels with collision shapes, use those tile to block path
	blocker_tiles = {}
	var tset = djkTiles[0].get_tileset()
	for i in tset.get_tiles_ids():
		if tset.tile_get_shapes(i).size() > 0:
			blocker_tiles[i] = true

	# Builder thread start
	builder_thread = Thread.new()
	builder_mutex = Mutex.new()
	builder_thread.start(self, "_grid_update", [])
	
func find_move(loc) -> Vector2:
	# Based on DJK grid, go toward a higher value (closer to DJK target)
	var tl = _global_to_tile(loc)
	if tl.x >= 1 and tl.x < djkWidth-1 and tl.y >= 1 and tl.y < djkWidth-1:
		var pos = tl.x + tl.y * djkWidth
		var maxmove = djkPath[pos]
		var r = djkPath[pos+1]
		var b = djkPath[pos+djkWidth]
		var l = djkPath[pos-1]
		var t = djkPath[pos-djkWidth]
		var maxchoice = Vector2(0, 0)
		if r > maxmove:
			maxmove = r
			maxchoice = Vector2(1, 0)
		if b > maxmove:
			maxmove = b
			maxchoice = Vector2(0, 1)
		if l > maxmove:
			maxmove = l
			maxchoice = Vector2(-1, 0)
		if t > maxmove:
			maxmove = t
			maxchoice = Vector2(0, -1)
		return maxchoice
	else:
		return Vector2(0, 0)

func find_path(start):
	# Put start location to tile center
	var head = start
	pathToDestination = []
	
	# Try find a direct route through terrain (layer 6)
	var space_state = get_world_2d().direct_space_state
#	var result = space_state.intersect_ray(head, target_position, [], 1 << collisionLayer)
	var result = space_state.intersect_ray(head, target_position)
	if not result:
		# Found a direct line of sight path
		pathToDestination.append(target_position)
	else:
		# No direct route, use path finding
		
		# Set all movement points to the middle of the cell
		head = (head / tileWidthf).floor() * tileWidthf + Vector2(tileWidthf/2, tileWidthf/2)
		for i in range(64):
			head += find_move(head) * tileWidthf
			# Skip steps where we don't move at all
			if i > 0 and head == pathToDestination[-1]: 
				break
			pathToDestination.append(head)
			
		# Prune path with ray-casting from the top towards the beginning
		var ti = 0
		while true:
			if pathToDestination.size()-3-ti < 0:
				break
			var nd = pathToDestination[-1-ti]
			for i in range(pathToDestination.size()-3-ti):
#				result = space_state.intersect_ray(nd, pathToDestination[-3-ti], [], 1 << collisionLayer)
				result = space_state.intersect_ray(nd, pathToDestination[-3-ti])
				if not result:
					# Prune
					var tmp = pathToDestination.pop_at(-1-ti)
					pathToDestination[-1-ti] = tmp
				else:
					break
			ti += 1
			
	return pathToDestination.duplicate()
		
func _global_to_tile(loc):
	var tile_loc = ((loc - self.global_position) / tileWidthf).floor()
	return tile_loc + Vector2(djkSide, djkSide)
		
func _grid_djk_step(djk_grid, blocking_cell):
	var step = 2
	for x in range(0, djkWidth-1):
		for y in range(0, djkWidth-1):
			if not blocking_cell.has(Vector2(x, y)):
				var pos = x + y * djkWidth
				if djk_grid[pos] == 0:
					djk_grid[pos] = max(max(max(djk_grid[pos], djk_grid[pos-1]), djk_grid[pos-djkWidth])-step, 0)
	
	for x in range(djkWidth-2, 0, -1):
		for y in range(djkWidth-2, 0, -1):
			if not blocking_cell.has(Vector2(x, y)):
				var pos = x + y * djkWidth
				if djk_grid[pos] == 0:
					djk_grid[pos] = max(max(max(djk_grid[pos], djk_grid[pos+1]), djk_grid[pos+djkWidth])-step, 0)

func _grid_ray_center_step(djk_grid, blocking_cell):
	# var maxd = sqrt(width*height)
	# widht == height, so...
	var maxd = float(djkSide) * sqrt(2.0)
	var rc = 0
	var ray_blocks = []
	for i in range(36):
		ray_blocks.append(false)
	var astep = 2.0*PI/ray_blocks.size()
	while rc < maxd:
		rc += 0.5
		for a in range(ray_blocks.size()):
			if not ray_blocks[a]:
				var af = float(a) * astep
				var x = sin(af) * rc + djkSide + 0.5
				var y = cos(af) * rc + djkSide + 0.5
				var cell_value = int(maxd - rc) + 70
				var pos = int(x)+int(y)*djkWidth
				if not blocking_cell.has(Vector2(int(x), int(y))) and \
				x >= 0 and y >= 0 and \
				x < djkWidth and y < djkWidth:
					djk_grid[pos] = cell_value
				else:
					ray_blocks[a] = true
		
func _grid_make_vectors(djk_grid):
	for tr in range(0):
		for x in range(1, djkWidth-1):
			for y in range(1, djkWidth-1):
				var pos = x + y * djkWidth
				if djk_grid[pos] == 0:
					continue
				var r = djk_grid[pos+1]
				var l = djk_grid[pos-1]
				var b = djk_grid[pos+djkWidth]
				var t = djk_grid[pos-djkWidth]
				var count = int(r>0) * 1 + int(l>0) * 1 + int(b>0) * 1 + int(t>0) * 1
				djk_grid[pos] = (djk_grid[pos] + r + l + b + t)/(count+1)
		
	var vecl = Vector2(-1.0, 0.0)
	var vecr = Vector2(1.0, 0.0)
	var vecu = Vector2(0.0, -1.0)
	var vecd = Vector2(0.0, 1.0)
		
	# Create directions
	for x in range(1, djkWidth-1):
		for y in range(1, djkWidth-1):
			var pos = x + y * djkWidth
			var dir = Vector2.ZERO
			dir = dir+(djk_grid[pos-1] - djk_grid[pos]) * vecl if (djk_grid[pos-1] > 0) else dir
			dir = dir+(djk_grid[pos+1] - djk_grid[pos]) * vecr if (djk_grid[pos+1] > 0) else dir
			dir = dir+(djk_grid[pos-djkWidth] - djk_grid[pos]) * vecu if (djk_grid[pos-djkWidth] > 0) else dir
			dir = dir+(djk_grid[pos+djkWidth] - djk_grid[pos]) * vecd if (djk_grid[pos+djkWidth] > 0) else dir
			djkDirection[pos] = dir.normalized()
		
func _grid_update(userdata):
	# This is the main thread of the DJK functionality
	while true:
		# Update DJK grid for pathfinding calculations
		builder_mutex.lock()
		
		target_position = target.global_position
		var new_global_position = (target_position / tileWidthf).floor() * tileWidthf
		
		var tile_x = int((new_global_position.x - djkTiles[0].global_position.x) / tileWidthf) - djkSide
		var tile_y = int((new_global_position.y - djkTiles[0].global_position.y) / tileWidthf) - djkSide
		
		# Clear previous data
		for i in range(djkWidth*djkWidth):
			djkPath[i] = 0
			
		# Calculate blocking locations
		var blocking_cell = {}
		for dt in djkTiles.size():
			for x in range(0, djkWidth):
				for y in range(0, djkWidth):
					var cell = djkTiles[dt].get_cell(x + tile_x, y + tile_y)
					var loc = Vector2(x, y)
					if blocker_tiles.has(cell):
						blocking_cell[loc] = true


		# ... but margin introduces troubles in starting the pathfind
		# as it eats the first step and can get player stuck on wallgrinding
		djkPath[djkSide+djkSide*djkWidth] = 99
		
		# Render rays from center, mark distance
#		_grid_ray_center_step(djkPath, blocking_cell)
		
		# Calculate paths, spread from known positions (non-zero)
		for r in range(3):
			_grid_djk_step(djkPath, blocking_cell)

		builder_mutex.unlock()
		update()
		
		# Can only change global position here, otherwise glitch because
		# updated content and position don't match visually
		# has to be close to update() (draws new canvas)
		self.global_position = new_global_position
		OS.delay_msec(100)

func _get_fmod(iv):
	# Get tile remainder based on 2D location 
	var x_off = fmod(iv.x, tileWidthf)
	if x_off < 0.0:
		x_off += tileWidthf
	var y_off = fmod(iv.y, tileWidthf)
	if y_off < 0.0:
		y_off += tileWidthf
	return Vector2(x_off, y_off)

func visible(x, y):
	# Simple visibility test based on smaller numbers
	# compared to what it would be without obstructing tile(s)
	# max(abs(x-y), abs(x+y)) is the function for open area 
	# (max possible values)
#	var maxnum = djkPath[djkSide+djkSide*djkWidth]
#	var tnum = djkPath[(x+djkSide)+(y+djkSide)*djkWidth]
#	return maxnum - max(abs(x-y), abs(x+y)) - 1 > tnum
	pass

func _draw_sub():
#	builder_mutex.lock()
	
	# Purely for debugging
	var gpos = self.global_position
	var xpos = gpos.x
	var ypos = gpos.y

	var maxnum = djkPath[0+djkSide+(0+djkSide)*djkWidth]
	for x in range(-djkSide, djkSide+1):
		for y in range(-djkSide, djkSide+1):
			var xloc = float(x*tileWidth)
			var yloc = float(y*tileWidth)
			var center = Vector2(xloc, yloc)
			var pos = x+djkSide+(y+djkSide)*djkWidth
			var num = djkPath[pos]
			# DJK value
			draw_string(font, Vector2(xloc+2.0, yloc+12.0), str(num), Color.yellow)
			# DJK direction
#			draw_line(center, center + djkDirection[x+djkSide+(y+djkSide)*djkWidth] * 10.0, Color.green)

	# Draw grid
	var v_off = _get_fmod(gpos)
	var x_off = v_off.x
	var y_off = v_off.y
	
	# Draw world origin
	draw_circle(Vector2(-xpos, -ypos), 3.0, Color.yellow)
	
	# Draw grid
	if true:
		draw_circle(Vector2(tileWidthf/2, tileWidthf/2)-v_off, 5.0, Color.blue)
		
		for x in range(-djkSide, djkSide+2):
			var xloc = float(x*tileWidth)-x_off
			draw_line(Vector2(xloc, -tileWidth*djkSide-y_off), Vector2(xloc, tileWidth*(djkSide+1)-y_off), Color.red)

		for y in range(-djkSide, djkSide+2):
			var yloc = float(y*tileWidth)-y_off
			draw_line(Vector2(-tileWidth*djkSide-x_off, yloc), Vector2(tileWidth*(djkSide+1)-x_off, yloc), Color.red)

	# Draw pathfinding result
	if true:
		if not pathToDestination.empty():
			for i in range(1, pathToDestination.size()):
				var ppos = pathToDestination[i]
				draw_circle(ppos - gpos, 5.0, Color.black)
				draw_line(ppos - gpos, pathToDestination[i-1] - gpos, Color.black, 5.0)
				
			for i in range(1, pathToDestination.size()):
				var ppos = pathToDestination[i]
				draw_circle(ppos - gpos, 3.5, Color.green)
				draw_line(ppos - gpos, pathToDestination[i-1] - gpos, Color.green, 2.5)
			
func _draw():
	if debugDraw:
		_draw_sub()
