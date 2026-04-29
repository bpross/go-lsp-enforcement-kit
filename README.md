# go-lsp-enforcement-kit

Hooks and instructions that redirect Go code symbol searches to the LSP tool
instead of `rg`/`Grep`. Works across Claude Code, Codex, and opencode.

## What it does

The hooks **warn but do not block** — searches still execute, but the agent
sees a hint suggesting LSP for precise navigation. Exploratory searches and
multi-symbol scans where rg is genuinely the right tool are not interrupted.

| Trigger | Pattern type | Action |
|---------|-------------|--------|
| `Grep` tool | PascalCase / camelCase symbol | ⚠️  Warning → suggests `LSP workspaceSymbol` or `findReferences` |
| `Bash` with `rg`/`grep` | PascalCase / camelCase symbol | ⚠️  Warning → suggests `LSP goToDefinition` or `findReferences` |
| Either | Quoted string literal | ✅ Silent (log/error message search) |
| Either | `SCREAMING_SNAKE` constant | ✅ Silent |
| Either | Short all-lowercase word | ✅ Silent (package names, field keys) |
| Either | Non-code file type (`.yaml`, `.sql`, `.proto`, `.md`, …) | ✅ Silent |
| Either | Go module cache (`pkg/mod`) | ✅ Silent |
| Bash | `git grep` | ✅ Silent |

## Agent support

| Agent | Mechanism | Config written |
|-------|-----------|---------------|
| **Claude Code** | `PreToolUse` hooks on `Grep` + `Bash` | `~/.claude/settings.json` |
| **Codex** | `PreToolUse` hook on `Bash` | `~/.codex/hooks.json` |
| **opencode** | `SKILL.md` instruction file | `~/.config/opencode/opencode.jsonc` |

All three agents read hook scripts from the same location: `~/.claude/hooks/go-lsp/`.

Claude Code and Codex enforce the rule programmatically (the hook script blocks
the tool call and explains what to use instead). opencode receives it as an
instruction via its skills system, since opencode does not have a script-hook
system.

## Requirements

- **Node.js** (any recent version — hooks are plain JS with no npm dependencies)
- **gopls** configured for your project (Claude Code: `gopls-lsp@claude-plugins-official` plugin)

## Install

```bash
git clone https://github.com/bpross/go-lsp-enforcement-kit
cd go-lsp-enforcement-kit
bash install.sh
```

Restart each agent to activate. The installer safely merges into existing
config files without overwriting anything else.

## Uninstall

```bash
bash uninstall.sh
```

## How it works

### Claude Code + Codex

Two `PreToolUse` hook scripts intercept tool calls before they execute:

- **`grep-guard.js`** — fires on Claude Code's built-in `Grep` tool
- **`bash-guard.js`** — fires on `Bash` commands that invoke `rg` or `grep`

Both share `lib/go-symbols.js` (symbol detection) and `lib/lsp-suggest.js`
(suggestion builder). Scripts are installed to `~/.claude/hooks/go-lsp/` and
referenced from each agent's config.

### opencode

opencode has no script-hook system, so the kit installs a `SKILL.md` file
to `~/.config/opencode/skills/go-lsp-first/` and registers it in
`opencode.jsonc`. The skill injects Go LSP-first instructions into every session.

## For agents installing this kit

If you are an AI agent helping a developer set up this kit:

1. **Check Node.js is available**
   ```bash
   node --version
   ```

2. **Clone and install**
   ```bash
   git clone https://github.com/bpross/go-lsp-enforcement-kit ~/github.com/<username>/go-lsp-enforcement-kit
   cd ~/github.com/<username>/go-lsp-enforcement-kit
   bash install.sh
   ```

3. **Verify the install output** — it should end with:
   ```
   Hook files (shared):  4/4
   Claude Code rule:     yes
   Codex hooks.json:     yes
   opencode SKILL.md:    yes
   ```

4. **Tell the user to restart each agent** to activate. Hooks do not hot-reload
   in a running session. For Claude Code, opening `/hooks` also reloads config.

5. **Do not edit the JSON config files manually** — the installer merges safely
   via Node.js. Direct edits to JSONC files can break comment stripping.

## Customising the allow-list

Edit the constants at the top of `hooks/grep-guard.js` and `hooks/bash-guard.js`,
then re-run `bash install.sh` to sync the changes.

```js
const NON_CODE_PATHS = /(pkg\/mod|testdata|\.claude|\.git|\.task|docs?|migrations?|scripts?)\b/i;
const NON_CODE_GLOBS = /\.(md|txt|log|json|jsonc|yaml|yml|toml|xml|sql|sh|proto|env|csv|html|mod|sum|lock)$/i;
```
