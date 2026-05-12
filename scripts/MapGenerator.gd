extends Node2D

@export var tilesBase = null
@export var tilesGround = null
@export var tilesBlocking = null
var mapSize = 128
var mapHalfSize = 64

var mapUpdateTick
var cellsNextToWater

const TILE_ATLAS_OFFSETS = {
	0: Vector2i(0, 3),   # water autotile region from the Godot 3 TileSet
	1: Vector2i(0, 0),   # dirt/base tile
	2: Vector2i(9, 2),   # grass/vegetation autotile region
	3: Vector2i(9, 8),
	4: Vector2i(8, 8),   # room/floor alternatives
	5: Vector2i(0, 12),  # wall autotile region
}

const TILE_ATLAS_SIZES = {
	0: Vector2i(8, 7),
	1: Vector2i(1, 1),
	2: Vector2i(5, 4),
	3: Vector2i(5, 3),
	4: Vector2i(1, 3),
	5: Vector2i(4, 3),
}

const TILE_BITMASK_COORDS = {
	0: {
		144: Vector2i(0, 0), 146: Vector2i(0, 1), 18: Vector2i(0, 2), 251: Vector2i(0, 3), 506: Vector2i(0, 4), 434: Vector2i(0, 5), 62: Vector2i(0, 6),
		48: Vector2i(1, 0), 176: Vector2i(1, 1), 50: Vector2i(1, 2), 191: Vector2i(1, 3), 446: Vector2i(1, 4), 248: Vector2i(1, 5), 155: Vector2i(1, 6),
		56: Vector2i(2, 0), 152: Vector2i(2, 1), 26: Vector2i(2, 2), 255: Vector2i(2, 3), 507: Vector2i(2, 4), 182: Vector2i(2, 5), 59: Vector2i(2, 6),
		24: Vector2i(3, 0), 178: Vector2i(3, 1), 58: Vector2i(3, 2), 447: Vector2i(3, 3), 510: Vector2i(3, 4), 440: Vector2i(3, 5), 218: Vector2i(3, 6),
		16: Vector2i(4, 0), 184: Vector2i(4, 1), 154: Vector2i(4, 2), 432: Vector2i(4, 3), 54: Vector2i(4, 4), 442: Vector2i(4, 5), 190: Vector2i(4, 6),
		186: Vector2i(5, 0), 438: Vector2i(5, 1), 63: Vector2i(5, 2), 216: Vector2i(5, 3), 27: Vector2i(5, 4), 250: Vector2i(5, 5), 187: Vector2i(5, 6),
		511: Vector2i(6, 0), 504: Vector2i(6, 1), 219: Vector2i(6, 2), 254: Vector2i(6, 3), 443: Vector2i(6, 4),
	},
	2: {
		257: Vector2i(0, 0), 256: Vector2i(0, 1), 4: Vector2i(0, 2), 325: Vector2i(0, 3), 68: Vector2i(1, 0), 64: Vector2i(1, 1), 1: Vector2i(1, 2),
		69: Vector2i(2, 1), 65: Vector2i(2, 2), 321: Vector2i(2, 3), 5: Vector2i(3, 1), 320: Vector2i(3, 3), 261: Vector2i(4, 1), 260: Vector2i(4, 2), 324: Vector2i(4, 3),
	},
	3: {
		432: Vector2i(0, 0), 438: Vector2i(0, 1), 54: Vector2i(0, 2), 504: Vector2i(1, 0), 511: Vector2i(1, 1), 63: Vector2i(1, 2),
		216: Vector2i(2, 0), 219: Vector2i(2, 1), 27: Vector2i(2, 2), 507: Vector2i(3, 0), 255: Vector2i(3, 1), 510: Vector2i(4, 0), 447: Vector2i(4, 1),
	},
	5: {
		176: Vector2i(0, 0), 50: Vector2i(0, 2), 56: Vector2i(1, 0), 144: Vector2i(1, 1), 16: Vector2i(1, 2), 152: Vector2i(2, 0),
		146: Vector2i(2, 1), 26: Vector2i(2, 2), 48: Vector2i(3, 0), 18: Vector2i(3, 1), 24: Vector2i(3, 2),
	},
}

func _create_runtime_tileset() -> TileSet:
	# Godot 4 cannot automatically convert the original Godot 3 autotile data.
	# Build a simple atlas-based TileSet at runtime so generated maps are visible.
	var texture = load("res://assets/tiles_map.png")
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	# Source TileMaps already carry their collision layers/masks. Keep the
	# TileSet layer broadly enabled and put polygons only on blocking tile types.
	ts.set_physics_layer_collision_layer(0, 0xffffffff)
	ts.set_physics_layer_collision_mask(0, 0xffffffff)
	# TileData collision polygons are local to the tile center in Godot 4.
	# Using 0..16 puts collision half a tile down/right from the visual tile.
	var full_tile_shape = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	for tile_id in TILE_ATLAS_OFFSETS.keys():
		var source = TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(16, 16)
		var offset = TILE_ATLAS_OFFSETS[tile_id]
		var size = TILE_ATLAS_SIZES[tile_id]
		for ax in range(size.x):
			for ay in range(size.y):
				var atlas_coords = offset + Vector2i(ax, ay)
				source.create_tile(atlas_coords)
		ts.add_source(source, tile_id)
		if tile_id == 0 or tile_id == 5:
			for ax in range(size.x):
				for ay in range(size.y):
					var atlas_coords = offset + Vector2i(ax, ay)
					var tile_data = source.get_tile_data(atlas_coords, 0)
					tile_data.add_collision_polygon(0)
					tile_data.set_collision_polygon_points(0, 0, full_tile_shape)
	return ts

func _set_cell(tmap: TileMap, x, y, tile_id, atlas_coords = Vector2i(-1, -1)):
	var coords = Vector2i(int(x), int(y))
	if int(tile_id) < 0:
		tmap.erase_cell(0, coords)
	else:
		var final_atlas_coords = atlas_coords
		if final_atlas_coords == Vector2i(-1, -1):
			final_atlas_coords = TILE_ATLAS_OFFSETS.get(int(tile_id), Vector2i(0, 0))
		else:
			final_atlas_coords += TILE_ATLAS_OFFSETS.get(int(tile_id), Vector2i(0, 0))
		tmap.set_cell(0, coords, int(tile_id), final_atlas_coords)

func _get_cell(tmap: TileMap, x, y) -> int:
	return tmap.get_cell_source_id(0, Vector2i(int(x), int(y)))

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

func _autotile_walls(bmap, gmap, x, y):
	var nb = _get_cell_neighbours(gmap, x, y)
	var tt = _get_cell(gmap, x, y)
	
	# Right wall
	if (nb[2] != 5 and tt == 5):
		_set_cell(bmap, x, y, 5, Vector2i(3, 1))
		
	# Left wall
	if (nb[6] != 5 and tt == 5):
		_set_cell(bmap, x, y, 5, Vector2i(1, 1))
		
	# Upper and lower walls
	if (nb[0] != 5 and tt == 5) or (tt == 5 and nb[4] != 5):
		_set_cell(bmap, x, y, 5, Vector2i(2, 0))

	# Upper corners
	# Lup
	if (nb[0] != 5 and nb[6] != 5 and tt == 5):
		_set_cell(bmap, x, y, 5, Vector2i(1, 0))
		
	# Rup
	if (nb[0] != 5 and nb[2] != 5 and tt == 5):
		_set_cell(bmap, x, y, 5, Vector2i(3, 0))
		
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
	
func _cell_bitmask(tmap: TileMap, x: int, y: int, tile_id: int) -> int:
	if tile_id == 2:
		# Godot 3 tile 2 (grass/vegetation) used BITMASK_2X2. The four stored
		# bits are the four *quadrants* of the visual tile. A quadrant is present
		# only when the 2x2 block of map cells touching that visual quadrant is
		# all grass. Checking only diagonal neighbours flips/breaks corners.
		var up = _get_cell(tmap, x, y - 1) == tile_id
		var right = _get_cell(tmap, x + 1, y) == tile_id
		var down = _get_cell(tmap, x, y + 1) == tile_id
		var left = _get_cell(tmap, x - 1, y) == tile_id
		var mask_2x2 = 0
		# NW, NE, SW, SE quadrant bits from Godot 3's saved bitmask flags.
		if up and left and _get_cell(tmap, x - 1, y - 1) == tile_id:
			mask_2x2 |= 1
		if up and right and _get_cell(tmap, x + 1, y - 1) == tile_id:
			mask_2x2 |= 4
		if down and left and _get_cell(tmap, x - 1, y + 1) == tile_id:
			mask_2x2 |= 64
		if down and right and _get_cell(tmap, x + 1, y + 1) == tile_id:
			mask_2x2 |= 256
		return mask_2x2

	# Recreate Godot 3's 3x3-minimal autotile bitmasking. Diagonal bits only
	# count when both adjacent cardinal neighbours are also present; otherwise
	# many edge/corner cases fall through to the wrong atlas tile.
	var top = _get_cell(tmap, x, y - 1) == tile_id
	var right = _get_cell(tmap, x + 1, y) == tile_id
	var bottom = _get_cell(tmap, x, y + 1) == tile_id
	var left = _get_cell(tmap, x - 1, y) == tile_id
	var mask = 16
	if top:
		mask |= 2
	if right:
		mask |= 32
	if bottom:
		mask |= 128
	if left:
		mask |= 8
	if top and left and _get_cell(tmap, x - 1, y - 1) == tile_id:
		mask |= 1
	if top and right and _get_cell(tmap, x + 1, y - 1) == tile_id:
		mask |= 4
	if bottom and left and _get_cell(tmap, x - 1, y + 1) == tile_id:
		mask |= 64
	if bottom and right and _get_cell(tmap, x + 1, y + 1) == tile_id:
		mask |= 256
	return mask

func _update_tilemap(tmap):
	for cell in tmap.get_used_cells(0):
		var tile_id = _get_cell(tmap, cell.x, cell.y)
		if TILE_BITMASK_COORDS.has(tile_id):
			var mask = _cell_bitmask(tmap, cell.x, cell.y, tile_id)
			var local_atlas = TILE_BITMASK_COORDS[tile_id].get(mask, Vector2i(1, 1) if tile_id == 2 else Vector2i(0, 0))
			_set_cell(tmap, cell.x, cell.y, tile_id, local_atlas)
	tmap.force_update(0)

func _ready():
	tilesBase = get_node(tilesBase) as TileMap
	tilesGround = get_node(tilesGround) as TileMap
	tilesBlocking = get_node(tilesBlocking) as TileMap
	
	var runtime_tileset = _create_runtime_tileset()
	tilesBase.tile_set = runtime_tileset
	tilesGround.tile_set = runtime_tileset
	tilesBlocking.tile_set = runtime_tileset
	
	var tileSize = tilesBase.tile_set.tile_size.x
	
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
			if _get_cell(tilesGround, x, y) != 0 and (nb[0] == 0 or nb[2] == 0 or nb[4] == 0 or nb[6] == 0):
				cellsNextToWater[Vector2(x, y)] = true
				
	
func getWaterCells():
	var res = []
	for c in cellsNextToWater.keys():
		res.append(c * tilesBase.tile_set.tile_size.x + tilesBase.position)
	return res
	
func _map_update_tick():
	if cellsNextToWater.size() > 0:
		# Get random key and fill with water
		var kk = cellsNextToWater.keys()[randi() % cellsNextToWater.size()]
		_set_cell(tilesGround, kk.x, kk.y, 0)
		_set_cell(tilesBlocking, kk.x, kk.y, -1)
		cellsNextToWater.erase(kk)
		
		if cellsNextToWater.size() == 0:
			print("Level is filled with water")
		
		var locs = [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]
		for l in locs:
			# Not water, add it to next to fill dictionary
			if _get_cell(tilesGround, kk.x+l.x, kk.y+l.y) != 0:
				cellsNextToWater[Vector2(kk.x+l.x, kk.y+l.y)] = true
		_update_tilemap(tilesGround)
	else:
		# Level is now full of water
		pass
		

func create_new_map(min_range, max_range, iterations):
	_generate_new_map(min_range, max_range, iterations)
	
