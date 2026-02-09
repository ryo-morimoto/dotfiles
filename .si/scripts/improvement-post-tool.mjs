#!/usr/bin/env node

/**
 * PostToolUse Hook: Error/Retry Detection
 *
 * Detects:
 * - Bash execution with exit code != 0 → category: error
 * - Same tool + similar input 3+ times in short window → category: retry-pattern
 * - Edit/Write on same file consecutively → category: correction
 *
 * Maintains a rolling 50-entry tool history in .tool-history.json
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, "..", "data");
const ENTRIES_DIR = join(DATA_DIR, "entries");
const HISTORY_FILE = join(DATA_DIR, ".tool-history.json");
const MAX_HISTORY = 50;

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

function writeHistory(history) {
  writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
}

function writeEntry(category, data) {
  ensureDirs();
  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10);
  const timeStr = now.toISOString().slice(11, 19).replace(/:/g, "");
  const slug = `${category}-${data.toolName || "unknown"}`.replace(
    /[^a-z0-9-]/gi,
    "-"
  );
  const filename = `${dateStr}-${timeStr}-${slug}.md`;
  const filepath = join(ENTRIES_DIR, filename);

  const tags = [data.toolName, category].filter(Boolean);
  const relatedFiles = data.file ? [data.file] : [];

  const content = `---
date: "${dateStr}"
category: ${category}
tags: [${tags.join(", ")}]
impact: low
status: open
source: post-tool-hook
related_files: [${relatedFiles.map((f) => `"${f}"`).join(", ")}]
---
# ${category}: ${data.toolName || "unknown"}
## What Happened
${data.description || "Detected by PostToolUse hook."}
## Details
- Tool: ${data.toolName || "unknown"}
${data.exitCode !== undefined ? `- Exit code: ${data.exitCode}` : ""}
${data.count !== undefined ? `- Occurrences: ${data.count}` : ""}
${data.file ? `- File: ${data.file}` : ""}
`;

  writeFileSync(filepath, content);
}

function extractFile(toolInput) {
  if (!toolInput) return null;
  return (
    toolInput.file_path || toolInput.path || toolInput.file || toolInput.command?.match?.(/(?:^|\s)(\S+\.\w+)/)?.[1] || null
  );
}

function similarInput(a, b) {
  if (!a || !b) return false;
  const aStr = JSON.stringify(a);
  const bStr = JSON.stringify(b);
  if (aStr === bStr) return true;
  // Check if same tool targeting same file
  const aFile = extractFile(a);
  const bFile = extractFile(b);
  return aFile && bFile && aFile === bFile;
}

function detectPatterns(history, current) {
  const entries = [];

  // 1. Bash error detection (exit code != 0)
  if (current.toolName === "Bash") {
    const output = current.toolOutput || "";
    // Check for exit code indicators in output
    const exitMatch = output.match(/exit code[:\s]*(\d+)/i);
    const hasError =
      exitMatch && exitMatch[1] !== "0"
        ? true
        : output.includes("Error") ||
          output.includes("error:") ||
          output.includes("FAILED") ||
          output.includes("command not found");

    if (hasError && current.toolOutput) {
      // More specific: check if the tool result indicates failure
      const isLikelyError =
        output.includes("exit code") ||
        output.includes("error:") ||
        output.includes("FAILED") ||
        output.includes("command not found") ||
        output.includes("No such file");

      if (isLikelyError) {
        entries.push({
          category: "error",
          data: {
            toolName: "Bash",
            exitCode: exitMatch ? exitMatch[1] : "non-zero",
            description: `Bash command encountered an error.\n\`\`\`\n${output.slice(0, 500)}\n\`\`\``,
          },
        });
      }
    }
  }

  // 2. Retry pattern detection (same tool + similar input 3+ times)
  const recentWindow = history.slice(-10);
  const similar = recentWindow.filter(
    (h) =>
      h.toolName === current.toolName &&
      similarInput(h.toolInput, current.toolInput)
  );
  if (similar.length >= 2) {
    // Current call is the 3rd+
    entries.push({
      category: "retry-pattern",
      data: {
        toolName: current.toolName,
        count: similar.length + 1,
        file: extractFile(current.toolInput),
        description: `Tool "${current.toolName}" called ${similar.length + 1} times with similar input in recent history.`,
      },
    });
  }

  // 3. Correction detection (Edit/Write on same file consecutively)
  if (
    current.toolName === "Edit" ||
    current.toolName === "Write"
  ) {
    const currentFile = extractFile(current.toolInput);
    const last = history[history.length - 1];
    if (
      last &&
      (last.toolName === "Edit" || last.toolName === "Write") &&
      extractFile(last.toolInput) === currentFile &&
      currentFile
    ) {
      entries.push({
        category: "correction",
        data: {
          toolName: current.toolName,
          file: currentFile,
          description: `Consecutive ${last.toolName} → ${current.toolName} on the same file: ${currentFile}`,
        },
      });
    }
  }

  return entries;
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
    // If we can't parse input, just pass through
    process.stdout.write(JSON.stringify({ continue: true }));
    return;
  }

  const { tool_name: toolName, tool_input: toolInput, tool_output: toolOutput } = payload;
  const current = {
    toolName,
    toolInput,
    toolOutput: typeof toolOutput === "string" ? toolOutput : JSON.stringify(toolOutput || ""),
    timestamp: Date.now(),
  };

  // Read and update history
  const history = readHistory();
  const detected = detectPatterns(history, current);

  // Write entries for detected patterns
  for (const { category, data } of detected) {
    writeEntry(category, data);
  }

  // Append to history (rolling buffer)
  history.push({
    toolName: current.toolName,
    toolInput: current.toolInput,
    timestamp: current.timestamp,
    hadError: detected.some((d) => d.category === "error"),
    hadRetry: detected.some((d) => d.category === "retry-pattern"),
    hadCorrection: detected.some((d) => d.category === "correction"),
  });

  // Trim to max size
  while (history.length > MAX_HISTORY) {
    history.shift();
  }

  writeHistory(history);
  process.stdout.write(JSON.stringify({ continue: true }));
}

main().catch(() => {
  process.stdout.write(JSON.stringify({ continue: true }));
});
