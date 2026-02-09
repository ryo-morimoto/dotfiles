#!/usr/bin/env node

/**
 * Stop Hook: Session Summary Generation
 *
 * Reads .tool-history.json, aggregates error/retry/correction stats,
 * generates a session summary entry if thresholds are met,
 * clears the history, and reminds about unanalyzed entries.
 */

import { readFileSync, writeFileSync, readdirSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const HOME = process.env.HOME || process.env.USERPROFILE;
const DATA_DIR = join(HOME, ".claude", "si", "data");
const ENTRIES_DIR = join(DATA_DIR, "entries");
const REPORTS_DIR = join(DATA_DIR, "reports");
const HISTORY_FILE = join(DATA_DIR, ".tool-history.json");

function ensureDirs() {
  mkdirSync(ENTRIES_DIR, { recursive: true });
  mkdirSync(REPORTS_DIR, { recursive: true });
}

function readHistory() {
  try {
    return JSON.parse(readFileSync(HISTORY_FILE, "utf-8"));
  } catch {
    return [];
  }
}

function clearHistory() {
  writeFileSync(HISTORY_FILE, "[]");
}

function countEntries() {
  try {
    const files = readdirSync(ENTRIES_DIR).filter((f) => f.endsWith(".md"));
    return files.length;
  } catch {
    return 0;
  }
}

function countReports() {
  try {
    return readdirSync(REPORTS_DIR).filter((f) => f.endsWith(".md")).length;
  } catch {
    return 0;
  }
}

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  let payload;
  try {
    payload = JSON.parse(input);
  } catch {
    return;
  }

  ensureDirs();
  const history = readHistory();

  if (history.length === 0) {
    return;
  }

  // Aggregate stats
  const stats = {
    totalCalls: history.length,
    errors: history.filter((h) => h.hadError).length,
    retries: history.filter((h) => h.hadRetry).length,
    corrections: history.filter((h) => h.hadCorrection).length,
  };

  // Threshold check: only generate summary if there's something notable
  if (stats.errors === 0 && stats.retries === 0 && stats.corrections === 0) {
    clearHistory();
    return;
  }

  // Group errors by tool
  const errorsByTool = {};
  const retryByTool = {};
  const correctionsByFile = {};

  for (const entry of history) {
    if (entry.hadError) {
      errorsByTool[entry.toolName] = (errorsByTool[entry.toolName] || 0) + 1;
    }
    if (entry.hadRetry) {
      retryByTool[entry.toolName] = (retryByTool[entry.toolName] || 0) + 1;
    }
    if (entry.hadCorrection) {
      const file =
        entry.toolInput?.file_path ||
        entry.toolInput?.path ||
        entry.toolInput?.file ||
        "unknown";
      correctionsByFile[file] = (correctionsByFile[file] || 0) + 1;
    }
  }

  // Generate summary entry
  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10);
  const sessionId = (payload.session_id || "unknown").slice(0, 8);
  const filename = `${dateStr}-session-${sessionId}.md`;
  const filepath = join(ENTRIES_DIR, filename);

  const errorSection =
    stats.errors > 0
      ? `## Errors Encountered\n${Object.entries(errorsByTool)
          .map(([tool, count]) => `- \`${tool}\`: ${count} error(s)`)
          .join("\n")}\n`
      : "";

  const retrySection =
    stats.retries > 0
      ? `## Retry Patterns\n${Object.entries(retryByTool)
          .map(([tool, count]) => `- \`${tool}\`: ${count} retry pattern(s)`)
          .join("\n")}\n`
      : "";

  const correctionSection =
    stats.corrections > 0
      ? `## Corrections\n${Object.entries(correctionsByFile)
          .map(([file, count]) => `- \`${file}\`: ${count} correction(s)`)
          .join("\n")}\n`
      : "";

  const content = `---
date: "${dateStr}"
category: session-summary
tags: [auto-collected]
source: stop-hook
stats: { errors: ${stats.errors}, retries: ${stats.retries}, corrections: ${stats.corrections}, total_calls: ${stats.totalCalls} }
---
# Session Summary (${sessionId})
${errorSection}
${retrySection}
${correctionSection}
## Stats
- Total tool calls: ${stats.totalCalls}
- Errors: ${stats.errors}
- Retry patterns: ${stats.retries}
- Corrections: ${stats.corrections}
`;

  writeFileSync(filepath, content);
  clearHistory();

  // Check for unanalyzed entries and remind
  const totalEntries = countEntries();
  const totalReports = countReports();

  const result = {};
  if (totalEntries >= 10 && totalReports === 0) {
    result.additionalContext = `[Self-Improvement] ${totalEntries} unanalyzed entries in .si/data/entries/. Consider running /improve-analyze.`;
  } else if (totalEntries >= 10) {
    result.additionalContext = `[Self-Improvement] ${totalEntries} entries accumulated. Consider running /improve-analyze for fresh insights.`;
  }

  if (Object.keys(result).length > 0) {
    process.stdout.write(JSON.stringify(result));
  }
}

main().catch(() => {});
