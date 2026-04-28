#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Shared hook files destination (all agents read from here) ──────────────
HOOKS_DEST="$HOME/.claude/hooks/go-lsp"

# ── Claude Code ────────────────────────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
RULES_DEST="$CLAUDE_DIR/rules"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

# ── Codex ──────────────────────────────────────────────────────────────────
CODEX_DIR="$HOME/.codex"
CODEX_HOOKS="$CODEX_DIR/hooks.json"

# ── opencode ───────────────────────────────────────────────────────────────
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_SKILLS_DEST="$OPENCODE_DIR/skills/go-lsp-first"
OPENCODE_CONFIG="$OPENCODE_DIR/opencode.jsonc"

echo "=== Go LSP Enforcement Kit — Install ==="
echo ""

# ── Verify dependencies ────────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  echo "ERROR: node is required but not found in PATH." >&2
  exit 1
fi

# ── 1. Copy shared hook files ──────────────────────────────────────────────
mkdir -p "$HOOKS_DEST/lib" "$RULES_DEST"
cp "$SCRIPT_DIR/hooks/lib/"*.js "$HOOKS_DEST/lib/"
cp "$SCRIPT_DIR/hooks/"*.js     "$HOOKS_DEST/"
cp "$SCRIPT_DIR/rules/"*.md     "$RULES_DEST/"
echo "[1/4] Hook files copied to $HOOKS_DEST"

# ── 2. Claude Code: merge into settings.json ──────────────────────────────
node - "$CLAUDE_SETTINGS" "$HOOKS_DEST" <<'NODEJS'
const fs = require('fs');

const settingsPath = process.argv[2];
const hooksDir     = process.argv[3];

let settings = {};
if (fs.existsSync(settingsPath)) {
  try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); }
  catch { process.stderr.write('WARNING: could not parse settings.json — starting fresh\n'); }
}

if (!settings.hooks) settings.hooks = {};
if (!settings.hooks.PreToolUse) settings.hooks.PreToolUse = [];

const newHooks = [
  {
    matcher: 'Grep',
    hooks: [{ type: 'command', command: `node ${hooksDir}/grep-guard.js`, statusMessage: 'Checking Go symbols…' }],
  },
  {
    matcher: 'Bash',
    hooks: [{ type: 'command', command: `node ${hooksDir}/bash-guard.js`, statusMessage: 'Checking Go symbols…' }],
  },
];

function hasHook(arr, cmd) {
  return arr.some(e => Array.isArray(e.hooks) && e.hooks.some(h => h.command === cmd));
}

let added = 0;
for (const entry of newHooks) {
  if (!hasHook(settings.hooks.PreToolUse, entry.hooks[0].command)) {
    settings.hooks.PreToolUse.push(entry);
    added++;
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
console.log(`[2/4] Claude Code: settings.json updated (${added} hook(s) added)`);
NODEJS

# ── 3. Codex: merge into ~/.codex/hooks.json ──────────────────────────────
# Codex has no standalone Grep tool — the Bash matcher covers rg/grep calls.
mkdir -p "$CODEX_DIR"
node - "$CODEX_HOOKS" "$HOOKS_DEST" <<'NODEJS'
const fs = require('fs');

const hooksPath = process.argv[2];
const hooksDir  = process.argv[3];

let existing = { hooks: { PreToolUse: [] } };
if (fs.existsSync(hooksPath)) {
  try { existing = JSON.parse(fs.readFileSync(hooksPath, 'utf8')); }
  catch { process.stderr.write('WARNING: could not parse hooks.json — starting fresh\n'); }
}

if (!existing.hooks) existing.hooks = {};
if (!existing.hooks.PreToolUse) existing.hooks.PreToolUse = [];

const entry = {
  matcher: 'Bash',
  hooks: [{ type: 'command', command: `node ${hooksDir}/bash-guard.js`, statusMessage: 'Checking Go symbols…' }],
};

function hasHook(arr, cmd) {
  return arr.some(e => Array.isArray(e.hooks) && e.hooks.some(h => h.command === cmd));
}

let added = 0;
if (!hasHook(existing.hooks.PreToolUse, entry.hooks[0].command)) {
  existing.hooks.PreToolUse.push(entry);
  added++;
}

fs.writeFileSync(hooksPath, JSON.stringify(existing, null, 2));
console.log(`[3/4] Codex: hooks.json updated (${added} hook(s) added)`);
NODEJS

# ── 4. opencode: install skill + update opencode.jsonc ────────────────────
# opencode has no script-hook system; we install a SKILL.md so the agent
# receives the LSP-first instructions at session start.
mkdir -p "$OPENCODE_SKILLS_DEST"
cp "$SCRIPT_DIR/skills/go-lsp-first/SKILL.md" "$OPENCODE_SKILLS_DEST/SKILL.md"

node - "$OPENCODE_CONFIG" "$OPENCODE_SKILLS_DEST" <<'NODEJS'
const fs   = require('fs');
const path = require('path');

const configPath = process.argv[2];
const skillPath  = process.argv[3];

// opencode.jsonc may contain comments — strip them before parsing.
function stripJsonComments(src) {
  return src
    .replace(/\/\/[^\n]*/g, '')
    .replace(/\/\*[\s\S]*?\*\//g, '');
}

let config = {};
if (fs.existsSync(configPath)) {
  try { config = JSON.parse(stripJsonComments(fs.readFileSync(configPath, 'utf8'))); }
  catch { process.stderr.write('WARNING: could not parse opencode.jsonc — starting fresh\n'); }
}

if (!config.skills) config.skills = {};
if (!Array.isArray(config.skills.paths)) config.skills.paths = [];

if (!config.skills.paths.includes(skillPath)) {
  config.skills.paths.push(skillPath);
}

// Write back as plain JSON (comments are lost, but opencode accepts JSON too).
fs.mkdirSync(path.dirname(configPath), { recursive: true });
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('[4/4] opencode: skill installed and opencode.jsonc updated');
NODEJS

# ── Verify ─────────────────────────────────────────────────────────────────
echo ""
HOOKS_OK=$(ls "$HOOKS_DEST"/grep-guard.js "$HOOKS_DEST"/bash-guard.js \
              "$HOOKS_DEST/lib"/go-symbols.js "$HOOKS_DEST/lib"/lsp-suggest.js \
              2>/dev/null | wc -l | tr -d ' ')
RULE_OK=$([ -f "$RULES_DEST/go-lsp-first.md" ] && echo "yes" || echo "no")
CODEX_OK=$([ -f "$CODEX_HOOKS" ] && echo "yes" || echo "no")
OPENCODE_OK=$([ -f "$OPENCODE_SKILLS_DEST/SKILL.md" ] && echo "yes" || echo "no")

echo "  Hook files (shared):  $HOOKS_OK/4"
echo "  Claude Code rule:     $RULE_OK"
echo "  Codex hooks.json:     $CODEX_OK"
echo "  opencode SKILL.md:    $OPENCODE_OK"
echo ""

if [ "$HOOKS_OK" -eq 4 ] && [ "$RULE_OK" = "yes" ] && [ "$CODEX_OK" = "yes" ] && [ "$OPENCODE_OK" = "yes" ]; then
  echo "Done."
  echo "  • Claude Code: restart or open /hooks to activate"
  echo "  • Codex:       restart to activate"
  echo "  • opencode:    restart to activate"
else
  echo "WARNING: Some components missing — check output above."
  exit 1
fi
