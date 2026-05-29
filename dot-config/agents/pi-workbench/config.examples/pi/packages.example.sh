#!/usr/bin/env sh
set -eu

# Run this only in a disposable Pi profile while evaluating.
pi install npm:@spences10/pi-mcp
pi install npm:@spences10/pi-lsp
pi install npm:@spences10/pi-context
pi install npm:@spences10/pi-recall
pi install npm:@spences10/pi-telemetry
pi install npm:@spences10/pi-redact
pi install npm:@spences10/pi-skills

# Evaluate after the minimal subagent path works.
# pi install npm:@spences10/pi-team-mode
