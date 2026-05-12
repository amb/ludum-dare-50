# Code Improvements After Godot 4 Conversion

Date: 2026-05-12
Project: `ludum-dare-50` / `Survivor Island`

This document lists follow-up improvements for making the converted project more idiomatic, maintainable, and performant in Godot 4. The project is now mostly functional after conversion, but several systems still carry Godot 3-era patterns or temporary migration shims.

## High-priority improvements

### 1. Replace runtime-built TileSet with a real Godot 4 TileSet resource

Status: done in code on 2026-05-13. Added `assets/map_tileset.tres`, assigned it to the map layers from `levels/default.tscn`, and removed runtime TileSet construction from gameplay startup.

Previous state:

- `scripts/MapGenerator.gd` builds a `TileSet` at runtime.
- It creates atlas sources, terrain sets, terrain peering bits, and collision polygons programmatically.
- This was useful for unblocking the conversion, but it is fragile and hard to inspect visually.

Recommended Godot 4 approach:

- Create or save a real `.tres` TileSet resource.
- Configure terrain sets and collisions in the editor or with a one-time migration script.
- Reference the TileSet from the scene/resources normally.
- Remove most of the runtime TileSet construction code from gameplay startup.

Benefits:

- Faster startup.
- Easier visual debugging.
- Terrain peering bits and collision shapes become editable in the Godot 4 editor.
- Less fragile code in `MapGenerator.gd`.

### 2. Convert deprecated `TileMap` usage to `TileMapLayer`

Status: done for the main map scene/scripts on 2026-05-13. `Tiles Base`, `Tiles Ground`, and `Tiles Blocking` are now `TileMapLayer` nodes, and map/pathfinder code uses layer-local APIs.

Godot 4.6 marks `TileMap` as deprecated in favor of `TileMapLayer`.

Current pattern:

```gdscript
tilemap.set_cell(0, coords, source_id, atlas_coords)
tilemap.get_cell_source_id(0, coords)
tilemap.set_cells_terrain_connect(0, cells, terrain_set, terrain)
```

Recommended pattern:

- Convert `Tiles Base`, `Tiles Ground`, and `Tiles Blocking` to separate `TileMapLayer` nodes.
- Use layer-local APIs without passing `0` everywhere.

Target style:

```gdscript
tilemap_layer.set_cell(coords, source_id, atlas_coords)
tilemap_layer.get_cell_source_id(coords)
tilemap_layer.set_cells_terrain_connect(cells, terrain_set, terrain)
```

Benefits:

- More future-proof for Godot 4.6+.
- Cleaner code.
- Less layer-index boilerplate.

### 3. Move map generation data out of TileMap reads/writes

Current state:

- `MapGenerator.gd` uses TileMap state as the source of truth during procedural generation.
- Many helper methods call `_get_cell()` and `_set_cell()` directly against TileMap nodes.

Recommended approach:

- Keep logical map data in arrays/dictionaries first:
  - `base_grid`
  - `ground_grid`
  - `blocking_grid`
- Generate and mutate these data structures.
- Render/batch-apply them to TileMap/TileMapLayer afterward.
- Update terrain only for affected cells.

Benefits:

- Faster generation.
- Easier debugging.
- Easier testing of map algorithms.
- Less dependence on engine-side TileMap state while generating.

### 4. Remove dead/manual autotile migration code once terrains are stable

Status: mostly done on 2026-05-13. Removed the runtime TileSet builder, `_cell_bitmask()`, `_autotile_walls()`, `_walls_from_floor()`, and the old Godot 3 bitmask lookup tables from `MapGenerator.gd` after moving terrain data into `assets/map_tileset.tres`.

Previous/temporary code included manual or partially obsolete helpers from the migration process, such as:

- `_cell_bitmask()`
- `_autotile_walls()`
- `_walls_from_floor()`
- large Godot 3 bitmask lookup tables in `MapGenerator.gd`

Recommended approach:

- Once the TileSet terrain data is stored as a real Godot 4 resource, remove runtime bitmask emulation.
- Let `set_cells_terrain_connect()` choose tiles based on configured terrain peering bits.

Benefits:

- Less confusing code.
- Fewer sources of visual terrain bugs.
- More idiomatic Godot 4 terrain usage.

## Gameplay and physics improvements

### 5. Consider converting enemies from `RigidBody2D` to `CharacterBody2D`

Current state:

- `prefabs/Enemy.gd` extends `RigidBody2D`.
- Enemy movement is driven using force-like values and `constant_force`.
- This is a legacy-style workaround after Godot 3-to-4 migration.

Recommended Godot 4 approach:

```gdscript
extends CharacterBody2D

func _physics_process(delta):
    velocity = movement_direction * movement_speed
    move_and_slide()
```

Benefits:

- More deterministic top-down movement.
- Easier collision behavior.
- Easier to tune speed/pathing.
- Avoids physics-force side effects.

### 6. Evaluate `NavigationAgent2D` versus the custom pathfinder

Status: custom pathfinder kept for now and partially optimized on 2026-05-13. `PathFinder.gd` now reuses a preallocated boolean blocking array instead of rebuilding `Dictionary[Vector2, bool]`, clears/reuses path arrays, uses integer target tiles, and skips full flow-field rebuilds while the player remains in the same tile.

Current state:

- `scripts/PathFinder.gd` implements a custom DJK/flow-field pathfinder.
- This may be intentional for survivor-style many-enemy movement, but it is still tightly coupled to TileMap cell reads.

Options:

1. Keep the custom flow-field system, but refactor it into a clearer, data-oriented component.
2. Replace or augment it with Godot 4 `NavigationAgent2D` and navigation regions.

If using Godot navigation:

- Generate/update walkable navigation polygons or regions.
- Let enemies use `NavigationAgent2D` to chase the player.

If keeping flow fields:

- Store blocking/walkable data separately from TileMap.
- Avoid rebuilding dictionaries every update.
- Make update frequency configurable.

### 7. Rework water damage/collision handling

Current state:

- Water collision/damage behavior depends on TileMap collision and Area2D/body interactions.
- This was restored during conversion, but could be simpler.

Recommended options:

- Query the ground tile under the player each physics frame.
- Or generate a dedicated water collision/area layer using Godot 4 TileSet physics layers.
- Avoid relying on old signal names like `_on_Area2D_body_entered` when the intent is tile-based state.

Benefits:

- More explicit water behavior.
- Easier debugging.
- Less dependent on TileSet collision quirks.

## Script architecture improvements

### 8. Use typed exported node references

Status: partially done on 2026-05-13. Removed the `@export var ... = null` NodePath/node-instance ambiguity from the main gameplay scripts under `scripts/` by splitting exported `NodePath` properties from runtime node references.

Current state:

Many scripts used this migration-friendly style:

```gdscript
@export var modManager = null
```

and later replace the variable with a node instance:

```gdscript
modManager = get_node(modManager)
```

Recommended Godot 4 style:

```gdscript
@export var mod_manager_path: NodePath
@onready var mod_manager: Node = get_node(mod_manager_path)
```

Or, if assigning nodes directly in the Godot 4 editor:

```gdscript
@export var mod_manager: Node
```

Benefits:

- Clearer typing.
- Less ambiguity between `NodePath` and node instance.
- Easier editor use and refactoring.

### 9. Use typed `@onready` node references

Status: partially done on 2026-05-13. Added typed `@onready` references for common child-node lookups in `Player.gd` and `LevelPopup.gd`, replacing repeated `$Node` access in active code.

Current code often calls `get_node()` in `_ready()` and stores loosely-typed variables.

Recommended style:

```gdscript
@onready var hero: Sprite2D = $Hero
@onready var path_finder: Node = $PathFinder
@onready var damage_audio: AudioStreamPlayer2D = $DamageAS
@onready var die_audio: AudioStreamPlayer2D = $DieAS
```

Benefits:

- Cleaner `_ready()` methods.
- More type safety.
- Better autocompletion.
- Easier scene refactoring.

### 10. Replace dictionary-based stats/mods/weapons with Resources or typed classes

Status: partially done on 2026-05-13. Weapon definitions were moved out of hard-coded dictionaries in `AssetLoader.gd` into `WeaponData`/`WeaponDamageData` resources under `weapons/data/`. Player stats and mods are still dictionary-based.

Current state:

- Player stats and modifiers are nested dictionaries.
- Weapon definitions are dictionaries in `AssetLoader.gd`.
- Code uses dictionary dot access like `mods.health.level`.

Recommended Godot 4 approach:

- Create `Resource` scripts such as:
  - `PlayerStats.gd`
  - `ModData.gd`
  - `WeaponData.gd`
- Store data as exported typed properties.
- Reference resources from scenes or preload them.

Example:

```gdscript
class_name PlayerStats
extends Resource

@export var health: float = 20.0
@export var max_health: float = 20.0
@export var movement_speed: float = 0.5
```

Benefits:

- Editor-editable game data.
- Better type safety.
- Easier balancing.
- Less fragile than nested dictionaries.

## Performance improvements

### 11. Reduce allocations in hot paths

Status: partially done on 2026-05-13. `MapGenerator.gd` now keeps the water frontier in both a dictionary and cached array, using swap-remove for random frontier removal. This avoids repeated `cellsNextToWater.keys()` allocation in water expansion and spawn-position lookup. The misleading spawn API was renamed to `get_spawn_positions_near_water()`, with a backward-compatible `getWaterCells()` wrapper. `PathFinder.gd` also now reuses preallocated arrays and avoids rebuilding the flow field unless the player changes tile.

Current examples:

- `getWaterCells()` builds a new array for the spawner.
- `cellsNextToWater.keys()` allocates arrays repeatedly.
- `PathFinder.gd` rebuilds dictionaries in frequent update loops.

Recommended approach:

- Keep frontier cells in cached arrays.
- Use `Array[Vector2i]` where possible.
- Use swap-remove when removing random entries.
- Avoid calling `.keys()` inside frequently-called logic.
- Store map data in arrays rather than dictionaries for dense grids.

Benefits:

- Better frame pacing.
- Less garbage collection pressure.
- More predictable performance.

### 12. Disable debug timers and prints by default

Status: mostly done on 2026-05-13. The `SimpleSpawner.gd` debug timer is now only created when `debug_logging` is enabled, `_print_debug()` returns early otherwise, and remaining noisy gameplay prints were removed from mod activation, map generation, scene changes, and weapon detach/spawn paths.

Previous example in `SimpleSpawner.gd`:

```gdscript
func _print_debug():
    var wck = mapSource.getWaterCells()
    print(wck.size())
    print(_calculate_spawn_rate(...))
```

Recommended approach:

```gdscript
@export var debug_logging := false

func _print_debug():
    if not debug_logging:
        return
    ...
```

Or remove the timer entirely for release builds.

Benefits:

- Cleaner output.
- Less runtime overhead.
- Easier profiling.

### 13. Consider pooling enemies, gems, and weapon hitboxes

Not urgent, but survivor-style games spawn many entities.

Potential pool targets:

- enemies
- gems
- weapon areas/projectiles
- temporary effects

Benefits:

- Lower allocation churn.
- Better performance under high enemy counts.

## Scene and project cleanup

### 14. Resave scenes/resources in the Godot 4 editor

Godot still reports some non-fatal warnings for old converted resources.

Recommended:

- Open affected scenes/resources in Godot 4.
- Inspect and resave:
  - `levels/default.tscn`
  - `global/SceneChanger.tscn`
  - `prefabs/FlashShader.tres`
  - `theme_gui.tres`

Benefits:

- Clears deprecated material/shader parameter warnings where possible.
- Updates resource serialization to modern Godot 4 format.

### 15. Decide what to commit or ignore from generated files

Status: done on 2026-05-13. `.gitignore` now keeps `.godot/` ignored, allows Godot 4 `.gd.uid` files to be committed, and allows `*.import` files to be committed for reproducible import settings.

During conversion, Godot generated:

- `.gd.uid` files
- many updated `.import` files
- `.godot/` cache files

Recommended:

- Commit `.gd.uid` files and `.import` files if they are part of the converted project state.
- Do not commit `.godot/` unless there is a specific reason.
- Ensure `.gitignore` reflects the intended policy.

### 16. Add a small debug/profiling overlay

A simple in-game debug overlay would help future tuning.

Useful metrics:

- FPS
- enemy count
- gem count
- water frontier size
- spawn interval
- pathfinding update time
- TileMap terrain update time

Possible implementation:

- Add a `CanvasLayer` debug panel.
- Toggle with a key, e.g. F3.
- Use `Performance.get_monitor(...)` and project-specific counters.

## Suggested refactor order

1. Create a real Godot 4 TileSet resource for `assets/tiles_map.png`.
2. Convert TileMap nodes to `TileMapLayer`.
3. Simplify `MapGenerator.gd` by removing runtime TileSet construction.
4. Move procedural generation to pure data arrays, then render in batches.
5. Optimize water frontier storage to avoid repeated `.keys()` and array rebuilding.
6. Convert enemy movement to `CharacterBody2D`, if deterministic movement is preferred.
7. Replace ad-hoc exported paths with typed `@export` / `@onready` references.
8. Move stats, weapons, and mods into typed `Resource` classes.
9. Remove debug print timers or guard them behind exported debug flags.
10. Add an in-game profiling/debug overlay.

## Notes

The current converted project is a working bridge from Godot 3 to Godot 4. The main goal of the next pass should be to reduce bridge code and shift systems toward native Godot 4 workflows, especially around TileSet terrains, TileMapLayer nodes, typed script references, and Resource-based game data.
