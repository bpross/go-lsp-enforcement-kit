#!/usr/bin/env node
'use strict';

// bash-guard.js — PreToolUse hook (matcher: Bash)
//
// Blocks rg/grep Bash commands when the search pattern contains a Go code
// symbol. Respects the rg-for-text-search convention: only intercepts when
// the pattern is clearly a code identifier, not a string literal.
//
// Allowed through:
//   - git grep (fine to use)
//   - Explicit non-code file type flags: -t yaml, --type json, etc.
//   - --include=*.proto / *.yaml / *.sql / *.md etc.
//   - Searches in Go module cache (pkg/mod), testdata/, docs/, migrations/, .claude/
//   - Quoted string patterns (log messages, error strings)
//   - rg on non-Go file type flags

const { extractGoSymbols, ZERO_WIDTH } = require('./lib/go-symbols');
const { buildSuggestion, buildBlockResponse } = require('./lib/lsp-suggest');

const NON_CODE_TYPE_FLAGS =
  /(?:-t|--type[= ])\s*(yaml|yml|json|toml|xml|sql|markdown|md|sh|proto|txt|csv|html)/i;
const NON_CODE_INCLUDE =
  /--include=?\*?\.(yaml|yml|json|toml|xml|sql|md|sh|proto|txt|csv|html|mod|sum)/i;
const NON_CODE_GLOB_FLAG =
  /-g\s+['"]?\*?\.(yaml|yml|json|toml|xml|sql|md|sh|proto|txt|csv)['"]?/i;
const NON_CODE_PATHS =
  /(pkg\/mod|testdata|\.claude|\.git|\.task|docs?|migrations?|scripts?)\b/i;

// Pattern extraction: try quoted then unquoted symbol
const PATTERN_RE = [
  /\b(?:grep|rg)\s+(?:-\S+\s+)*"([^"]+)"/i,
  /\b(?:grep|rg)\s+(?:-\S+\s+)*'([^']+)'/i,
  /\b(?:grep|rg)\s+(?:-[a-zA-Z0-9]+\s+)*([A-Z][a-zA-Z0-9]{2,})\b/,
  /\b(?:grep|rg)\s+(?:-[a-zA-Z0-9]+\s+)*([a-z][a-zA-Z0-9]{3,})\b/,
];

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', d => { raw += d; });
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(raw); } catch { process.exit(0); }
  if (data.tool_name !== 'Bash') process.exit(0);

  const cmd = String(data.tool_input?.command ?? '').trim().replace(ZERO_WIDTH, '');

  if (!/\b(grep|rg)\b/i.test(cmd)) process.exit(0);
  if (/\bgit\s+grep\b/i.test(cmd)) process.exit(0);
  if (NON_CODE_TYPE_FLAGS.test(cmd)) process.exit(0);
  if (NON_CODE_INCLUDE.test(cmd)) process.exit(0);
  if (NON_CODE_GLOB_FLAG.test(cmd)) process.exit(0);
  if (NON_CODE_PATHS.test(cmd)) process.exit(0);

  let rawPattern = null;
  for (const re of PATTERN_RE) {
    const m = cmd.match(re);
    if (m) { rawPattern = m[1]; break; }
  }
  if (!rawPattern) process.exit(0);

  // Quoted pattern → user is searching a string literal, not a symbol
  if (/^["'`]/.test(rawPattern.trim())) process.exit(0);

  const symbols = extractGoSymbols(rawPattern);
  if (symbols.length === 0) process.exit(0);

  const suggestion = buildSuggestion(symbols, '  ');
  process.stderr.write(
    `\n⛔ GO-LSP-FIRST: rg/grep blocked — Go symbol(s) detected: ${symbols.join(', ')}\n` +
    `gopls is connected. Use LSP for precise code navigation:\n${suggestion}\n\n`,
  );
  console.log(JSON.stringify(buildBlockResponse(symbols, suggestion)));
});
