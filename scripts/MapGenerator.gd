extends Node2D

@export var tiles_base_path: NodePath
@export var tiles_ground_path: NodePath
@export var tiles_blocking_path: NodePath
@export var map_tileset: TileSet
var tilesBase: TileMapLayer
var tilesGround: TileMapLayer
var tilesBlocking: TileMapLayer
var mapSize = 128
var mapHalfSize = 64

var mapUpdateTick
var cellsNextToWater: Dictionary = {}
var cellsNextToWaterList: Array[Vector2i] = []
var waterUpdateCells: Array[Vector2i] = []

const TILE_ATLAS_OFFSETS = {
	0: Vector2i(0, 3),   # water autotile region from the Godot 3 TileSet
	1: Vector2i(0, 0),   # dirt/base tile
	2: Vector2i(9, 2),   # grass/vegetation autotile region
	3: Vector2i(9, 8),
	4: Vector2i(8, 8),   # room/floor alternatives
	5: Vector2i(0, 12),  # wall autotile region
}

func _add_water_frontier_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= mapSize or cell.y >= mapSize:
		return
	if cellsNextToWater.has(cell):
		return
	cellsNextToWater[cell] = cellsNextToWaterList.size()
	cellsNextToWaterList.append(cell)

func _remove_water_frontier_cell(cell: Vector2i) -> void:
	if not cellsNextToWater.has(cell):
		return
	var idx = cellsNextToWater[cell]
	var last_cell = cellsNextToWaterList[-1]
	cellsNextToWaterList[idx] = last_cell
	cellsNextToWater[last_cell] = idx
	cellsNextToWaterList.pop_back()
	cellsNextToWater.erase(cell)

func _set_cell(tmap: TileMapLayer, x, y, tile_id, atlas_coords = Vector2i(-1, -1)):
	var coords = Vector2i(int(x), int(y))
	if int(tile_id) < 0:
		tmap.erase_cell(coords)
	else:
		var final_atlas_coords = atlas_coords
		if final_atlas_coords == Vector2i(-1, -1):
			final_atlas_coords = TILE_ATLAS_OFFSETS.get(int(tile_id), Vector2i(0, 0))
		else:
			final_atlas_coords += TILE_ATLAS_OFFSETS.get(int(tile_id), Vector2i(0, 0))
		tmap.set_cell(coords, int(tile_id), final_atlas_coords)

func _get_cell(tmap: TileMapLayer, x, y) -> int:
	return tmap.get_cell_source_id(Vector2i(int(x), int(y)))

func _fill_tiles_grid(tmap, tile_id, tiles):
	for x in range(1, mapSize-1):
		for y in range(1, mapSize-1):
			if tiles[x][y]:
				_set_cell(tmap, x, y, tile_id)
			
func _fill_tiles(tmap, tile_id):
	# Skip corners
	for x in range(1, mapSize-1):
		for y in range(1, mapSize-1):
			_set_cell(tmap, x, y, tile_id)
			
func _get_cell_neighbours(tmap, x, y):
	# Clockwise, start from top
	return [ \
		_get_cell(tmap, x, y-1), \
		_get_cell(tmap, x+1, y-1), \
		_get_cell(tmap, x+1, y), \
		_get_cell(tmap, x+1, y+1), \
		_get_cell(tmap, x, y+1), \
		_get_cell(tmap, x-1, y+1), \
		_get_cell(tmap, x-1, y), \
		_get_cell(tmap, x-1, y-1), \
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
			var ec = _get_cell(tmap, cell.x, cell.y)
			if ec == -1 or ec == tile_id:
				_set_cell(tmap, cell.x, cell.y, new_cells[cell])
				
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
			if _get_cell(tmap, x, y) == -1 and randf() > pgrid[x][y]:
				_set_cell(tmap, x, y, tile_id)
				
func _add_rooms(tmap, blocking_grid):
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
					_set_cell(tmap, cx, cy, 4)
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
			res[-1].append(_get_cell(tmap, x, y) == tile_id)
	return res
	
func _mul_blocking_grid(trg, bgrid):
	for x in range(mapSize):
		for y in range(mapSize):
			if bgrid[x][y]:
				trg[x][y] = 1.0

func _remove_with_grid(tmap, tile_id, bgrid):
	for x in range(mapSize):
		for y in range(mapSize):
			if bgrid[x][y] and _get_cell(tmap, x, y) == tile_id:
#			if bgrid[x][y]:
#				print("rem")
				_set_cell(tmap, x, y, -1)

func _generate_new_map(min_range, max_range, iterations):
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
		_set_cell(tilesGround, loc.x, loc.y, -1)
		_set_cell(tilesGround, loc.x+sizex, loc.y, -1)
		_set_cell(tilesGround, loc.x, loc.y+sizey, -1)
		_set_cell(tilesGround, loc.x+sizex, loc.y+sizey, -1)
		
		# Create walls
		for y in range(sizey+1):
			_set_cell(tilesBlocking, loc.x, y+loc.y, 5)
			_set_cell(tilesBlocking, loc.x+sizex, y+loc.y, 5)
		for x in range(sizex):
			_set_cell(tilesBlocking, x+loc.x, loc.y, 5)
			_set_cell(tilesBlocking, x+loc.x, loc.y+sizey, 5)
			
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
				_set_cell(tilesBlocking, posx, posy, -1)
			
		for vside in range(2):
			if pokes[vside + 2]:
				var posx = loc.x+1 +(randi() % (sizex-1))
				var posy = loc.y+sizey * vside
				_set_cell(tilesBlocking, posx, posy, -1)


#	_fill_tiles_grid(tilesBlocking, 5, new_tiles)
	_update_tilemap(tilesBlocking)

	# Fill empty space with vegetation
	var probg = _grid_with_value(0.4)
	_probability_tile_fill(tilesGround, 2, probg)
	_cell_dynamics(tilesGround, 3, 4, 2, 2)
	_remove_with_grid(tilesGround, 2, bgrid)

	_update_tilemap(tilesGround)
	
func _update_tilemap(tmap):
	var water_cells = []
	var grass_cells = []
	var wall_cells = []
	for cell in tmap.get_used_cells():
		var tile_id = _get_cell(tmap, cell.x, cell.y)
		if tile_id == 0:
			water_cells.append(cell)
		elif tile_id == 2:
			grass_cells.append(cell)
		elif tile_id == 5:
			wall_cells.append(cell)
	if water_cells.size() > 0:
		tmap.set_cells_terrain_connect(water_cells, 0, 0, false)
	if grass_cells.size() > 0:
		tmap.set_cells_terrain_connect(grass_cells, 1, 0, false)
	if wall_cells.size() > 0:
		tmap.set_cells_terrain_connect(wall_cells, 2, 0, false)
	tmap.update_internals()

func _ready():
	tilesBase = get_node(tiles_base_path) as TileMapLayer
	tilesGround = get_node(tiles_ground_path) as TileMapLayer
	tilesBlocking = get_node(tiles_blocking_path) as TileMapLayer
	
	if map_tileset == null:
		push_error("MapGenerator requires a Godot 4 TileSet resource.")
		return
	tilesBase.tile_set = map_tileset
	tilesGround.tile_set = map_tileset
	tilesBlocking.tile_set = map_tileset
	
	var tileSize = tilesBase.tile_set.tile_size.x
	
	tilesBase.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	tilesGround.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	tilesBlocking.position = Vector2(-mapHalfSize, -mapHalfSize) * tileSize
	
	_generate_new_map(3, 4, 2)

	mapUpdateTick = Timer.new()
	mapUpdateTick.autostart = true
	mapUpdateTick.wait_time = 0.2
	mapUpdateTick.connect("timeout", Callable(self, "_map_update_tick"))
	add_child(mapUpdateTick)
	
	# Get water and land border tiles
	cellsNextToWater.clear()
	cellsNextToWaterList.clear()
	for x in range(mapSize):
		for y in range(mapSize):
			var nb = _get_cell_neighbours(tilesGround, x, y)
			# water = 0
			if _get_cell(tilesGround, x, y) != 0 and (nb[0] == 0 or nb[2] == 0 or nb[4] == 0 or nb[6] == 0):
				_add_water_frontier_cell(Vector2i(x, y))
				
	
func _is_spawn_safe_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= mapSize or cell.y >= mapSize:
		return false
	if _get_cell(tilesGround, cell.x, cell.y) == 0:
		return false
	if _get_cell(tilesBlocking, cell.x, cell.y) != -1:
		return false
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbour = cell + offset
		if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= mapSize or neighbour.y >= mapSize:
			return false
		if _get_cell(tilesGround, neighbour.x, neighbour.y) == 0:
			return false
	return true

func get_spawn_positions_near_water():
	var res = []
	var fallback = []
	var tile_size = tilesBase.tile_set.tile_size.x
	for c in cellsNextToWaterList:
		# cellsNextToWaterList stores the land cells beside expanding water. Enemies have
		# a water-detection Area2D, so spawning directly on these border cells can
		# overlap adjacent water and immediately destroy them. Prefer a nearby dry
		# cell one/two tiles inland, but keep the old border cell as a fallback.
		if _get_cell(tilesGround, c.x, c.y) == 0:
			continue
		var away_from_water = Vector2i.ZERO
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var neighbour = c + offset
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= mapSize or neighbour.y >= mapSize or _get_cell(tilesGround, neighbour.x, neighbour.y) == 0:
				away_from_water -= offset
		if away_from_water != Vector2i.ZERO:
			away_from_water = away_from_water.sign()
			for distance in [2, 1]:
				var spawn_cell = c + away_from_water * distance
				if _is_spawn_safe_cell(spawn_cell):
					res.append(Vector2(spawn_cell) * tile_size + tilesBase.position)
					break
		if _is_spawn_safe_cell(c):
			fallback.append(Vector2(c) * tile_size + tilesBase.position)
	if res.is_empty():
		return fallback
	return res

func getWaterCells():
	# Backward-compatible wrapper for older callers.
	return get_spawn_positions_near_water()
	
func _map_update_tick():
	waterUpdateCells.clear()
	if cellsNextToWaterList.size() > 0:
		# Pick a random frontier cell without allocating cellsNextToWater.keys().
		var kk = cellsNextToWaterList[randi() % cellsNextToWaterList.size()]
		_set_cell(tilesGround, kk.x, kk.y, 0)
		waterUpdateCells.append(kk)
		_set_cell(tilesBlocking, kk.x, kk.y, -1)
		_remove_water_frontier_cell(kk)
		
		var locs = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
		for l in locs:
			var neighbour = kk + l
			# Not water, add it to next to fill dictionary
			if neighbour.x >= 0 and neighbour.y >= 0 and neighbour.x < mapSize and neighbour.y < mapSize and _get_cell(tilesGround, neighbour.x, neighbour.y) != 0:
				_add_water_frontier_cell(neighbour)
			waterUpdateCells.append(neighbour)
		tilesGround.set_cells_terrain_connect(waterUpdateCells, 0, 0, false)
		tilesGround.update_internals()
	else:
		# Level is now full of water
		pass
		

func create_new_map(min_range, max_range, iterations):
	_generate_new_map(min_range, max_range, iterations)
	
