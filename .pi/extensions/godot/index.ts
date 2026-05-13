// pi-godot: Extension tool registration
//
// Registers godot_check, godot_test, and godot_scene_info as Pi tools.
// See also the godot SKILL.md for agent-facing documentation.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { Type } from "typebox"

import { godotCheck } from "./check"
import { godotTest } from "./test"
import { godotSceneInfo } from "./scene-info"
import { godotWarnings } from "./warnings"

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "godot_check",
    label: "Godot Check",
    description:
      "Validate GDScript syntax in a Godot project. " +
      "Runs 'godot --check-only' and returns structured errors. " +
      "Use after editing .gd files to catch syntax and type errors.",
    promptSnippet: "godot_check — validate GDScript syntax in a Godot project",
    promptGuidelines: [
      "Use godot_check after editing .gd files to catch syntax errors early.",
      "Pass a project path only if the tool can't auto-detect the project root.",
    ],
    parameters: Type.Object({
      project: Type.Optional(
        Type.String({ description: "Path to Godot project root (auto-detected if omitted)" })
      ),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      try {
        const result = await godotCheck(params.project)
        return {
          content: [
            {
              type: "text" as const,
              text: result.valid
                ? "✅ All scripts valid"
                : `❌ ${result.errors.length} error(s) found\n${result.errors.map((e) => `  ${e.file}:${e.line} — ${e.message}`).join("\n")}`,
            },
          ],
          details: result,
        }
      } catch (err) {
        throw new Error(`godot_check failed: ${(err as Error).message}`)
      }
    },
  })

  pi.registerTool({
    name: "godot_test",
    label: "Godot Test",
    description:
      "Run a Godot scene with runtime test flags. " +
      "Uses the godot-runtime-test addon to set properties, call methods, " +
      "capture signals, and assert expectations — all from the command line. " +
      "Returns structured pass/fail results.",
    promptSnippet: "godot_test — run a scene with CLI runtime test flags",
    promptGuidelines: [
      "Use godot_test to verify scene behavior after code changes.",
      "Flags use --set:Path:prop=value, --call:Path:method:args, --expect:Path:prop=value, --listen:Path:signal, --expect-signal:Path:sig.",
      "Always listen before triggering: --listen must come before --call or --set.",
      "Headless mode is preferred. Pass --no-headless for visual debugging.",
    ],
    parameters: Type.Object({
      scene: Type.String({ description: "Path to the scene file (relative to project root)" }),
      flags: Type.Array(Type.String(), { description: "Runtime test flags (e.g. --set:.:health=50, --expect:.:health=50)" }),
      project: Type.Optional(
        Type.String({ description: "Path to Godot project root (auto-detected if omitted)" })
      ),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      try {
        const result = await godotTest(params.scene, params.flags, params.project)
        const summary = result.failed === 0
          ? `✅ All ${result.passed} assertion(s) passed`
          : `❌ ${result.failed} failed, ${result.passed} passed`
        return {
          content: [
            {
              type: "text" as const,
              text: `${summary}\n${result.lines.map((l) => `  [${l.type.toUpperCase()}] ${l.message}`).join("\n")}`,
            },
          ],
          details: result,
        }
      } catch (err) {
        throw new Error(`godot_test failed: ${(err as Error).message}`)
      }
    },
  })

  pi.registerTool({
    name: "godot_scene_info",
    label: "Godot Scene Info",
    description:
      "Parse a .tscn file to reveal node hierarchy, scripts, signals, and resources. " +
      "No engine runtime needed — reads the text format directly. " +
      "Use to understand scene structure before editing.",
    promptSnippet: "godot_scene_info — parse a .tscn file for node hierarchy and signals",
    promptGuidelines: [
      "Use godot_scene_info before editing a scene to understand its structure.",
      "The result shows the node tree, attached scripts, signal connections, and external resources.",
    ],
    parameters: Type.Object({
      scene: Type.String({ description: "Path to the .tscn file (relative to project root)" }),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      try {
        const result = await godotSceneInfo(params.scene)
        const nodeList = result.nodes
          .map((n) => {
            const indent = "  ".repeat(n.parent.split("/").length)
            return `${indent}${n.name} (${n.type})${n.script ? ` ← ${n.script}` : ""}`
          })
          .join("\n")
        const signalList = result.connections
          .map((c) => `  ${c.from}.${c.signal} → ${c.to}.${c.method}`)
          .join("\n")

        return {
          content: [
            {
              type: "text" as const,
              text: `Scene: ${result.path}\n\nNodes:\n${nodeList}\n\nSignals:\n${signalList || "  (none)"}`,
            },
          ],
          details: result,
        }
      } catch (err) {
        throw new Error(`godot_scene_info failed: ${(err as Error).message}`)
      }
    },
  })

  pi.registerTool({
    name: "godot_warnings",
    label: "Godot Warnings",
    description:
      "Launch Godot and capture runtime warnings/errors while you play. " +
      "Runs the game in normal (visible) mode for N seconds so you can " +
      "interact with it, then auto-closes and reports all captured " +
      "stdout/stderr including runtime warnings, errors, and script errors. " +
      "Use this to find runtime issues that don't appear in static analysis.",
    promptSnippet:
      "godot_warnings — capture runtime warnings by playing the game",
    promptGuidelines: [
      "Use godot_warnings to see runtime warnings/errors that appear during gameplay.",
      "The tool asks the user how long they want to play before launching.",
      "The game launches in a visible window — play normally and the tool auto-closes.",
      "After closing, all captured stdout/stderr warnings and errors are returned.",
    ],
    parameters: Type.Object({
      seconds: Type.Optional(
        Type.Number({
          description:
            "How many seconds to run the game before auto-closing (default: 15)",
        })
      ),
      scene: Type.Optional(
        Type.String({
          description:
            "Path to the scene file (relative to project root, default: main scene)",
        })
      ),
      project: Type.Optional(
        Type.String({ description: "Path to Godot project root (auto-detected if omitted)" })
      ),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      try {
        // Ask the user how long they want to play
        const durationOptions = [
          "10 seconds (Recommended)",
          "30 seconds",
          "Custom amount...",
          "Until I quit (manual)",
        ]

        const selected = await ctx.ui.select(
          "How long should the game window stay open?",
          durationOptions
        )

        let duration: number = 10
        let custom = false

        if (selected === "Until I quit (manual)") {
          duration = 300 // 5 minute cap as safety
          custom = true
        } else if (selected === "Custom amount...") {
          const customInput = await ctx.ui.input(
            "Enter custom duration in seconds",
            "10"
          )
          duration = parseInt(customInput, 10) || 10
          if (duration < 3) duration = 3
          if (duration > 300) duration = 300
        } else if (selected === "30 seconds") {
          duration = 30
        }

        const result = await godotWarnings({
          duration: duration,
          scene: params.scene,
          project: params.project,
        })

        const parts: string[] = []

        if (result.timedOut) {
          if (custom) {
            parts.push("ℹ️  Game window closed (you quit)")
          } else {
            parts.push(`⏱️  Auto-closed after ${duration}s`)
          }
        }

        // Summary
        const summary: string[] = []
        if (result.errorCount > 0) {
          summary.push(`❌ ${result.errorCount} error(s)`)
        }
        if (result.warningCount > 0) {
          summary.push(`⚠️ ${result.warningCount} warning(s)`)
        }
        if (summary.length === 0) {
          summary.push("✅ No warnings or errors captured")
        }
        parts.push(summary.join(", "))

        // Detail lines
        if (result.lines.length > 0) {
          const detailLines = result.lines.map((l) => {
            const icon = l.severity === "ERROR" || l.severity === "SCRIPT ERROR" ? "❌" : "⚠️"
            return `  ${icon} [${l.severity}] ${l.message}`
          })
          parts.push("")
          parts.push(detailLines.join("\n"))
        }

        return {
          content: [{ type: "text" as const, text: parts.join("\n") }],
          details: result,
        }
      } catch (err) {
        throw new Error(`godot_warnings failed: ${(err as Error).message}`)
      }
    },
  })
}