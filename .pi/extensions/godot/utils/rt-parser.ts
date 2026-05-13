// pi-godot: [RT:*] output parser for godot-runtime-test
//
// Parses stdout from godot-runtime-test runs into structured results.
// Output format: [RT:TYPE] message

export type RtLineType =
  | "ok"
  | "err"
  | "pass"
  | "fail"
  | "print"
  | "change"
  | "signal"
  | "wait"
  | "results"

export type RtLine = {
  type: RtLineType
  message: string
}

export type RtResult = {
  passed: number
  failed: number
  lines: RtLine[]
  summary: string
  exitCode: number
}

const RT_PREFIX = /^\[RT:(OK|ERR|PASS|FAIL|PRINT|CHANGE|SIGNAL|WAIT|RESULTS)\]\s*(.*)$/

function parseType(raw: string): RtLineType {
  switch (raw) {
    case "OK":      return "ok"
    case "ERR":     return "err"
    case "PASS":    return "pass"
    case "FAIL":    return "fail"
    case "PRINT":   return "print"
    case "CHANGE":  return "change"
    case "SIGNAL":  return "signal"
    case "WAIT":    return "wait"
    case "RESULTS": return "results"
    default:        return "results"
  }
}

/**
 * Parse stdout from a godot-runtime-test run.
 * Non-matching lines (engine output, warnings) are silently ignored.
 */
export function parseRtOutput(stdout: string, exitCode: number): RtResult {
  const lines: RtLine[] = []
  let summary = ""

  for (const raw of stdout.split("\n")) {
    const match = raw.match(RT_PREFIX)
    if (!match) continue

    const type = parseType(match[1])
    const message = match[2] ?? ""

    if (type === "results") {
      summary = message
    }

    lines.push({ type, message })
  }

  const passed = lines.filter((l) => l.type === "pass").length
  const failed = lines.filter((l) => l.type === "fail").length

  return { passed, failed, lines, summary, exitCode }
}