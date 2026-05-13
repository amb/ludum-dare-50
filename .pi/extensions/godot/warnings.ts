// pi-godot: godot_warnings — capture runtime warnings by running the game
//
// Launches Godot in normal (visible) mode so the user can play, while
// capturing all stdout/stderr output in the background. After the
// specified duration, Godot is automatically closed and the captured
// warnings/errors are returned.
//
// This shows what normally appears in the editor's Output/Debugger
// panels during gameplay.

import { spawn } from "node:child_process"
import { resolve } from "node:path"

import { resolveProject, resolveGodotBinary } from "./utils/godot-path"

export type WarningLine = {
  severity: "WARNING" | "ERROR" | "SCRIPT ERROR" | "INFO"
  message: string
}

export type WarningsResult = {
  lines: WarningLine[]
  raw: string
  errorCount: number
  warningCount: number
  exitCode: number | null
  timedOut: boolean
}

/**
 * Parse Godot output lines into structured warning data.
 */
function parseOutput(text: string): WarningLine[] {
  const result: WarningLine[] = []
  const lines = text.split("\n")

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    // SCRIPT ERROR lines (compile-time parse errors)
    const scriptErrorMatch = line.match(/^SCRIPT ERROR:\s*(.*)/)
    if (scriptErrorMatch) {
      let message = scriptErrorMatch[1]
      const nextLine = lines[i + 1]
      if (nextLine && nextLine.includes("res://")) {
        message += `\n  at: ${nextLine.trim()}`
        i++
      }
      result.push({ severity: "SCRIPT ERROR", message })
      continue
    }

    // ERROR: lines (runtime errors)
    const errorMatch = line.match(/^ERROR:\s*(.*)/)
    if (errorMatch) {
      let message = errorMatch[1]
      const nextLine = lines[i + 1]
      if (nextLine && nextLine.trimStart().startsWith("at:")) {
        message += `\n  ${nextLine.trim()}`
        i++
      }
      result.push({ severity: "ERROR", message })
      continue
    }

    // WARNING: lines (runtime warnings)
    const warningMatch = line.match(/^WARNING:\s*(.*)/)
    if (warningMatch) {
      let message = warningMatch[1]
      const nextLine = lines[i + 1]
      if (nextLine && nextLine.trimStart().startsWith("at:")) {
        message += `\n  ${nextLine.trim()}`
        i++
      }
      result.push({ severity: "WARNING", message })
      continue
    }

    // Condition: parsed res:// script errors (sometimes no prefix)
    const parsedErrorMatch = line.match(/res:\/\/.+:\d+.*/)
    if (parsedErrorMatch && (line.includes("error") || line.includes("Error") || line.includes("ERROR"))) {
      result.push({ severity: "ERROR", message: line.trim() })
    }
  }

  return result
}

/**
 * Launch Godot in normal (visible) mode, capture output for the
 * specified duration, then shut down and return captured warnings.
 *
 * The user should play the game during this time to trigger runtime
 * warnings.
 *
 * @param options.duration - Seconds to let the user play (default: 15)
 * @param options.scene - Specific scene to load (default: project main scene)
 * @param options.project - Path to project root (auto-detected if omitted)
 */
export async function godotWarnings(options: {
  duration?: number
  scene?: string
  project?: string
}): Promise<WarningsResult> {
  const projectDir = resolveProject(options.project)
  const godot = resolveGodotBinary()
  const duration = options.duration ?? 15

  const scene = options.scene ?? resolve(projectDir, "levels/default.tscn")

  const args = [
    "--path", projectDir,
    scene,
  ]

  return new Promise((resolvePromise, reject) => {
    const allOutput: string[] = []
    let exitCode: number | null = null
    let timedOut = false
    let killed = false

    const child = spawn(godot, args, {
      stdio: ["ignore", "pipe", "pipe"],
    })

    const timer = setTimeout(() => {
      timedOut = true
      killed = true
      // Graceful shutdown
      child.kill("SIGTERM")
      // Force kill if still alive after 2s
      setTimeout(() => {
        try { if (!child.killed) child.kill("SIGKILL") } catch { /* ignore */ }
      }, 2000)
    }, duration * 1000)

    child.stdout.on("data", (data: Buffer) => {
      allOutput.push(data.toString("utf8"))
    })

    child.stderr.on("data", (data: Buffer) => {
      allOutput.push(data.toString("utf8"))
    })

    child.on("close", (code) => {
      clearTimeout(timer)
      exitCode = code
      const raw = allOutput.join("")
      const parsed = parseOutput(raw)
      const errorCount = parsed.filter((l) => l.severity === "ERROR" || l.severity === "SCRIPT ERROR").length
      const warningCount = parsed.filter((l) => l.severity === "WARNING").length

      resolvePromise({
        lines: parsed,
        raw,
        errorCount,
        warningCount,
        exitCode,
        timedOut,
      })
    })

    child.on("error", (err) => {
      clearTimeout(timer)
      reject(new Error(`Failed to spawn Godot: ${err.message}`))
    })
  })
}