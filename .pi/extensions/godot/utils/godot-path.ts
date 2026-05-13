// pi-godot: Godot binary and project discovery
//
// Finds the Godot binary via PATH lookup and detects project roots
// by walking up directories looking for project.godot.

import { execSync } from "node:child_process"
import { existsSync } from "node:fs"
import { join, resolve } from "node:path"

/**
 * Find the Godot binary via PATH lookup.
 * Returns the absolute path or null if not found.
 */
export function findGodotBinary(): string | null {
  try {
    const result = execSync("which godot", { encoding: "utf8" })
    const path = result.trim()
    if (path && existsSync(path)) return path
  } catch {
    // Not found on PATH
  }
  return null
}

/**
 * Walk up from startDir looking for project.godot.
 * Returns the project directory (the dir containing project.godot) or null.
 */
export function findProjectRoot(startDir?: string): string | null {
  let dir = startDir ? resolve(startDir) : process.cwd()

  // Walk up until we find project.godot or hit filesystem root
  while (true) {
    if (existsSync(join(dir, "project.godot"))) return dir
    const parent = resolve(dir, "..")
    if (parent === dir) return null // reached filesystem root
    dir = parent
  }
}

/**
 * Resolve a project path argument.
 * Returns the project directory if found, or throws a clear error.
 */
export function resolveProject(project?: string): string {
  if (project) {
    const abs = resolve(project)
    if (!existsSync(join(abs, "project.godot"))) {
      throw new Error(
        `No Godot project found at "${abs}". ` +
        `Expected to find project.godot there.`
      )
    }
    return abs
  }

  const found = findProjectRoot()
  if (!found) {
    throw new Error(
      "No Godot project found. Run this tool from within a Godot project " +
      "or pass a `project` argument pointing to one."
    )
  }
  return found
}

/**
 * Resolve the Godot binary or throw a clear error.
 */
export function resolveGodotBinary(): string {
  const bin = findGodotBinary()
  if (!bin) {
    throw new Error(
      "Godot binary not found. Install Godot and ensure it's on your PATH " +
      "(e.g. 'brew install godot' or download from godotengine.org)."
    )
  }
  return bin
}
