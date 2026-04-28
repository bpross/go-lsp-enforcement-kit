# Go LSP-First Navigation

gopls is always connected. Use the **LSP tool** for Go code navigation — not rg or Grep.

## Use LSP when you know a symbol name

| Goal | LSP operation |
|------|--------------|
| Find where a type/function is defined | `workspaceSymbol` → then `goToDefinition` |
| Find all call sites / usages | `findReferences` from a known position |
| Find interface implementations | `goToImplementation` from the interface position |
| Browse a file's exported symbols | `documentSymbol` |
| Explore call graphs | `incomingCalls` / `outgoingCalls` |

## Use rg / Grep for text searches

rg is appropriate for:
- String literals: error messages, log strings, SQL queries, comments
- Non-Go files: `.yaml`, `.sql`, `.proto`, `.md`, `.json`, `.env`
- Import paths and package names
- `git grep` for history searches

## Symbol search workflow

1. **Locate** — `LSP(operation="workspaceSymbol", ...)` with the symbol name
2. **Navigate** — `LSP(operation="findReferences", ...)` or `goToDefinition` from the result
3. **Read** — open the file only after you have the exact position
