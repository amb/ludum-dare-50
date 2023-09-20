extends Node2D

@export var tilesBase: TileMap
@export var tilesGround: TileMap
@export var tilesBlocking: TileMap

var mapSize = 128
var mapHalfSize = 64

var mapUpdateTick
var cellsNextToWater

func _fill_tiles_grid(tmap, tile_id, tiles):
	for x in range(1, mapSize-1):
		for y in range(1, mapSize-1):
			if tiles[x][y]:
				tmap.set_cell(x, y, tile_id)
			
func _fill_tiles(tmap, tile_id):
	# Skip corners
	for x in range(1, mapSize-1):
		for y in range(1, mapSize-1):
			tmap.set_cell(x, y, tile_id)
			
func _get_cell_neighbours(tmap, x, y):
	# Clockwise, start from top
	return [ \
		tmap.get_cell(x, y-1), \
		tmap.get_cell(x+1, y-1), \
		tmap.get_cell(x+1, y), \
		tmap.get_cell(x+1, y+1), \
		tmap.get_cell(x, y+1), \
		tmap.get_cell(x-1, y+1), \
		tmap.get_cell(x-1, y), \
		tmap.get_cell(x-1, y-1), \
	]
			
func _cell_dynamics(tmap, range_a, range_b, tile_id, iterations):
#	var used_cells = tmap.get_used_cells()
#	print("cd:", " min:", range_a, " max:", range_b, " it:", iterations)
	for _it in range(iterations):
		var new_cells = {}
		for x in range(mapSize):
			for y in range(mapSize):
				var neighbours = _get_cell_neighbours(tmap, x, y)
				var n_cells = neighbours.count(tile_id)
				if n_cells < range_a:
					new_cells[Vector2(x, y)] = -1
				if n_cells > range_b:
					new_cells[Vector2(x, y)] = tile_id
					
		for cell in new_cells.keys():
			# Only write at empty locations
			var ec = tmap.get_cell(cell.x, cell.y)
			if ec == -1 or ec == tile_id:
				tmap.set_cell(cell.x, cell.y, new_cells[cell])
				
func _center_distance_grid(pw):
	var distances = []
	for y in range(mapSize):
		var yd = float(abs(y)-mapHalfSize)
		distances.append([])
		for x in range(mapSize):
			var xd = float(abs(x)-mapHalfSize)
			distances[-1].append(pow(clamp((float(mapHalfSize) - sqrt(xd*xd+yd*yd)) / mapHalfSize, 0.0, 1.0), pw))
	return distances
	
func _grid_with_value(v):
	var vals = []
	for _y in range(mapSize):
		vals.append([])
		for _x in range(mapSize):
			vals[-1].append(v)
	return vals
			
func _probability_tile_fill(tmap, tile_id, pgrid):
	for x in range(mapSize):
		for y in range(mapSize):
			# Don't overwrite cells
			if tmap.get_cell(x, y) == -1 and randf() > pgrid[x][y]:
				tmap.set_cell(x, y, tile_id)
				
func _add_rooms(tmap, blocking_grid):
#	var tiles = tilesBase.tile_set.get_tiles_ids()
#	print(tiles)
#	for y in range(mapSize):
#		for x in range(mapSize):
#			if not blocking_grid[x][y]:
#				tmap.set_cell(x, y, 5)

	var new_tiles = _grid_with_value(false)
	var rooms = []
	var found_rooms = 0
	for _tr in range(50):
		var sizex = (randi() % 4) * 2 + 6
		var sizey = (randi() % 4) * 2 + 6
		
		# Try location
		var asize = 18
		var loc = Vector2( \
			randi() % (asize*2 - sizex) + mapSize/2 - asize, \
			randi() % (asize*2 - sizey) + mapSize/2 - asize)
			
		var it_fits = true
		for y in range(-1, sizey+2):
			for x in range(-1, sizex+2):
				var cx = x + loc.x
				var cy = y + loc.y
				if blocking_grid[cx][cy]:
					it_fits = false
					break
					
		if it_fits:
			found_rooms += 1

			rooms.append([loc.x, loc.y, sizex, sizey])
			for x in range(sizex+1):
				for y in range(sizey+1):
					var cx = x+loc.x
					var cy = y+loc.y
					tmap.set_cell(cx, cy, 4)
					new_tiles[cx][cy] = true
					blocking_grid[cx][cy] = true
					
		if found_rooms > 5:
			break
	return [new_tiles, rooms]
					
func _get_blocking_grid(tmap, tile_id):
	var res = []
	for x in range(mapSize):
		res.append([])
		for y in range(mapSize):
			res[-1].append(tmap.get_cell(x, y) == tile_id)
	return res
	
func _mul_blocking_grid(trg, bgrid):
	for x in range(mapSize):
		for y in range(mapSize):
			if bgrid[x][y]:
				trg[x][y] = 1.0

func _remove_with_grid(tmap, tile_id, bgrid):
	for x in range(mapSize):
		for y in range(mapSize):
			if bgrid[x][y] and tmap.get_cell(x, y) == tile_id:
#			if bgrid[x][y]:
#				print("rem")
				tmap.set_cell(x, y, -1)

func _autotile_walls(bmap, gmap, x, y):
	var nb = _get_cell_neighbours(gmap, x, y)
	var tt = gmap.get_cell(x, y)
	
	# Right wall
	if (nb[2] != 5 and tt == 5):
		bmap.set_cell(x, y, 5, false, false, false, Vector2(3, 1))
		
	# Left wall
	if (nb[6] != 5 and tt == 5):
		bmap.set_cell(x, y, 5, false, false, false, Vector2(1, 1))
		
	# Upper and lower walls
	if (nb[0] != 5 and tt == 5) or (tt == 5 and nb[4] != 5):
		bmap.set_cell(x, y, 5, false, false, false, Vector2(2, 0))

	# Upper corners
	# Lup
	if (nb[0] != 5 and nb[6] != 5 and tt == 5):
		bmap.set_cell(x, y, 5, false, false, false, Vector2(1, 0))
		
	# Rup
	if (nb[0] != 5 and nb[2] != 5 and tt == 5):
		bmap.set_cell(x, y, 5, false, false, false, Vector2(3, 0))
		
func _walls_from_floor(bmap, gmap):
	for x in range(mapSize):
		for y in range(mapSize):
			_autotile_walls(bmap, gmap, x, y)

func _generate_new_map(min_range, max_range, iterations):
#	var tiles = tilesBase.tile_set.get_tiles_ids()
	
	# Fill background with dirt
	_fill_tiles(tilesBase, 1)
	
	# Fill foreground with water
	_fill_tiles(tilesGround, -1)
	_probability_tile_fill(tilesGround, 0, _center_distance_grid(1.0))
	_cell_dynamics(tilesGround, min_range, max_range, 0, iterations)
	
	# Create new walls
	_fill_tiles(tilesBlocking, -1)
	var bgrid = _get_blocking_grid(tilesGround, 0)
	bgrid[mapHalfSize][mapHalfSize] = true
	var res = _add_rooms(tilesGround, bgrid)
	var _new_tiles = res[0]
	var new_rooms = res[1]
	
	for r in new_rooms:
		var loc = Vector2(r[0], r[1])
		var sizex = r[2]
		var sizey = r[3]
		
		# Remove corner tiles
		tilesGround.set_cell(loc.x, loc.y, -1)
		tilesGround.set_cell(loc.x+sizex, loc.y, -1)
		tilesGround.set_cell(loc.x, loc.y+sizey, -1)
		tilesGround.set_cell(loc.x+sizex, loc.y+sizey, -1)
		
		# Create walls
		for y in range(sizey+1):
			tilesBlocking.set_cell(loc.x, y+loc.y, 5)
			tilesBlocking.set_cell(loc.x+sizex, y+loc.y, 5)
		for x in range(sizex):
			tilesBlocking.set_cell(x+loc.x, loc.y, 5)
			tilesBlocking.set_cell(x+loc.x, loc.y+sizey, 5)
			
		# Create doorways to walls
		var pokes = [false, false, false, false]
		for i in range(pokes.size()):
			pokes[i] = randf() > 0.6
			
		if pokes.count(true) == 0:
			pokes[randi() % 4] = true
		
		for hside in range(2):
			if pokes[hside]:
				var posx = loc.x +sizex * hside
				var posy = loc.y+1 +(randi() % (sizey-1))
				tilesBlocking.set_cell(posx, posy, -1)
			
		for vside in range(2):
			if pokes[vside + 2]:
				var posx = loc.x+1 +(randi() % (sizex-1))
				var posy = loc.y+sizey * vside
				tilesBlocking.set_cell(posx, posy, -1)


#	_fill_tiles_grid(tilesBlocking, 5, new_tiles)
	_update_tilemap(tilesBlocking)

	# Fill empty space with vegetation
	var probg = _grid_with_value(0.4)
	_probability_tile_fill(tilesGround, 2, probg)
	_cell_dynamics(tilesGround, 3, 4, 2, 2)
	_remove_with_grid(tilesGround, 2, bgrid)

	_update_tilemap(tilesGround)
	
func _update_tilemap(tmap):
	tmap.update_dirty_quadrants()
	tmap.update_bitmask_region()
	tmap.fix_invalid_tiles()

func _ready():
#	tilesBase = get_node(tilesBase) as TileMap
#	tilesGround = get_node(tilesGround) as TileMap
#	tilesBlocking = get_node(tilesBlocking) as TileMap
	
	var tileSize = tilesBase.cell_size.x
	
	tilesBase.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	tilesGround.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	tilesBlocking.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	
	print("Run: Map generator")
	_generate_new_map(3, 4, 2)

	mapUpdateTick = Timer.new()
	mapUpdateTick.autostart = true
	mapUpdateTick.wait_time = 0.2
	mapUpdateTick.connect("timeout", Callable(self, "_map_update_tick"))
	add_child(mapUpdateTick)
	
	# Get water and land border tiles
	cellsNextToWater = {}
	for x in range(mapSize):
		for y in range(mapSize):
			var nb = _get_cell_neighbours(tilesGround, x, y)
			# water = 0
			if tilesGround.get_cell(x, y) != 0 and (nb[0] == 0 or nb[2] == 0 or nb[4] == 0 or nb[6] == 0):
				cellsNextToWater[Vector2(x, y)] = true
				
	
func getWaterCells():
	var res = []
	for c in cellsNextToWater.keys():
		res.append(c * tilesBase.cell_size.x + tilesBase.position)
	return res
	
func _map_update_tick():
	if cellsNextToWater.size() > 0:
		# Get random key and fill with water
		var kk = cellsNextToWater.keys()[randi() % cellsNextToWater.size()]
		tilesGround.set_cell(kk.x, kk.y, 0)
		tilesBlocking.set_cell(kk.x, kk.y, -1)
		cellsNextToWater.erase(kk)
		
		if cellsNextToWater.size() == 0:
			print("Level is filled with water")
		
		var locs = [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]
		for l in locs:
			# Not water, add it to next to fill dictionary
			if tilesGround.get_cell(kk.x+l.x, kk.y+l.y) != 0:
				cellsNextToWater[Vector2(kk.x+l.x, kk.y+l.y)] = true
		tilesGround.update_bitmask_region(Vector2(kk.x-1, kk.y-1), Vector2(kk.x+1, kk.y+1))
	else:
		# Level is now full of water
		pass
		

func create_new_map(min_range, max_range, iterations):
	_generate_new_map(min_range, max_range, iterations)
	
