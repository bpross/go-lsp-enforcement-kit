'use strict';

// Zero-width chars that could split tokens to evade detection
const ZERO_WIDTH = /[­​-‏⁠-⁤﻿]/g;

const GO_KEYWORDS = new Set([
  'break', 'case', 'chan', 'const', 'continue', 'default', 'defer',
  'else', 'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import',
  'interface', 'map', 'package', 'range', 'return', 'select', 'struct',
  'switch', 'type', 'var',
]);

const GO_BUILTINS = new Set([
  'append', 'cap', 'close', 'copy', 'delete', 'error', 'false', 'imag',
  'iota', 'len', 'make', 'new', 'nil', 'panic', 'print', 'println',
  'real', 'recover', 'true', 'string', 'byte', 'rune', 'int', 'uint',
]);

// Patterns that indicate text/log searches rather than code navigation
const TEXT_SEARCH_PREFIXES = [
  /^(TODO|FIXME|HACK|XXX|NOTE|BUG)/i,
  /^(invalid|failed|cannot|unable|missing|unknown|unexpected|not found)/i,
  /^(getting|fetching|loading|saving|creating|updating|deleting)/i,
  /^(beginning|finished|starting|stopping|running|executing)/i,
  /^https?:\/\//,
  /^\d/,
  /^["'`]/,
];

/**
 * Returns true if the string looks like a Go code symbol (exported or
 * unexported) that should be navigated via LSP rather than searched with rg.
 *
 * Go naming conventions (no snake_case for code symbols):
 *   Exported:   PascalCase  — PaymentService, HandleRequest, AuthorizationUpdater
 *   Unexported: camelCase   — newPaymentService, parseAccountID, accountsCache
 */
function isGoSymbol(raw) {
  if (!raw || typeof raw !== 'string') return false;
  const s = raw.replace(ZERO_WIDTH, '').trim();

  if (s.length < 3) return false;
  if (/\s/.test(s)) return false;

  // Regex metacharacters — this is a pattern, not a symbol name
  if (/[&?+[\]{}()\\^$*|]/.test(s)) return false;

  // Paths, file extensions, dotted notation (log field keys like "event.type")
  if (/[/\\.]/.test(s)) return false;

  if (GO_KEYWORDS.has(s) || GO_BUILTINS.has(s)) return false;
  if (TEXT_SEARCH_PREFIXES.some(rx => rx.test(s))) return false;

  // SCREAMING_SNAKE — constants and env vars, fine to grep for
  if (/^[A-Z][A-Z0-9_]+$/.test(s)) return false;

  // Short all-lowercase — package names, log field keys, common words
  if (/^[a-z]{1,10}$/.test(s)) return false;

  // Kebab-case — config keys, not Go identifiers
  if (/^[a-z][a-z0-9]*(-[a-z0-9]+)+$/.test(s)) return false;

  // PascalCase exported symbol: PaymentService, HandleRequest, NewAccountsClient
  const isPascalCase = /^[A-Z][a-zA-Z0-9]{2,}$/.test(s);

  // camelCase unexported symbol: newPaymentService, parseAccountID, accountsCache
  // Require uppercase after the first character to avoid false positives on short words
  const isCamelCase = /^[a-z][a-zA-Z0-9]{3,}$/.test(s) && /[A-Z]/.test(s.slice(1));

  return isPascalCase || isCamelCase;
}

/**
 * Extracts Go code symbols from a search pattern string.
 * Handles regex alternations (foo|bar) and strips regex syntax.
 */
function extractGoSymbols(pattern) {
  if (!pattern) return [];
  const cleaned = String(pattern).replace(ZERO_WIDTH, '').replace(/\\["']/g, '');

  // Quoted string search — user is looking for a string literal, not a symbol
  if (/^["'`]/.test(cleaned.trim())) return [];

  const parts = cleaned
    .split(/[|()\s,+*?[\]{}\\]+/)
    .map(p => p.replace(/[^a-zA-Z0-9_]/g, '').trim())
    .filter(Boolean);

  return [...new Set(parts.filter(isGoSymbol))];
}

module.exports = { isGoSymbol, extractGoSymbols, ZERO_WIDTH };
