'use strict';

/**
 * Builds a human-readable suggestion block directing Claude to use the
 * built-in LSP tool instead of rg/grep for Go code navigation.
 *
 * The LSP tool provides:
 *   workspaceSymbol   — find a symbol by name across the whole project
 *   findReferences    — find all usages of a symbol (needs file:line)
 *   goToDefinition    — jump to where a symbol is defined (needs file:line)
 *   goToImplementation — find interface implementations (needs file:line)
 */
function buildSuggestion(symbols, indent = '  ') {
  const lines = [];

  for (const sym of symbols) {
    const isExported = /^[A-Z]/.test(sym);

    if (isExported) {
      lines.push(
        `${indent}• LSP(operation="workspaceSymbol", ...) — locate "${sym}" across all packages`,
        `${indent}  Then LSP(operation="findReferences", ...) from the result position`,
      );
    } else {
      lines.push(
        `${indent}• From a call site of ${sym}: LSP(operation="goToDefinition", ...)`,
        `${indent}  Then LSP(operation="findReferences", ...) to find all usages`,
      );
    }
  }

  return lines.join('\n');
}

/**
 * Builds the JSON block response that a PreToolUse hook should emit to
 * block the tool call and explain the required LSP alternative.
 */
function buildBlockResponse(symbols, suggestion) {
  return {
    decision: 'block',
    reason: `GO-LSP-FIRST: Pattern contains Go symbol(s) [${symbols.join(', ')}].\n\n${suggestion}`,
  };
}

module.exports = { buildSuggestion, buildBlockResponse };
