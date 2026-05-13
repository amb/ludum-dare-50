# Survivor Island

Ludum Dare 50 entry built with Godot 4.6.

## Project Structure

| Directory    | Purpose                           |
|--------------|-----------------------------------|
| `.pi/`       | Pi coding agent extensions & skills (godot_check, godot_test, godot_scene_info) |
| `scenes/`    | `.tscn` scene files               |
| `scripts/`   | `.gd` GDScript files              |
| `levels/`    | Level scenes                      |
| `prefabs/`   | Reusable scene components         |
| `global/`    | Autoloaded singletons (SceneChanger, AudioManager, AssetLoader) |
| `assets/`    | Textures, fonts, and other assets |
| `audio/`     | Music and sound effects           |
| `addons/`    | Godot plugins                     |
| `weapons/`   | Weapon scenes and scripts         |
| `resources/` | Resource files                    |
| `locale/`    | Localization / translation files  |

Main scene: `global/SceneChanger.tscn`

## pi-godot Extension Tools

This project includes a local `.pi/` installation of **pi-godot** — a set of Pi coding agent extensions for Godot development. These tools provide:

- **`godot_check`** — Validate GDScript syntax via `godot --check-only`
- **`godot_test`** — Run scenes with runtime test flags (requires `godot-runtime-test` addon with autoload registered)
- **`godot_scene_info`** — Parse `.tscn` files for node hierarchy, scripts, and signals

### ⚠️ Runtime Test Addon: Autoload Required

The `godot-runtime-test` addon needs **both** the addon files *and* an autoload entry in `project.godot`:
```ini
RuntimeTest="*res://addons/runtime_test/runtime_test.gd"
```
This is written automatically when you open the project in the Godot editor with the plugin
enabled (Plugins → Godot Runtime Test). Adding the files alone is not sufficient.

See the skill documentation at `.pi/skills/godot/SKILL.md` for usage details.

## Development

The pi-godot extension source lives at [`~/Code/godot/agent/`](../agent/).  
The delivery plan and package manifest are maintained there.  
Edits to the `.pi/` directory here should be mirrored back to that source project.

## Requirements

- Godot 4.6+ on PATH (`brew install godot` or download from [godotengine.org](https://godotengine.org))
- pi coding agent (npm package `@earendil-works/pi-coding-agent`)