# Godot MCP in Pi

Pi does not include built-in MCP support. The recommended way to use Godot MCP with Pi is to install the community `pi-mcp-adapter` extension, then configure `@coding-solo/godot-mcp` as an MCP server.

This guide is tailored for this project (`ludum-dare-50`, Godot project name: `Survivor Island`).

## Prerequisites

- Godot installed through Homebrew
- Node.js and npm available
- Pi coding agent installed

Homebrew Godot executable path:

```bash
/opt/homebrew/bin/godot
```

Verify local tools:

```bash
which godot
node --version
npm --version
pi --version
```

From this repo, verify Godot can see the project:

```bash
godot --headless --path . --quit
```

## Install Pi MCP adapter

```bash
pi install npm:pi-mcp-adapter
```

Restart Pi after installation, or use:

```text
/reload
```

Pi extensions installed with `pi install` are loaded as Pi packages. If you are developing or testing a local adapter instead, put the extension under one of Pi's auto-discovery locations such as `~/.pi/agent/extensions/` or `.pi/extensions/`, then run `/reload`.

## Add Godot MCP config

Use either a project-local config:

```bash
.mcp.json
```

or a global shared MCP config:

```bash
~/.config/mcp/mcp.json
```

For this repo, the project-local option is easiest because it keeps the Godot project path implicit: start Pi from `/Users/tommi/Code/godot/ludum-dare-50`, and the MCP server will operate on this project.

Recommended `.mcp.json`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "@coding-solo/godot-mcp"],
      "env": {
        "GODOT_PATH": "/opt/homebrew/bin/godot"
      }
    }
  }
}
```

Then reload Pi:

```text
/reload
```

## Smoke test

Open the MCP UI:

```text
/mcp
```

Reconnect the server if needed:

```text
/mcp reconnect godot
```

Ask Pi to call the proxy tool in this order:

```text
mcp({ search: "godot" })
mcp({ describe: "godot_get_godot_version" })
mcp({ tool: "godot_get_godot_version", args: "{}" })
```

Note: `args` is a JSON string, not an object.

A successful version call confirms that:

- `pi-mcp-adapter` loaded
- `@coding-solo/godot-mcp` was launched by `npx`
- `GODOT_PATH` points to a working Godot executable

## Usage in Pi

After the smoke test, ask Pi for the MCP action you want. Good prompts include:

```text
Use Godot MCP to inspect this project's info.
Use Godot MCP to launch the editor for this project.
Use Godot MCP to run the project, read debug output, then stop it.
Use Godot MCP to create a scene named TestScene with a Node2D root.
```

The adapter exposes one proxy tool named `mcp`. The agent can search, describe, and call Godot MCP tools through it.

Example MCP proxy usage pattern:

```text
mcp({ search: "project" })
mcp({ describe: "godot_get_project_info" })
mcp({ tool: "godot_get_project_info", args: "{}" })
```

## Optional: expose Godot tools directly

By default, `pi-mcp-adapter` keeps MCP tools behind the compact `mcp` proxy to avoid filling the context with tool definitions.

If you want Godot tools to appear as first-class Pi tools, enable `directTools`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "@coding-solo/godot-mcp"],
      "env": {
        "GODOT_PATH": "/opt/homebrew/bin/godot"
      },
      "directTools": true
    }
  }
}
```

You can also expose only selected tools:

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "@coding-solo/godot-mcp"],
      "env": {
        "GODOT_PATH": "/opt/homebrew/bin/godot"
      },
      "directTools": [
        "get_godot_version",
        "list_projects",
        "get_project_info",
        "launch_editor",
        "run_project",
        "get_debug_output",
        "stop_project"
      ]
    }
  }
}
```

After changing `directTools`, run:

```text
/mcp reconnect godot
/reload
```

## Useful Godot MCP tools

Godot MCP supports tools such as:

- `launch_editor`
- `run_project`
- `get_debug_output`
- `stop_project`
- `get_godot_version`
- `list_projects`
- `get_project_info`
- `create_scene`
- `add_node`
- `load_sprite`
- `export_mesh_library`
- `save_scene`
- `get_uid`
- `update_project_uids`

Tool names exposed through the Pi proxy may be prefixed with the MCP server name, for example `godot_get_godot_version`. Use `mcp({ search: "..." })` to confirm exact names before calling.

## Recommended workflow for this project

1. Start Pi from the project root:

   ```bash
   cd /Users/tommi/Code/godot/ludum-dare-50
   pi
   ```

2. Confirm MCP is connected:

   ```text
   /mcp
   ```

3. Run the game through MCP when testing gameplay changes:

   ```text
   Use Godot MCP to run the project, capture debug output, and stop the project after the test.
   ```

4. Use normal file edits for scripts/scenes, and MCP for editor/runtime checks.

5. If the editor is already open, save scenes/resources before asking MCP to run or modify them to avoid stale files.

## Troubleshooting

### Godot not found

Set `GODOT_PATH` explicitly:

```json
"env": {
  "GODOT_PATH": "/opt/homebrew/bin/godot"
}
```

### `npx` cannot download or launch the server

Try pre-warming the package from a normal shell:

```bash
npx -y @coding-solo/godot-mcp --help
```

If this fails, fix the npm/network error first, then reload Pi.

### Need debug logs

Add:

```json
"env": {
  "GODOT_PATH": "/opt/homebrew/bin/godot",
  "DEBUG": "true"
}
```

or in your shell before starting Pi:

```bash
export DEBUG=true
```

### MCP tools not visible

Try:

```text
/mcp reconnect godot
```

or restart Pi.

If using `directTools`, the adapter may need to populate its metadata cache first. Run:

```text
/mcp reconnect godot
```

then reload Pi:

```text
/reload
```

### Project does not launch

Verify Godot can run the project outside MCP:

```bash
godot --path .
```

For headless validation:

```bash
godot --headless --path . --quit
```

If Godot reports missing imports, open the project in the editor once and let it reimport assets.

## References

- Godot MCP: https://github.com/Coding-Solo/godot-mcp
- Pi MCP Adapter: https://www.npmjs.com/package/pi-mcp-adapter
- Pi issue discussing MCP extension: https://github.com/earendil-works/pi/issues/563
