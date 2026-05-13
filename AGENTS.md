# Agent Tooling Guide

Notes for AI agents working in this project on which CLI tools work reliably.

- **`README.md`** — Project entry point. Start here for project structure and tool overview.
- **`.pi/`** — Contains pi coding agent extensions (`extensions/godot/`) and skills (`skills/godot/SKILL.md`). Tools: `godot_check`, `godot_test`, `godot_scene_info`, `godot_warnings`.

## 1. `read` vs `tilth`

- **`read`** — Not available as a standalone tool. Use `tilth` instead.
- **`tilth`** — AST-aware code reader. Preferred for reading files, finding symbol definitions, and searching code. Supports:
  - File paths: `tilth path/to/file.ts`
  - Symbol lookup: `tilth symbolName`
  - Glob patterns: `tilth "*.gd"`
  - Text search: `tilth "some text"`
  - Regex search: `tilth "/pattern/"`
  - Multi-symbol: `tilth "foo, bar, baz"`
  - Pass `map=true` for project orientation

## 2. RTK command interception

[RTK](https://github.com/rtk-ai/rtk) (`rtk 0.39.0`) is installed and proxies common CLI commands
to optimize output for LLM context windows (fewer tokens, less noise).

| You type | RTK rewrites to | Notes |
|----------|-----------------|-------|
| `cat <file>` | `rtk read <file>` | Token-optimized file output |
| `ls` | `rtk ls` | Compact directory listing |
| `grep` | `rtk grep` | RTK's own grep implementation |
| `rg` | `rtk grep` | Proxies ripgrep — use `tilth` for AST-aware text search instead |
| `find` | `rtk find` | RTK's own find |
| `which` | *(passthrough)* | Not intercepted |

RTK is designed to reduce token usage — trust its output compression. If you need the
full raw output of a command, prefer `tilth` for file reading and code search instead,
as tilth operates outside the shell and isn't intercepted.

## Quick reference

| Task | Preferred tool |
|------|----------------|
| Read a file | `tilth path/to/file` |
| Search for text | `tilth "pattern"` or `rg "pattern"` |
| Find symbol definition | `tilth symbolName` |
| List directory | `ls` or `tilth "*.gd"` |
| File stats | `wc -l`, `stat` |
| Capture runtime warnings | `godot_warnings` — asks you how long to play, runs game visibly, reports stdout/stderr |