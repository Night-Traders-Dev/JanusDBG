# JSON Utilities (`lib/json.sage`)

## Purpose

A self-contained JSON parser and serializer for JSON-RPC 2.0 communication. Avoids `std.json` because the SageLang C/LLVM codegen backends cannot call native module methods at runtime.

## API

### `json_stringify(value) -> String`

Convert a SageLang value to its JSON representation.

| Input Type | JSON Output |
|-----------|-------------|
| `nil` | `null` |
| `bool` (true) | `true` |
| `bool` (false) | `false` |
| `number` | decimal string |
| `string` | `"..."` (with escaping) |
| `array` | `[...]` |
| `dict` | `{...}` |

**String escaping** handles: `\"`, `\\`, `\n`, `\t`.

### `json_parse(text: String) -> any`

Parse a JSON string into SageLang values.

| JSON Input | Output Type |
|-----------|-------------|
| `null` | `nil` |
| `true` / `false` | `bool` |
| number | `number` (via `tonumber()`) |
| `"..."` | `String` |
| `[...]` | `Array` |
| `{...}` | `dict` |

## Internal Design

### `json_stringify`

Recursive descent using `type()` built-in for dispatch:

1. `nil` → `"null"`
2. `bool` → `"true"` / `"false"`
3. `number` → `str(value)`
4. `string` → iterate characters with escaping rules
5. `array` → recurse each element, join with `,`
6. `dict` → iterate `dict_keys()`, recurse each value as `"key":value`

### `json_parse`

Stateful recursive descent parser driven by a mutable `pos` variable:

- **Lexer**: `skip_ws()` ingests whitespace
- **`parse_str()`**: reads quoted string with `\"`, `\\`, `\n`, `\t`, `\/` escape handling
- **`parse_num()`**: reads optional `-`, digits, optional `.` + digits; returns `tonumber()`
- **`parse_val()`**: dispatches to sub-parsers based on first character
- **`parse_arr()`**: reads `[`, comma-separated values, `]`
- **`parse_obj()`**: reads `{`, comma-separated `key: value` pairs, `}`

**Nested procedure scope**: `json_parse` defines `skip_ws`, `parse_str`, `parse_num`, `parse_val`, `parse_arr`, and `parse_obj` as local procedures that share the outer `pos` and `n` variables.

## Codegen Considerations

- No native module calls (`std.json`, `regex`, etc.)
- Uses `type()` built-in for dispatch instead of `instanceof` or class checks
- Uses `dict_keys()` and `dict_has()` (available in SageLang v4.0.8) rather than `.keys()` or `.get()`
- String-by-string concatenation for building output (avoids array-of-chars approach that may confuse backends)
- Nested procedures rely on closure — all SageLang backends support this

## Test Coverage

No separate test file for `lib/json.sage`; it is tested indirectly through the RPC server tests:

| Test | What It Checks |
|------|----------------|
| `test_rpc_request` | Response has `jsonrpc` field (stringified by `json_stringify`) |
| `test_rpc_connect` | `result` field equals `"connected"` (round-trip parse/stringify) |
| `test_rpc_unknown_method` | Error response code `-32601` (parsed from `json_stringify` output) |

## Usage Example

```python
from lib.json import json_stringify, json_parse

let data = {"name": "Janus", "version": 1.0}
let json_str = json_stringify(data)       # {"name":"Janus","version":1.0}
let parsed = json_parse(json_str)         # {name: "Janus", version: 1.0}
```
