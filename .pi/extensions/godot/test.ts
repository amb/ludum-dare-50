// pi-godot: godot_test — runtime testing via godot-runtime-test addon
//
// Runs a scene with CLI test flags using the godot-runtime-test addon,
// then parses the [RT:*] output into structured results.
//
// Requires the runtime-test addon installed at addons/runtime_test/
// in the target Godot project.

import { execSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { join, resolve } from "node:path"

import { resolveProject, resolveGodotBinary } from "./utils/godot-path"
import { parseRtOutput, type RtLine, type RtResult } from "./utils/rt-parser"

export type TestResult = {
  passed: number
  failed: number
  lines: RtLine[]
  summary: string
  exitCode: number
}

/**
 * Run runtime tests on a scene using the godot-runtime-test addon.
 *
 * @param scene - Path to the scene file (relative to project root)
 * @param flags - Array of runtime test flags (e.g. "--set:.:health=50", "--expect:.:health=50")
 * @param project - Path to project root (auto-detected if omitted)
 */
export async function godotTest(
  scene: string,
  flags: string[],
  project?: string
): Promise<TestResult> {
  const projectDir = resolveProject(project)
  const godot = resolveGodotBinary()

  // Verify the runtime-test addon is installed and its autoload is registered
  const addonPath = join(projectDir, "addons", "runtime_test", "plugin.cfg")
  if (!existsSync(addonPath)) {
    throw new Error(
      "Runtime test addon not found. Install it:\n" +
        `  cp -r .pi/skills/godot-runtime-test/addon addons/runtime_test\n` +
        "Then enable it in Project Settings → Plugins and open the project in the editor so the autoload is registered."
    )
  }

  // Check that the RuntimeTest autoload is registered in project.godot
  const projectCfg = readFileSync(join(projectDir, "project.godot"), "utf8")
  if (!projectCfg.includes('RuntimeTest="*res://addons/runtime_test/runtime_test.gd"')) {
    throw new Error(
      "RuntimeTest autoload not found in project.godot. " +
      "Open the project in the Godot editor with the runtime-test plugin enabled, " +
      "or manually add this line to the [autoload] section:\n" +
      '  RuntimeTest="*res://addons/runtime_test/runtime_test.gd"'
    )
  }

  // Build the full scene path
  const scenePath = scene.startsWith("/") ? scene : resolve(projectDir, scene)

  // Assemble flags
  // Godot flags go before "--". Runtime-test flags (containing a colon, e.g. --set:.:health=50)
  // go after "--" so the addon receives them via OS.get_cmdline_user_args().
  const godotFlags: string[] = []
  const rtFlags: string[] = []

  for (const flag of flags) {
    // Runtime-test flags all contain a colon in the flag name (--set:, --expect:, --listen:, etc.)
    // Everything else is a Godot engine flag (--headless, --quit, etc.)
    if (flag.startsWith("--") && flag.includes(":")) {
      rtFlags.push(flag)
    } else {
      godotFlags.push(flag)
    }
  }

  // Default to headless (preferred for automation), unless user explicitly opts out
  const noHeadless = godotFlags.includes("--no-headless")
  if (noHeadless) {
    godotFlags.splice(godotFlags.indexOf("--no-headless"), 1)
  } else if (!godotFlags.includes("--headless")) {
    godotFlags.unshift("--headless")
  }

  // Run godot with the runtime-test flags after "--" separator
  const rtPart = rtFlags.length > 0 ? " -- " + rtFlags.join(" ") : ""
  const cmd = `"${godot}" --path "${projectDir}" ${godotFlags.join(" ")} "${scenePath}"${rtPart} 2>&1`

  try {
    const stdout = execSync(cmd, {
      encoding: "utf8",
      stdio: "pipe",
      timeout: 30_000, // 30s timeout for testing
    })

    return parseRtOutput(stdout, 0)
  } catch (err) {
    const stderr = (err as { stderr?: string }).stderr ?? ""
    const stdout = (err as { stdout?: string }).stdout ?? ""
    const exitCode = (err as { status?: number }).status ?? 1
    const output = stdout || stderr || (err as Error).message

    return parseRtOutput(output, exitCode)
  }
}