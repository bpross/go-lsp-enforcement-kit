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
 * Builds a non-blocking warning that suggests LSP without preventing the
 * underlying tool call. The hook still fires and the suggestion is shown,
 * but Claude is free to proceed with rg/grep when LSP is genuinely the
 * wrong tool (e.g. exploratory searches across multiple symbols).
 */
function buildWarnResponse(symbols, suggestion) {
  return {
    systemMessage:
      `GO-LSP-FIRST hint: Pattern contains Go symbol(s) [${symbols.join(', ')}]. ` +
      `For precise navigation prefer:\n${suggestion}`,
  };
}

module.exports = { buildSuggestion, buildWarnResponse };
