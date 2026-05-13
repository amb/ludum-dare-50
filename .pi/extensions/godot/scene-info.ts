// pi-godot: godot_scene_info — parse .tscn files for node hierarchy, scripts, signals
//
// No engine runtime needed. The .tscn format is a plain text scene tree format.
// See: https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html

import { readFileSync } from "node:fs"
import { resolve } from "node:path"

import { resolveProject } from "./utils/godot-path"

export type SceneNode = {
  name: string
  type: string
  parent: string
  script?: string
  children: string[]
}

export type SignalConnection = {
  from: string
  signal: string
  to: string
  method: string
}

export type Resource = {
  id: string
  type: string
  path: string
}

export type SceneInfo = {
  path: string
  nodes: SceneNode[]
  connections: SignalConnection[]
  resources: Resource[]
}

/**
 * Parse a .tscn file and extract its structure.
 *
 * @param scenePath - Path to the .tscn file
 */
export async function godotSceneInfo(scenePath: string): Promise<SceneInfo> {
  const projectDir = resolveProject()
  const absPath = scenePath.startsWith("/")
    ? scenePath
    : resolve(projectDir, scenePath)

  const content = readFileSync(absPath, "utf8")
  const lines = content.split("\n")

  const resources: Resource[] = []
  const nodeLines: string[][] = []
  const connections: SignalConnection[] = []
  let currentNode: string[] | null = null
  let inHeader = true

  for (const raw of lines) {
    const line = raw.trim()

    // Skip header lines before first section
    if (inHeader) {
      if (line.startsWith("[")) inHeader = false
      else continue
    }

    if (line.startsWith("[ext_resource")) {
      // [ext_resource type="Script" path="res://..." id="1"]
      const id = extractQuoted(line, "id")
      const type = extractQuoted(line, "type")
      const path = extractQuoted(line, "path")
      if (id && type && path) resources.push({ id, type, path })
    } else if (line.startsWith("[sub_resource")) {
      // We don't parse sub_resource bodies, but we note them
      continue
    } else if (line.startsWith("[node")) {
      if (currentNode) nodeLines.push(currentNode)
      currentNode = [line]
    } else if (line.startsWith("[connection")) {
      if (currentNode) nodeLines.push(currentNode)
      currentNode = null

      // [connection signal="health_changed" from="Player" to="HealthBar" method="_on_health_changed"]
      const signal = extractQuoted(line, "signal")
      const from = extractQuoted(line, "from")
      const to = extractQuoted(line, "to")
      const method = extractQuoted(line, "method")
      if (signal && from && to && method) {
        connections.push({ signal, from, to, method })
      }
    } else if (line.startsWith("[editable]")) {
      if (currentNode) nodeLines.push(currentNode)
      currentNode = null
      break // Editable children marker, rest is done
    } else if (currentNode) {
      // Property line within a node
      if (line !== "") currentNode.push(line)
    }
  }

  // Flush last node
  if (currentNode) nodeLines.push(currentNode)

  // Parse nodes
  const nodes: SceneNode[] = []
  const extResourceMap = new Map(resources.map((r) => [r.id, r.path]))

  for (const nl of nodeLines) {
    const header = nl[0]
    const name = extractQuoted(header, "name")
    const type = extractQuoted(header, "type")
    const parent = extractQuoted(header, "parent") || ""
    if (!name || !type) continue

    let script: string | undefined

    // Scan properties for script reference
    for (const prop of nl.slice(1)) {
      const scriptMatch = prop.match(/^script\s*=\s*(.*)$/)
      if (scriptMatch) {
        let val = scriptMatch[1]
        // ExtResource("1") -> look up in resources
        const extMatch = val.match(/^ExtResource\("(\w+)"\)$/)
        if (extMatch) {
          script = extResourceMap.get(extMatch[1])
        } else {
          // Direct path: "res://path/to/script.gd"
          script = val.replace(/^"|"$/g, "")
        }
      }
    }

    nodes.push({
      name,
      type,
      parent,
      script,
      children: [],
    })
  }

  // Build parent-child relationships
  for (const node of nodes) {
    if (node.parent) {
      const parent = nodes.find((n) => n.name === node.parent)
      if (parent) {
        parent.children.push(node.name)
      }
    }
  }

  return {
    path: absPath,
    nodes,
    connections,
    resources: resources.filter((r) => r.type !== ""),
  }
}

/**
 * Extract a quoted attribute value from a bracket section header.
 * e.g. extractQuoted('[node name="Player" type="CharacterBody2D"]', 'name') -> "Player"
 */
function extractQuoted(line: string, attr: string): string | null {
  const re = new RegExp(`${attr}="([^"]*)"`)
  const match = line.match(re)
  return match ? match[1] : null
}