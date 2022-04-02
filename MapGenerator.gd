extends Node2D

export(NodePath) var tilesBase
export(NodePath) var tilesGround
export(NodePath) var tilesBlocking

var mapSize = 128
var mapHalfSize = 64

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
	for it in range(iterations):
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
	for y in range(mapSize):
		vals.append([])
		for x in range(mapSize):
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

	var found_rooms = 0
	for tr in range(300):
		var sizex = (randi() % 4) * 2 + 5
		var sizey = (randi() % 4) * 2 + 5
		
		# Try location
		var loc = Vector2(randi() % (mapSize - sizex), randi() % (mapSize - sizey))
		var it_fits = true
		for y in range(sizey+1):
			for x in range(sizex+1):
				var cx = x + loc.x
				var cy = y + loc.y
#				if blocking_grid[cx][cy] or tmap.get_cell(cx, cy) != -1:
				if blocking_grid[cx][cy]:
					it_fits = false
					break
					
		if it_fits:
			found_rooms += 1
#			for y in range(sizey+1):
#				tmap.set_cell(loc.x, y+loc.y, 5)
#				tmap.set_cell(loc.x+sizex, y+loc.y, 5)
#			for x in range(sizex):
#				tmap.set_cell(x+loc.x, loc.y, 5)
#				tmap.set_cell(x+loc.x, loc.y+sizey, 5)
			for y in range(sizey+1):
				for x in range(sizex):
					var cx = x+loc.x
					var cy = y+loc.y
					tmap.set_cell(cx, cy, 5)
					blocking_grid[cx][cy] = true
					
		if found_rooms > 4:
			print("Found 4 rooms")
			break
					
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
	_add_rooms(tilesBlocking, bgrid)
	
	# Fill empty space with vegetation
	var probg = _grid_with_value(0.4)
#	_mul_blocking_grid(probg, bgrid)
	_probability_tile_fill(tilesGround, 2, probg)
	_cell_dynamics(tilesGround, 3, 4, 2, 2)
	_remove_with_grid(tilesGround, 2, bgrid)

	tilesGround.update_dirty_quadrants()
	tilesGround.update_bitmask_region()
	tilesGround.fix_invalid_tiles()

func _ready():
	tilesBase = get_node(tilesBase) as TileMap
	tilesGround = get_node(tilesGround) as TileMap
	tilesBlocking = get_node(tilesBlocking) as TileMap
	
	var tileSize = tilesBase.cell_size.x
	
	tilesBase.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	tilesGround.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	tilesBlocking.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	
	_generate_new_map(3, 4, 2)

func create_new_map(min_range, max_range, iterations):
	_generate_new_map(min_range, max_range, iterations)
	
