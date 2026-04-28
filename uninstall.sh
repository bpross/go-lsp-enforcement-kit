#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks/go-lsp"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "=== Go LSP Enforcement Kit — Uninstall ==="
echo ""

# Remove hook files
if [ -d "$HOOKS_DEST" ]; then
  rm -rf "$HOOKS_DEST"
  echo "[1/2] Removed $HOOKS_DEST"
else
  echo "[1/2] Hook directory not found (already removed?)"
fi

# Remove hooks from settings.json
if [ -f "$SETTINGS" ] && command -v node &>/dev/null; then
  node - "$SETTINGS" "$HOOKS_DEST" <<'EOF'
const fs = require('fs');
const settingsPath = process.argv[2];
const hooksDir     = process.argv[3];

let settings;
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); }
catch { process.exit(0); }

if (!settings.hooks) { process.exit(0); }

function removeHooksDir(arr) {
  if (!Array.isArray(arr)) return arr;
  return arr.filter(entry => {
    if (!Array.isArray(entry.hooks)) return true;
    const filtered = entry.hooks.filter(h => !String(h.command || '').includes(hooksDir));
    if (filtered.length === 0) return false;
    entry.hooks = filtered;
    return true;
  });
}

for (const event of Object.keys(settings.hooks)) {
  settings.hooks[event] = removeHooksDir(settings.hooks[event]);
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
EOF
  echo "[2/2] Removed hooks from settings.json"
else
  echo "[2/2] Skipped settings.json update (file not found or node unavailable)"
fi

echo ""
echo "Done. Restart Claude Code to deactivate."
