#!/usr/bin/env node
'use strict';

// grep-guard.js — PreToolUse hook (matcher: Grep)
//
// Blocks the built-in Grep tool when the search pattern looks like a Go
// code symbol. Suggests the LSP tool instead for precise navigation.
//
// Allowed through:
//   - Non-code file globs (.md, .yaml, .sql, .proto, .json, ...)
//   - Searches in vendor/, testdata/, .claude/, .git/, docs/
//   - Short patterns (<3 chars)
//   - Quoted string literals
//   - SCREAMING_SNAKE constants
//   - All-lowercase short words (package names, log field keys)

const { extractGoSymbols } = require('./lib/go-symbols');
const { buildSuggestion, buildBlockResponse } = require('./lib/lsp-suggest');

const NON_CODE_GLOBS = /\.(md|txt|log|json|jsonc|yaml|yml|toml|xml|sql|sh|proto|env|csv|html|mod|sum|lock)$/i;
const NON_CODE_PATHS = /(vendor|testdata|\.claude|\.git|\.task|docs?|migrations?|scripts?)\b/i;

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', d => { raw += d; });
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(raw); } catch { process.exit(0); }
  if (data.tool_name !== 'Grep') process.exit(0);

  const params  = data.tool_input || {};
  const pattern = String(params.pattern ?? '').trim();
  const glob    = String(params.glob ?? '');
  const path_   = String(params.path ?? '');

  if (NON_CODE_PATHS.test(path_)) process.exit(0);
  if (NON_CODE_GLOBS.test(glob)) process.exit(0);

  const symbols = extractGoSymbols(pattern);
  if (symbols.length === 0) process.exit(0);

  const suggestion = buildSuggestion(symbols, '  ');
  process.stderr.write(
    `\n⛔ GO-LSP-FIRST: Grep blocked — Go symbol(s) detected: ${symbols.join(', ')}\n` +
    `gopls is connected. Use LSP for precise code navigation:\n${suggestion}\n\n`,
  );
  console.log(JSON.stringify(buildBlockResponse(symbols, suggestion)));
});
