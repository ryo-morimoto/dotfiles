#!/usr/bin/env node

/**
 * Stop Hook: Obsidian Daily Log
 *
 * Appends a session summary to ~/obsidian/Daily/YYYY-MM-DD.md.
 * Reads the SI entry for context if available.
 */

import { readFileSync, writeFileSync, appendFileSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { join, basename } from "node:path";

const HOME = process.env.HOME || process.env.USERPROFILE;
const VAULT = join(HOME, "obsidian");
const DAILY_DIR = join(VAULT, "Daily");
const SI_ENTRIES = join(HOME, ".claude", "si", "data", "entries");

function today() {
  return new Date().toISOString().slice(0, 10);
}

function nowTime() {
  return new Date().toTimeString().slice(0, 5);
}

function readLatestSiEntry(dateStr) {
  try {
    const files = readdirSync(SI_ENTRIES)
      .filter((f) => f.startsWith(dateStr) && f.endsWith(".md"))
      .sort()
      .reverse();
    if (files.length === 0) return null;
    return readFileSync(join(SI_ENTRIES, files[0]), "utf-8");
  } catch {
    return null;
  }
}

function ensureDailyNote(dateStr) {
  mkdirSync(DAILY_DIR, { recursive: true });
  const filepath = join(DAILY_DIR, `${dateStr}.md`);
  if (!existsSync(filepath)) {
    writeFileSync(
      filepath,
      `---\ndate: "${dateStr}"\ncategories: [daily]\ntags: []\nsource: auto\n---\n# ${dateStr}\n\n`
    );
  }
  return filepath;
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

  // Skip if vault doesn't exist
  if (!existsSync(VAULT)) return;

  const dateStr = today();
  const time = nowTime();
  const sessionId = (payload.session_id || "unknown").slice(0, 8);
  const cwd = payload.cwd || process.cwd();
  const project = basename(cwd);

  // Read SI entry for context
  const siEntry = readLatestSiEntry(dateStr);
  let statsLine = "";
  if (siEntry) {
    const statsMatch = siEntry.match(/Total tool calls: (\d+)/);
    const errMatch = siEntry.match(/Errors: (\d+)/);
    if (statsMatch) {
      statsLine = `- Tools: ${statsMatch[1]}`;
      if (errMatch && errMatch[1] !== "0") {
        statsLine += `, Errors: ${errMatch[1]}`;
      }
    }
  }

  // Append to daily note
  const dailyPath = ensureDailyNote(dateStr);
  const entry = [
    `\n## Session ${time} (${sessionId})`,
    `- Project: ${project}`,
    statsLine,
    "",
  ]
    .filter(Boolean)
    .join("\n");

  appendFileSync(dailyPath, entry + "\n");
}

main().catch(() => {});
