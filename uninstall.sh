#!/usr/bin/env bash
set -euo pipefail

HOOKS_DEST="$HOME/.claude/hooks/go-lsp"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CODEX_HOOKS="$HOME/.codex/hooks.json"
OPENCODE_SKILLS_DEST="$HOME/.config/opencode/skills/go-lsp-first"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"

echo "=== Go LSP Enforcement Kit — Uninstall ==="
echo ""

# 1. Remove shared hook files
if [ -d "$HOOKS_DEST" ]; then
  rm -rf "$HOOKS_DEST"
  echo "[1/4] Removed shared hook files ($HOOKS_DEST)"
else
  echo "[1/4] Hook directory not found (already removed?)"
fi

if ! command -v node &>/dev/null; then
  echo "WARNING: node not found — skipping JSON config cleanup."
  echo "Remove hooks manually from $CLAUDE_SETTINGS and $CODEX_HOOKS"
  exit 0
fi

# 2. Claude Code: remove hooks from settings.json
if [ -f "$CLAUDE_SETTINGS" ]; then
  node - "$CLAUDE_SETTINGS" "$HOOKS_DEST" <<'NODEJS'
const fs = require('fs');
const settingsPath = process.argv[2];
const hooksDir     = process.argv[3];

let settings;
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); }
catch { process.exit(0); }

if (!settings.hooks) process.exit(0);

function removeHooksDir(arr) {
  if (!Array.isArray(arr)) return arr;
  return arr.filter(entry => {
    if (!Array.isArray(entry.hooks)) return true;
    entry.hooks = entry.hooks.filter(h => !String(h.command || '').includes(hooksDir));
    return entry.hooks.length > 0;
  });
}

for (const event of Object.keys(settings.hooks)) {
  settings.hooks[event] = removeHooksDir(settings.hooks[event]);
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
NODEJS
  echo "[2/4] Claude Code: hooks removed from settings.json"
else
  echo "[2/4] Claude Code: settings.json not found, skipped"
fi

# 3. Codex: remove hooks from hooks.json
if [ -f "$CODEX_HOOKS" ]; then
  node - "$CODEX_HOOKS" "$HOOKS_DEST" <<'NODEJS'
const fs = require('fs');
const hooksPath = process.argv[2];
const hooksDir  = process.argv[3];

let existing;
try { existing = JSON.parse(fs.readFileSync(hooksPath, 'utf8')); }
catch { process.exit(0); }

if (!existing.hooks) process.exit(0);

function removeHooksDir(arr) {
  if (!Array.isArray(arr)) return arr;
  return arr.filter(entry => {
    if (!Array.isArray(entry.hooks)) return true;
    entry.hooks = entry.hooks.filter(h => !String(h.command || '').includes(hooksDir));
    return entry.hooks.length > 0;
  });
}

for (const event of Object.keys(existing.hooks)) {
  existing.hooks[event] = removeHooksDir(existing.hooks[event]);
}

fs.writeFileSync(hooksPath, JSON.stringify(existing, null, 2));
NODEJS
  echo "[3/4] Codex: hooks removed from hooks.json"
else
  echo "[3/4] Codex: hooks.json not found, skipped"
fi

# 4. opencode: remove skill and clean up opencode.jsonc
if [ -d "$OPENCODE_SKILLS_DEST" ]; then
  rm -rf "$OPENCODE_SKILLS_DEST"
fi

if [ -f "$OPENCODE_CONFIG" ]; then
  node - "$OPENCODE_CONFIG" "$OPENCODE_SKILLS_DEST" <<'NODEJS'
const fs = require('fs');

const configPath = process.argv[2];
const skillPath  = process.argv[3];

function stripJsonComments(src) {
  return src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
}

let config;
try { config = JSON.parse(stripJsonComments(fs.readFileSync(configPath, 'utf8'))); }
catch { process.exit(0); }

if (config.skills?.paths) {
  config.skills.paths = config.skills.paths.filter(p => p !== skillPath);
}

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
NODEJS
  echo "[4/4] opencode: skill removed and opencode.jsonc updated"
else
  echo "[4/4] opencode: config not found, skipped"
fi

echo ""
echo "Done. Restart each agent to deactivate."
