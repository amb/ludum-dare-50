---
name: godot
description: General knowledge about Godot projects — detection, structure, CLI flags, GDScript conventions. Use when working with Godot scenes, scripts, or the engine from the command line.
---

# Godot Project — Agent Knowledge

## Detecting a Godot project

Godot projects are identified by a `project.godot` file at the root. Common subdirectories:

- `scenes/` — `.tscn` scene files (text format, human-readable)
- `scripts/` — `.gd` GDScript files
- `addons/` — plugins and extensions
- `assets/` or `resources/` — textures, audio, models
- `levels/` — level scenes
- `prefabs/` — reusable scene components

The extension tools in this project auto-detect the project root by walking up from the current directory until they find `project.godot`.

## CLI flags (quick reference)

| Flag | Use |
|------|-----|
| `--path <dir>` | Set project directory |
| `--check-only` | Parse all scripts for errors, then quit |
| `--headless` | Run without display (servers, CI, testing) |
| `--scene <path>` | Run a specific scene |
| `--script <path>` | Run a GDScript file directly |
| `--quit` | Quit after first frame |
| `--version` | Print version |

## GDScript conventions

```gdscript
extends <NodeType>       # First line: what node this attaches to

func _ready():           # Called when node enters tree
func _process(delta):    # Called every frame

@export var health: int = 100  # Exported property (editable in inspector)
signal health_changed(value)   # Signal declaration

func take_damage(amount: int) -> void:
    health -= amount
    emit_signal("health_changed", health)

# Node references
get_node("Path/To/Node")
$Path/To/Node              # Shorthand for get_node
```

## Extension tools available

These tools are provided by this skill package:

- `godot_check(project?)` — Validate GDScript syntax. Parses all `.gd` files for errors and returns structured results.
- `godot_test(scene, flags, project?)` — Run a scene with runtime test flags. Returns structured pass/fail results.
- `godot_scene_info(scene)` — Parse a `.tscn` file and return its node hierarchy, scripts, signals, and resources.
- `godot_warnings(seconds?, scene?, project?)` — Prompts you for how long to play, then launches the game in visible mode. After it auto-closes, reports all captured runtime warnings/errors from stdout/stderr.

## Runtime Test Addon Setup

The `godot_test` tool requires the `godot-runtime-test` addon. Two things must be in place:

1. **Files** — `addons/runtime_test/` must exist in the project
2. **Autoload** — `project.godot` must have this line in its `[autoload]` section:
   ```ini
   RuntimeTest="*res://addons/runtime_test/runtime_test.gd"
   ```

   The autoload entry is written automatically when you **open the project in the Godot editor**
   with the plugin enabled (the plugin's `_enter_tree()` calls `add_autoload_singleton()`).
   **Copying the addon files alone is not enough** — the autoload must be registered.

If the tool reports "addon not found" or "autoload not found", run:
```bash
# Copy addon files (one-time setup)
cp -r .pi/skills/godot-runtime-test/addon addons/runtime_test

# Then open the project in the Godot editor and enable the plugin under
# Project → Project Settings → Plugins → Godot Runtime Test

# Or manually add to project.godot's [autoload] section:
#   RuntimeTest="*res://addons/runtime_test/runtime_test.gd"
```