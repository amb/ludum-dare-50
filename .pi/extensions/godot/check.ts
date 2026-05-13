// pi-godot: godot_check — syntax validation via godot --check-only
//
// Runs the Godot engine's built-in script parser across the entire project
// and returns structured error results. No daemon or server needed.

import { execSync } from "node:child_process"

import { resolveProject, resolveGodotBinary } from "./utils/godot-path"

export type CheckError = {
  file: string
  line: number
  message: string
}

export type CheckResult = {
  valid: boolean
  errors: CheckError[]
}

/**
 * Parse Godot SCRIPT ERROR lines from --check-only output.
 *
 * Godot 4.6.2 format (exits 0 even on errors):
 *   SCRIPT ERROR: <Category>: <message>
 *             at: GDScript::reload (res://path/file.gd:LINE)
 *   
 *   ERROR: Failed to load script "res://path/file.gd" with error "<category>".
 *      at: load (modules/gdscript/gdscript.cpp:2907)
 */
function parseErrors(output: string): CheckError[] {
  const errors: CheckError[] = []
  const lines = output.split("\n")

  // Match SCRIPT ERROR lines and their trailing "at:" line
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    // SCRIPT ERROR: Parse Error: Cannot assign a value...
    //   at: GDScript::reload (res://path/file.gd:LINE)
    const scriptErrorMatch = line.match(/^SCRIPT ERROR: ([^:]+):\s*(.*)$/)
    if (scriptErrorMatch) {
      const category = scriptErrorMatch[1].trim()
      const message = scriptErrorMatch[2].trim()

      // Look at next line for "at:" with file location
      const nextLine = lines[i + 1]
      if (nextLine) {
        const atMatch = nextLine.match(/\(res:\/\/(\S+?):(\d+)\)/)
        if (atMatch) {
          errors.push({
            file: "res://" + atMatch[1],
            line: parseInt(atMatch[2], 10),
            message: `${category}: ${message}`,
          })
        } else {
          // Error with no file location (unlikely for script errors)
          errors.push({
            file: "unknown",
            line: 0,
            message: `${category}: ${message}`,
          })
        }
      }
      continue
    }
  }

  return errors
}

/**
 * Run godot --check-only on a project and return structured results.
 *
 * Note: Godot 4.6.2 exits with code 0 even when parse errors are found.
 * Errors are reported on stderr in SCRIPT ERROR format. We always
 * parse the output regardless of exit code.
 *
 * @param project - Path to project root (auto-detected if omitted)
 */
export async function godotCheck(project?: string): Promise<CheckResult> {
  const projectDir = resolveProject(project)
  const godot = resolveGodotBinary()

  const output = execSync(`"${godot}" --check-only --quit --path "${projectDir}" 2>&1`, {
    encoding: "utf8",
    stdio: "pipe",
  })

  const errors = parseErrors(output)
  return { valid: errors.length === 0, errors }
}