#!/usr/bin/env node
// Render every *.mmd under designs/<NNN-slug>/diagrams/ to <name>.svg using
// beautiful-mermaid. Synchronous renderer; no Puppeteer / Chrome dependency.
//
// Usage:
//   node render-diagrams.mjs                  # render every design
//   node render-diagrams.mjs 001-permission-broker   # render one design

import { renderMermaidSVG, THEMES } from "beautiful-mermaid";
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, basename } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const THEME = THEMES["github-light"]; // matches the markdown reading context

function listDesigns() {
  return readdirSync(HERE)
    .filter((name) => /^\d{3}-/.test(name))
    .filter((name) => statSync(join(HERE, name)).isDirectory());
}

function renderOne(mmdPath) {
  const text = readFileSync(mmdPath, "utf-8");
  const svg = renderMermaidSVG(text, THEME);
  const svgPath = mmdPath.replace(/\.mmd$/, ".svg");
  writeFileSync(svgPath, svg);
  return svgPath;
}

function renderDesign(slug) {
  const dir = join(HERE, slug, "diagrams");
  let entries;
  try {
    entries = readdirSync(dir);
  } catch (err) {
    console.error(`skip ${slug}: ${err.message}`);
    return { ok: 0, fail: 0 };
  }
  const mmds = entries.filter((n) => n.endsWith(".mmd"));
  let ok = 0;
  let fail = 0;
  for (const m of mmds) {
    const p = join(dir, m);
    try {
      const out = renderOne(p);
      console.log(`  ok  ${basename(out)} (${statSync(out).size} bytes)`);
      ok++;
    } catch (err) {
      console.error(`  err ${m}: ${err.message}`);
      fail++;
    }
  }
  return { ok, fail };
}

const target = process.argv[2];
const designs = target ? [target] : listDesigns();

let totalOk = 0;
let totalFail = 0;
for (const d of designs) {
  console.log(`design: ${d}`);
  const { ok, fail } = renderDesign(d);
  totalOk += ok;
  totalFail += fail;
}

console.log(`\nrendered ${totalOk} svg(s), ${totalFail} failure(s)`);
process.exit(totalFail === 0 ? 0 : 1);
