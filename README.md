# go-lsp-enforcement-kit

Claude Code hooks that redirect Go code symbol searches to the built-in LSP
tool instead of `rg`/`Grep`. Keeps your AI-assisted navigation fast and
precise — gopls already knows where everything is.

## What it does

| Trigger | Pattern type | Action |
|---------|-------------|--------|
| `Grep` tool | PascalCase / camelCase symbol | ⛔ Blocked → suggests `LSP workspaceSymbol` or `findReferences` |
| `Bash` with `rg`/`grep` | PascalCase / camelCase symbol | ⛔ Blocked → suggests `LSP goToDefinition` or `findReferences` |
| Either | Quoted string literal | ✅ Allowed (log/error message search) |
| Either | `SCREAMING_SNAKE` constant | ✅ Allowed |
| Either | Short all-lowercase word | ✅ Allowed (package names, field keys) |
| Either | Non-code file type (`.yaml`, `.sql`, `.proto`, `.md`, …) | ✅ Allowed |
| Either | Go module cache (`pkg/mod`) | ✅ Allowed |
| Bash | `git grep` | ✅ Allowed |

## Requirements

- **Node.js** (any recent version — hooks are plain JS with no dependencies)
- **Claude Code** with the `gopls-lsp@claude-plugins-official` plugin enabled

## Install

```bash
git clone https://github.com/bpross/go-lsp-enforcement-kit
cd go-lsp-enforcement-kit
bash install.sh
```

Restart Claude Code (or open `/hooks`) to activate.

The installer safely merges into your existing `~/.claude/settings.json` —
it will not overwrite or remove any other hooks you have configured.

## Uninstall

```bash
bash uninstall.sh
```

## How it works

Two `PreToolUse` hooks intercept tool calls before they execute:

- **`grep-guard.js`** — fires on the built-in `Grep` tool
- **`bash-guard.js`** — fires on `Bash` commands that invoke `rg` or `grep`

Both share `lib/go-symbols.js` (symbol detection) and `lib/lsp-suggest.js`
(suggestion builder). Hook files are installed to `~/.claude/hooks/go-lsp/`.

A rule file (`rules/go-lsp-first.md`) is copied to `~/.claude/rules/` and
injected into Claude's context to reinforce the LSP-first behaviour.

## For agents installing this kit

If you are a Claude agent helping a developer set up this kit, follow these steps:

1. **Check prerequisites**
   ```bash
   node --version   # must be present
   ```
   Confirm `gopls-lsp@claude-plugins-official` is enabled in
   `~/.claude/settings.json` under `enabledPlugins`.

2. **Clone and install**
   ```bash
   git clone https://github.com/bpross/go-lsp-enforcement-kit ~/github.com/<username>/go-lsp-enforcement-kit
   cd ~/github.com/<username>/go-lsp-enforcement-kit
   bash install.sh
   ```

3. **Verify the install output** — it should report:
   ```
   Hook files:    4/4
   Rule file:     yes
   ```

4. **Tell the user to restart Claude Code** (or open `/hooks` in the UI) to
   activate the hooks. Hooks do not hot-reload in a running session.

5. **Do not modify `~/.claude/settings.json` manually** — the installer
   handles JSON merging safely via Node.js. Direct edits risk breaking the
   JSON structure.

## Customising the allow-list

To permit additional paths or file types, edit the constants at the top of
`hooks/grep-guard.js` and `hooks/bash-guard.js`, then re-run `bash install.sh`
to sync the updated files to `~/.claude/hooks/go-lsp/`.

```js
// grep-guard.js / bash-guard.js
const NON_CODE_PATHS = /(pkg\/mod|testdata|\.claude|\.git|\.task|docs?|migrations?|scripts?)\b/i;
const NON_CODE_GLOBS = /\.(md|txt|log|json|jsonc|yaml|yml|toml|xml|sql|sh|proto|env|csv|html|mod|sum|lock)$/i;
```
