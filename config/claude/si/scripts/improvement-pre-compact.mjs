#!/usr/bin/env node

/**
 * PreCompact Hook: Context Preservation
 *
 * Flushes any error patterns from .tool-history.json to entries
 * before compaction loses the context.
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const HOME = process.env.HOME || process.env.USERPROFILE;
const DATA_DIR = join(HOME, ".claude", "si", "data");
const ENTRIES_DIR = join(DATA_DIR, "entries");
const HISTORY_FILE = join(DATA_DIR, ".tool-history.json");

function ensureDirs() {
  mkdirSync(ENTRIES_DIR, { recursive: true });
}

function readHistory() {
  try {
    return JSON.parse(readFileSync(HISTORY_FILE, "utf-8"));
  } catch {
    return [];
  }
}

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  ensureDirs();
  const history = readHistory();

  if (history.length === 0) {
    return;
  }

  // Check if there are any notable patterns worth preserving
  const errors = history.filter((h) => h.hadError);
  const retries = history.filter((h) => h.hadRetry);
  const corrections = history.filter((h) => h.hadCorrection);

  if (errors.length === 0 && retries.length === 0 && corrections.length === 0) {
    return;
  }

  // Flush a pre-compact snapshot entry
  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10);
  const timeStr = now.toISOString().slice(11, 19).replace(/:/g, "");
  const filename = `${dateStr}-${timeStr}-pre-compact-snapshot.md`;
  const filepath = join(ENTRIES_DIR, filename);

  const errorDetails = errors
    .map((e) => `- \`${e.toolName}\` at ${new Date(e.timestamp).toISOString()}`)
    .join("\n");

  const retryDetails = retries
    .map((e) => `- \`${e.toolName}\` at ${new Date(e.timestamp).toISOString()}`)
    .join("\n");

  const correctionDetails = corrections
    .map((e) => {
      const file =
        e.toolInput?.file_path ||
        e.toolInput?.path ||
        e.toolInput?.file ||
        "unknown";
      return `- \`${e.toolName}\` on ${file} at ${new Date(e.timestamp).toISOString()}`;
    })
    .join("\n");

  const content = `---
date: "${dateStr}"
category: pre-compact-snapshot
tags: [auto-collected, pre-compact]
source: pre-compact-hook
stats: { errors: ${errors.length}, retries: ${retries.length}, corrections: ${corrections.length} }
---
# Pre-Compact Snapshot
Flushed before context compaction to preserve error patterns.

${errors.length > 0 ? `## Errors\n${errorDetails}\n` : ""}
${retries.length > 0 ? `## Retry Patterns\n${retryDetails}\n` : ""}
${corrections.length > 0 ? `## Corrections\n${correctionDetails}\n` : ""}
`;

  writeFileSync(filepath, content);
}

main().catch(() => {});
