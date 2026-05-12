extends Node2D

@export var tiles_base_path: NodePath
@export var tiles_ground_path: NodePath
@export var tiles_blocking_path: NodePath
@export var map_tileset: TileSet

var tilesBase: TileMapLayer
var tilesGround: TileMapLayer
var tilesBlocking: TileMapLayer
var mapSize := 128
var mapHalfSize := 64

var baseGrid: Array = []
var groundGrid: Array = []
var blockingGrid: Array = []

var mapUpdateTick: Timer
var cellsNextToWater: Dictionary = {}
var cellsNextToWaterList: Array[Vector2i] = []
var waterUpdateCells: Array[Vector2i] = []

const TILE_ATLAS_OFFSETS = {
	0: Vector2i(0, 3),   # water
	1: Vector2i(0, 0),   # dirt/base
	2: Vector2i(9, 2),   # grass/vegetation
	3: Vector2i(9, 8),
	4: Vector2i(8, 8),   # room/floor alternatives
	5: Vector2i(0, 12),  # wall
}

func _make_grid(value: int) -> Array:
	var grid := []
	for x in range(mapSize):
		grid.append([])
		for y in range(mapSize):
			grid[x].append(value)
	return grid

func _set_grid_cell(grid: Array, x, y, tile_id: int) -> void:
	var ix := int(x)
	var iy := int(y)
	if ix < 0 or iy < 0 or ix >= mapSize or iy >= mapSize:
		return
	grid[ix][iy] = tile_id

func _get_grid_cell(grid: Array, x, y) -> int:
	var ix := int(x)
	var iy := int(y)
	if ix < 0 or iy < 0 or ix >= mapSize or iy >= mapSize:
		return -1
	return grid[ix][iy]

func _set_layer_cell(tmap: TileMapLayer, coords: Vector2i, tile_id: int) -> void:
	if tile_id < 0:
		tmap.erase_cell(coords)
	else:
		tmap.set_cell(coords, tile_id, TILE_ATLAS_OFFSETS.get(tile_id, Vector2i.ZERO))

func _render_grid_to_layer(grid: Array, tmap: TileMapLayer) -> void:
	tmap.clear()
	var water_cells: Array[Vector2i] = []
	var grass_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []
	for x in range(1, mapSize - 1):
		for y in range(1, mapSize - 1):
			var tile_id := int(grid[x][y])
			var coords := Vector2i(x, y)
			_set_layer_cell(tmap, coords, tile_id)
			if tile_id == 0:
				water_cells.append(coords)
			elif tile_id == 2:
				grass_cells.append(coords)
			elif tile_id == 5:
				wall_cells.append(coords)
	if water_cells.size() > 0:
		tmap.set_cells_terrain_connect(water_cells, 0, 0, false)
	if grass_cells.size() > 0:
		tmap.set_cells_terrain_connect(grass_cells, 1, 0, false)
	if wall_cells.size() > 0:
		tmap.set_cells_terrain_connect(wall_cells, 2, 0, false)
	tmap.update_internals()

func _get_grid_neighbours(grid: Array, x: int, y: int) -> Array:
	return [
		_get_grid_cell(grid, x, y - 1),
		_get_grid_cell(grid, x + 1, y - 1),
		_get_grid_cell(grid, x + 1, y),
		_get_grid_cell(grid, x + 1, y + 1),
		_get_grid_cell(grid, x, y + 1),
		_get_grid_cell(grid, x - 1, y + 1),
		_get_grid_cell(grid, x - 1, y),
		_get_grid_cell(grid, x - 1, y - 1),
	]

func _cell_dynamics_grid(grid: Array, range_a: int, range_b: int, tile_id: int, iterations: int) -> void:
	for _it in range(iterations):
		var changes := {}
		for x in range(mapSize):
			for y in range(mapSize):
				var n_cells := _get_grid_neighbours(grid, x, y).count(tile_id)
				if n_cells < range_a:
					changes[Vector2i(x, y)] = -1
				if n_cells > range_b:
					changes[Vector2i(x, y)] = tile_id
		for cell in changes.keys():
			var existing := _get_grid_cell(grid, cell.x, cell.y)
			if existing == -1 or existing == tile_id:
				_set_grid_cell(grid, cell.x, cell.y, changes[cell])

func _center_distance_grid(power: float) -> Array:
	var distances := []
	for x in range(mapSize):
		distances.append([])
		for y in range(mapSize):
			var xd := float(abs(x) - mapHalfSize)
			var yd := float(abs(y) - mapHalfSize)
			distances[x].append(pow(clamp((float(mapHalfSize) - sqrt(xd * xd + yd * yd)) / mapHalfSize, 0.0, 1.0), power))
	return distances

func _grid_with_value(value) -> Array:
	var grid := []
	for x in range(mapSize):
		grid.append([])
		for y in range(mapSize):
			grid[x].append(value)
	return grid

func _probability_tile_fill_grid(grid: Array, tile_id: int, probability_grid: Array) -> void:
	for x in range(mapSize):
		for y in range(mapSize):
			if grid[x][y] == -1 and randf() > probability_grid[x][y]:
				grid[x][y] = tile_id

func _get_blocking_grid_from_tile(grid: Array, tile_id: int) -> Array:
	var res := []
	for x in range(mapSize):
		res.append([])
		for y in range(mapSize):
			res[x].append(grid[x][y] == tile_id)
	return res

func _remove_with_grid(grid: Array, tile_id: int, mask_grid: Array) -> void:
	for x in range(mapSize):
		for y in range(mapSize):
			if mask_grid[x][y] and grid[x][y] == tile_id:
				grid[x][y] = -1

func _add_rooms_grid(grid: Array, block_mask: Array) -> Array:
	var new_tiles := _grid_with_value(false)
	var rooms := []
	var found_rooms := 0
	for _tr in range(50):
		var sizex := (randi() % 4) * 2 + 6
		var sizey := (randi() % 4) * 2 + 6
		var asize := 18
		var loc := Vector2i(
			randi() % (asize * 2 - sizex) + mapSize / 2 - asize,
			randi() % (asize * 2 - sizey) + mapSize / 2 - asize
		)
		var fits := true
		for y in range(-1, sizey + 2):
			for x in range(-1, sizex + 2):
				if block_mask[loc.x + x][loc.y + y]:
					fits = false
					break
			if not fits:
				break
		if fits:
			found_rooms += 1
			rooms.append([loc.x, loc.y, sizex, sizey])
			for x in range(sizex + 1):
				for y in range(sizey + 1):
					var cx := loc.x + x
					var cy := loc.y + y
					grid[cx][cy] = 4
					new_tiles[cx][cy] = true
					block_mask[cx][cy] = true
		if found_rooms > 5:
			break
	return [new_tiles, rooms]

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
	var idx: int = cellsNextToWater[cell]
	var last_cell: Vector2i = cellsNextToWaterList[-1]
	cellsNextToWaterList[idx] = last_cell
	cellsNextToWater[last_cell] = idx
	cellsNextToWaterList.pop_back()
	cellsNextToWater.erase(cell)

func _rebuild_water_frontier() -> void:
	cellsNextToWater.clear()
	cellsNextToWaterList.clear()
	for x in range(mapSize):
		for y in range(mapSize):
			var nb := _get_grid_neighbours(groundGrid, x, y)
			if groundGrid[x][y] != 0 and (nb[0] == 0 or nb[2] == 0 or nb[4] == 0 or nb[6] == 0):
				_add_water_frontier_cell(Vector2i(x, y))

func _generate_new_map(min_range: int, max_range: int, iterations: int) -> void:
	baseGrid = _make_grid(-1)
	groundGrid = _make_grid(-1)
	blockingGrid = _make_grid(-1)
	for x in range(1, mapSize - 1):
		for y in range(1, mapSize - 1):
			baseGrid[x][y] = 1

	_probability_tile_fill_grid(groundGrid, 0, _center_distance_grid(1.0))
	_cell_dynamics_grid(groundGrid, min_range, max_range, 0, iterations)

	var water_mask := _get_blocking_grid_from_tile(groundGrid, 0)
	water_mask[mapHalfSize][mapHalfSize] = true
	var room_result := _add_rooms_grid(groundGrid, water_mask)
	var new_rooms: Array = room_result[1]
	for r in new_rooms:
		var loc := Vector2i(r[0], r[1])
		var sizex: int = r[2]
		var sizey: int = r[3]

		groundGrid[loc.x][loc.y] = -1
		groundGrid[loc.x + sizex][loc.y] = -1
		groundGrid[loc.x][loc.y + sizey] = -1
		groundGrid[loc.x + sizex][loc.y + sizey] = -1

		for y in range(sizey + 1):
			blockingGrid[loc.x][loc.y + y] = 5
			blockingGrid[loc.x + sizex][loc.y + y] = 5
		for x in range(sizex):
			blockingGrid[loc.x + x][loc.y] = 5
			blockingGrid[loc.x + x][loc.y + sizey] = 5

		var pokes := [false, false, false, false]
		for i in range(pokes.size()):
			pokes[i] = randf() > 0.6
		if pokes.count(true) == 0:
			pokes[randi() % 4] = true
		for hside in range(2):
			if pokes[hside]:
				blockingGrid[loc.x + sizex * hside][loc.y + 1 + (randi() % (sizey - 1))] = -1
		for vside in range(2):
			if pokes[vside + 2]:
				blockingGrid[loc.x + 1 + (randi() % (sizex - 1))][loc.y + sizey * vside] = -1

	var grass_probability := _grid_with_value(0.4)
	_probability_tile_fill_grid(groundGrid, 2, grass_probability)
	_cell_dynamics_grid(groundGrid, 3, 4, 2, 2)
	_remove_with_grid(groundGrid, 2, water_mask)

	_render_grid_to_layer(baseGrid, tilesBase)
	_render_grid_to_layer(blockingGrid, tilesBlocking)
	_render_grid_to_layer(groundGrid, tilesGround)
	_rebuild_water_frontier()

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
	var tile_size := tilesBase.tile_set.tile_size.x
	tilesBase.position = Vector2(-mapHalfSize, -mapHalfSize) * tile_size
	tilesGround.position = Vector2(-mapHalfSize, -mapHalfSize) * tile_size
	tilesBlocking.position = Vector2(-mapHalfSize, -mapHalfSize) * tile_size
	_generate_new_map(3, 4, 2)

	mapUpdateTick = Timer.new()
	mapUpdateTick.autostart = true
	mapUpdateTick.wait_time = 0.2
	mapUpdateTick.connect("timeout", Callable(self, "_map_update_tick"))
	add_child(mapUpdateTick)

func _is_spawn_safe_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= mapSize or cell.y >= mapSize:
		return false
	if groundGrid[cell.x][cell.y] == 0:
		return false
	if blockingGrid[cell.x][cell.y] != -1:
		return false
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbour: Vector2i = cell + offset
		if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= mapSize or neighbour.y >= mapSize:
			return false
		if groundGrid[neighbour.x][neighbour.y] == 0:
			return false
	return true

func get_spawn_positions_near_water() -> Array:
	var res := []
	var fallback := []
	var tile_size := tilesBase.tile_set.tile_size.x
	for c in cellsNextToWaterList:
		if groundGrid[c.x][c.y] == 0:
			continue
		var away_from_water := Vector2i.ZERO
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var neighbour: Vector2i = c + offset
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= mapSize or neighbour.y >= mapSize or groundGrid[neighbour.x][neighbour.y] == 0:
				away_from_water -= offset
		if away_from_water != Vector2i.ZERO:
			away_from_water = away_from_water.sign()
			for distance in [2, 1]:
				var spawn_cell: Vector2i = c + away_from_water * distance
				if _is_spawn_safe_cell(spawn_cell):
					res.append(Vector2(spawn_cell) * tile_size + tilesBase.position)
					break
		if _is_spawn_safe_cell(c):
			fallback.append(Vector2(c) * tile_size + tilesBase.position)
	if res.is_empty():
		return fallback
	return res

func getWaterCells() -> Array:
	return get_spawn_positions_near_water()

func is_water_at_global_position(pos: Vector2) -> bool:
	var tile_size := tilesGround.tile_set.tile_size.x
	var cell := Vector2i(floor((pos.x - tilesGround.global_position.x) / tile_size), floor((pos.y - tilesGround.global_position.y) / tile_size))
	if cell.x < 0 or cell.y < 0 or cell.x >= mapSize or cell.y >= mapSize:
		return false
	return groundGrid[cell.x][cell.y] == 0

func _map_update_tick() -> void:
	waterUpdateCells.clear()
	if cellsNextToWaterList.size() > 0:
		var kk := cellsNextToWaterList[randi() % cellsNextToWaterList.size()]
		groundGrid[kk.x][kk.y] = 0
		blockingGrid[kk.x][kk.y] = -1
		_set_layer_cell(tilesGround, kk, 0)
		_set_layer_cell(tilesBlocking, kk, -1)
		waterUpdateCells.append(kk)
		_remove_water_frontier_cell(kk)

		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var neighbour: Vector2i = kk + offset
			if neighbour.x >= 0 and neighbour.y >= 0 and neighbour.x < mapSize and neighbour.y < mapSize and groundGrid[neighbour.x][neighbour.y] != 0:
				_add_water_frontier_cell(neighbour)
			waterUpdateCells.append(neighbour)
		tilesGround.set_cells_terrain_connect(waterUpdateCells, 0, 0, false)
		tilesGround.update_internals()

func create_new_map(min_range, max_range, iterations) -> void:
	_generate_new_map(min_range, max_range, iterations)
