#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks/go-lsp"
RULES_DEST="$CLAUDE_DIR/rules"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "=== Go LSP Enforcement Kit — Install ==="
echo ""

# 1. Verify dependencies
if ! command -v node &>/dev/null; then
  echo "ERROR: node is required but not found in PATH." >&2
  exit 1
fi

# 2. Copy hook files
mkdir -p "$HOOKS_DEST/lib" "$RULES_DEST"
cp "$SCRIPT_DIR/hooks/lib/"*.js "$HOOKS_DEST/lib/"
cp "$SCRIPT_DIR/hooks/"*.js "$HOOKS_DEST/"
cp "$SCRIPT_DIR/rules/"*.md "$RULES_DEST/"
echo "[1/3] Hooks and rules copied to $HOOKS_DEST"

# 3. Merge into settings.json
node - "$SETTINGS" "$HOOKS_DEST" <<'EOF'
const fs   = require('fs');
const path = require('path');

const settingsPath = process.argv[2];
const hooksDir     = process.argv[3];

let settings = {};
if (fs.existsSync(settingsPath)) {
  try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); }
  catch (e) { console.error('WARNING: could not parse existing settings.json — starting fresh'); }
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

function hasHook(arr, command) {
  return arr.some(entry =>
    Array.isArray(entry.hooks) && entry.hooks.some(h => h.command === command)
  );
}

let added = 0;
for (const entry of newHooks) {
  const cmd = entry.hooks[0].command;
  if (!hasHook(settings.hooks.PreToolUse, cmd)) {
    settings.hooks.PreToolUse.push(entry);
    added++;
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
console.log(`[2/3] settings.json updated (${added} hook(s) added, existing hooks preserved)`);
EOF

# 4. Verify
echo ""
HOOKS_OK=$(ls "$HOOKS_DEST"/grep-guard.js "$HOOKS_DEST"/bash-guard.js \
              "$HOOKS_DEST/lib"/go-symbols.js "$HOOKS_DEST/lib"/lsp-suggest.js \
              2>/dev/null | wc -l | tr -d ' ')
RULE_OK=$([ -f "$RULES_DEST/go-lsp-first.md" ] && echo "yes" || echo "no")

echo "[3/3] Verification"
echo "  Hook files:    $HOOKS_OK/4"
echo "  Rule file:     $RULE_OK"
echo ""

if [ "$HOOKS_OK" -eq 4 ] && [ "$RULE_OK" = "yes" ]; then
  echo "Done. Restart Claude Code (or open /hooks) to activate."
else
  echo "WARNING: Some components missing — check output above."
  exit 1
fi
