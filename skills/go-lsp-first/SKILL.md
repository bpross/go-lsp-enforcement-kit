---
name: go-lsp-first
description: Enforce LSP-first navigation for Go code — use LSP tools instead of grep/rg for code symbols
---

# Go LSP-First Navigation

gopls is always connected. Use LSP tools for Go code navigation — not `grep` or `rg`.

## Use LSP when you know a symbol name

| Goal | How |
|------|-----|
| Find where a type/function is defined | LSP `goToDefinition` from a call site |
| Find all usages of a symbol | LSP `findReferences` from a known position |
| Locate a symbol by name across the project | LSP `workspaceSymbol` |
| Find interface implementations | LSP `goToImplementation` |
| Browse a file's exported symbols | LSP `documentSymbol` |

## Use grep / rg for text searches only

grep and rg are appropriate for:
- String literals: error messages, log strings, SQL queries
- Non-Go files: `.yaml`, `.sql`, `.proto`, `.md`, `.json`, `.env`
- Import paths and package names
- `git grep` for history searches
- `SCREAMING_SNAKE` constants

## Symbol navigation workflow

1. **Locate** — LSP `workspaceSymbol` with the exported type or function name
2. **Navigate** — LSP `findReferences` or `goToDefinition` from the result position
3. **Read** — open the file only after you have the exact location
