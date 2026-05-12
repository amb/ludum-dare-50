# Godot 3.x to Godot 4 Conversion Report

Date: 2026-05-12
Project: `ludum-dare-50` / `Survivor Island`
Target engine used: Godot `4.6.2.stable.official.71f334935`

## Summary

This project was converted from Godot 3.x to Godot 4.x using Godot's built-in conversion tool, followed by manual fixes for GDScript, scene resources, imports, audio, TileMap usage, physics APIs, and runtime errors.

The converted project currently passes:

```bash
godot --headless --path . --check-only --quit
```

with **0 errors**, and a short headless runtime smoke test also reports **0 errors**.

## Automated conversion

Ran Godot's built-in conversion command:

```bash
godot --headless --path . --convert-3to4
```

This updated many scene/resource/script references automatically, including common Godot 3 to Godot 4 renames such as:

- `KinematicBody2D` style conversion to `CharacterBody2D` where applicable.
- `Sprite` to `Sprite2D`.
- `instance()` to `instantiate()`.
- Signal connection syntax updates.
- Basic resource format updates.
- Import metadata format updates.

## Script migration work

### General GDScript syntax/API updates

Updated project scripts for Godot 4 syntax and APIs, including:

- `onready` -> `@onready`.
- `export` -> `@export`.
- Fixed exported `NodePath` variables that Godot 4 inferred too strictly by removing incorrect static `NodePath` typing where the variable is later replaced by a node instance.
- Replaced `Array.invert()` with `Array.reverse()`.
- Replaced removed `update()` calls with `queue_redraw()`.
- Replaced old `OS` time calls with `Time`:
  - `OS.get_ticks_msec()` / `OS.get_system_time_msecs()` -> `Time.get_ticks_msec()`.
- Updated old file API usage:
  - `File.new()` -> `FileAccess.open()`.
- Adjusted JSON parsing code to match Godot 4 behavior.

Affected script areas include:

- `global/AssetLoader.gd`
- `global/AudioManager.gd`
- `global/SceneChanger.gd`
- `scripts/ButtonGenerate.gd`
- `scripts/Follower.gd`
- `scripts/LevelPopup.gd`
- `scripts/MapGenerator.gd`
- `scripts/ModManager.gd`
- `scripts/PathFinder.gd`
- `scripts/Player.gd`
- `scripts/Root.gd`
- `scripts/SimpleSpawner.gd`
- `scripts/TrackTarget.gd`
- `prefabs/Enemy.gd`
- `prefabs/Gem.gd`
- `weapons/Weapon.gd`

### Physics API updates

Updated Godot 3 physics calls to Godot 4 equivalents:

- Replaced old positional `intersect_ray(from, to, exclude, mask)` calls with `PhysicsRayQueryParameters2D.create(...)` and `direct_space_state.intersect_ray(query)`.
- Updated `RigidBody2D` usage in `prefabs/Enemy.gd`:
  - Removed old `mode = MODE_CHARACTER` usage.
  - Used `lock_rotation = true` for rotation locking.
  - Replaced sleep/wake mode manipulation with Godot 4 `freeze` / `freeze_mode` style logic.
  - Replaced invalid `applied_force` usage with `constant_force`.
- Removed obsolete `RigidBody2D.test_motion()` usage that no longer exists in Godot 4.
- Deferred enemy loot spawning with `call_deferred("add_child", ...)` to avoid physics query flush errors.

### Tween migration

Migrated `prefabs/Gem.gd` from the old Godot 3 `Tween` node API to Godot 4's `create_tween()` API:

- Removed use of `Tween.follow_property()`.
- Replaced it with `create_tween().tween_property(...)`.
- Awaited `tween.finished` instead of old tween completion signals.
- Removed the obsolete `Tween` node and `tween_all_completed` connection from `prefabs/Gem.tscn`.

### Audio playback changes

Updated script references to keep using `.sfxr` files through the Godot 4 `gdfxr` importer.

Initially, placeholder `.wav` files were generated to unblock loading, but after confirming the original project used the Godot 3 `gdfxr`/sfxr extension, that approach was replaced with proper Godot 4 `.sfxr` support.

Current audio behavior:

- `.sfxr` files remain the canonical audio source files in `audio/`.
- Godot imports them as `AudioStreamWAV` resources through `addons/gdfxr`.
- Runtime code continues to call paths like `res://audio/enemy_die.sfxr`.

## gdfxr / sfxr importer migration

The original Godot 3 project depended on a Godot sfxr importer/editor plugin.

Work done:

- Added the Godot 4 branch of `gdfxr` under:

```text
addons/gdfxr/
```

- Re-enabled the plugin in `project.godot`.
- Removed stale missing plugin references from `project.godot`:
  - `res://addons/CollisionPolygonShape/plugin.cfg`
  - `res://addons/kanban_tasks/plugin.cfg`
- Removed stale global script class entries that referenced missing `CollisionPolygonShape` addon files.
- Regenerated `.sfxr.import` files for all files in `audio/`.
- Patched the imported Godot 4 `gdfxr` plugin to fix a property-name bug:
  - `sfxre_type` -> `wave_type`

This allowed `.sfxr` files to import cleanly as `AudioStreamWAV` in Godot 4.

## TileMap migration work

Godot 4's TileMap API changed significantly. `scripts/MapGenerator.gd` and `scripts/PathFinder.gd` were manually updated.

### `scripts/MapGenerator.gd`

Added compatibility helper methods:

- `_set_cell(tmap, x, y, tile_id, atlas_coords = Vector2i(-1, -1))`
- `_get_cell(tmap, x, y)`

These wrap Godot 4's layer-based TileMap API:

- `set_cell(0, Vector2i(...), source_id, atlas_coords)`
- `erase_cell(0, Vector2i(...))`
- `get_cell_source_id(0, Vector2i(...))`

Other changes:

- Replaced `cell_size` with `tile_set.tile_size`.
- Replaced removed TileMap update methods such as:
  - `update_dirty_quadrants()`
  - `update_bitmask_region()`
  - `fix_invalid_tiles()`
- Used `force_update(0)` where needed.
- Added a runtime Godot 4 `TileSet` builder for `assets/tiles_map.png`, because the Godot 3 autotile resource did not convert into usable Godot 4 terrain/autotile data.
- Recreated atlas sources for tile IDs used by the generator:
  - `0`: water
  - `1`: dirt/base tile
  - `2`: grass/vegetation
  - `3`: alternate terrain set from the original atlas
  - `4`: room/floor tiles
  - `5`: walls/blocking tiles
- Added manual atlas-coordinate selection to approximate the original Godot 3 autotile behavior.
- Recreated Godot 3-style bitmask handling:
  - Water/walls use 3x3-minimal style bitmasking.
  - Grass/vegetation (`tile_id == 2`) uses a separate 2x2 quadrant bitmask path, matching its original `bitmask_mode = 0` data.
- Fixed grass fallback selection so unmatched/single grass pieces use a grass-looking tile instead of a broken corner atlas tile.
- Added runtime collision polygons to blocking generated tiles:
  - water (`tile_id == 0`)
  - walls/blocking (`tile_id == 5`)
- Corrected Godot 4 TileData collision polygon coordinates to be centered on the tile (`-8..8`) instead of `0..16`, which had shifted wall collision about half a tile down/right.

### Window, camera, and input adjustments

After launching the converted project visually, several usability issues were fixed:

- Set the logical viewport back to `1280x720` so CanvasLayer/UI text scales correctly.
- Added macOS high-resolution window override size:
  - `window/size/window_width_override=2560`
  - `window/size/window_height_override=1440`
- Adjusted the gameplay camera zoom so the visible map area is close to the original intended scale while keeping the physical window large.
- Added quit shortcuts in `scripts/Root.gd`:
  - `Esc` / `ui_cancel`
  - `Q`

### `scripts/PathFinder.gd`

Updated TileMap pathfinding code:

- Replaced `cell_size` with `tile_set.tile_size`.
- Replaced old `get_cell(...)` usage with Godot 4 `get_cell_source_id(...)`.
- Simplified blocker detection to treat occupied cells in pathfinding collision maps as blocking, since Godot 4's TileSet collision shape APIs differ from Godot 3.
- Updated raycast pruning logic to use Godot 4 `PhysicsRayQueryParameters2D`.

## Scene/resource updates

Godot's converter and manual edits updated the following scene/resource areas:

- `global/SceneChanger.tscn`
- `levels/default.tscn`
- `prefabs/Enemy.tscn`
- `prefabs/Gem.tscn`
- `theme_gui.tres`
- `prefabs/FlashShader.tres`

Notable scene updates:

- Audio stream references in `levels/default.tscn` point back to `.sfxr` files.
- Removed obsolete Tween node from `prefabs/Gem.tscn`.
- Godot 4 scene/resource format conversion was applied by the engine.

## Asset/import regeneration

Godot 4 import metadata was regenerated for images, fonts, sfxr audio, and other imported assets.

This produced updated `.import` files across many asset folders, including:

- `assets/`
- `assets/pixel_icons/`
- `assets/fonts/`
- `weapons/textures/`
- `audio/*.sfxr.import`

Godot also generated `.gd.uid` files for scripts, which is expected in modern Godot 4 projects.

## Validation performed

### Check-only validation

Command:

```bash
godot --headless --path . --check-only --quit
```

Result:

```text
0 ERROR / SCRIPT ERROR lines
```

### Runtime smoke test

Command pattern used:

```bash
godot --headless --path .
# allowed to run for roughly 5 seconds, then terminated
```

Result:

```text
0 ERROR / SCRIPT ERROR lines
```

The runtime smoke test exercised startup, autoloads, scene changing, map generation, player/enemy setup, weapon damage, gem drops, sfxr audio imports, and early gameplay logic without fatal errors.

Additional visual/runtime checks were performed by launching the game repeatedly in a normal Godot window. These checks led to fixes for:

- tiny initial window size
- over-zoomed/under-zoomed camera scale
- CanvasLayer/UI text appearing too small on macOS high-DPI display
- missing generated TileMap visuals
- broken water/grass/wall atlas selection
- missing TileMap collision
- shifted wall collision polygons
- missing keyboard quit shortcut

## Remaining warnings / follow-up work

The project still has non-fatal Godot 4 warnings that should be reviewed in the editor:

### TileSet/autotile warning

Godot reports that Godot 3 autotiles could not be automatically converted to Godot 4 terrain sets.

Current mitigation:

- `scripts/MapGenerator.gd` now builds a runtime atlas TileSet and manually recreates the important Godot 3 bitmask behavior for generated maps.
- Runtime collision polygons are generated for water and wall/blocking tiles.

Follow-up:

- Open the project in the Godot 4 editor.
- Review TileSet resources visually.
- Rebuild any terrain/autotile rules using Godot 4's native terrain system if long-term editor-driven TileSet editing is desired.
- Continue visual QA on grass corner/edge cases; the runtime 2x2 bitmask emulation is close but may still differ slightly from Godot 3's exact autotile selection in rare patterns.

### Deprecated material/shader parameter warnings

Godot reports deprecated parameter names on some converted materials/shaders, including resources embedded in:

- `prefabs/FlashShader.tres`
- `levels/default.tscn`
- `global/SceneChanger.tscn`

Follow-up:

- Open and re-save the affected scenes/resources in the Godot 4 editor.
- Verify shader behavior visually.

### Gameplay balance / behavior review

The migration focused on restoring loadability and runtime correctness. Some behavior may still need visual/manual testing:

- TileMap terrain appearance and collisions.
- Enemy pathfinding accuracy after TileMap API changes.
- sfxr sound parity versus Godot 3.
- UI layout and font rendering.
- Shader transition effects.

## Important implementation notes

- The `.sfxr` files are preserved and imported with the Godot 4 `gdfxr` plugin. They were not permanently converted to WAV.
- The added `addons/gdfxr` plugin is required for loading `.sfxr` audio resources.
- The patch from `sfxre_type` to `wave_type` in `addons/gdfxr` is intentional and required for the imported plugin to process this project's `.sfxr` files successfully.
- The runtime TileSet builder in `scripts/MapGenerator.gd` is intentional. It compensates for Godot 4 not converting the original Godot 3 autotile definitions into working terrain data.
- Tile collision polygons are added after the atlas source is attached to the TileSet; adding them before the source is registered caused Godot 4 physics-layer index errors.
- TileData collision polygon points are centered around the tile origin in Godot 4, so full-tile collision uses `(-8, -8)` to `(8, 8)`, not `(0, 0)` to `(16, 16)`.
- Godot 4 import metadata and `.gd.uid` files should generally be committed with the converted project.

## Final status

The Godot 4 conversion is functionally bootstrapped:

- Project imports in Godot 4.
- Scripts parse successfully.
- Main scene loads.
- Short headless runtime smoke test succeeds.
- `.sfxr` audio works through the Godot 4 `gdfxr` plugin.

Recommended next step: open the project in the Godot 4 editor and perform visual/gameplay QA, especially around TileMap terrain conversion, grass edge/corner selection, generated tile collision, and shader/material warnings.
