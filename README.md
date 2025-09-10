# CS3: The Road to CoffeeScript 3 (and Beyond to Rip)

## The Vision

CoffeeScript 3 represents a **revolutionary leap** in parser architecture: transforming all 399 grammar rules from function-based actions to **pure data structures**. This enables CoffeeScript to compile not just to JavaScript, but to **any target language**.

More importantly, CS3 is the **technological foundation** for the evolution into **Rip** — a next-generation programming language that takes these data-oriented principles to their ultimate conclusion.

```
CoffeeScript Code → Parser → Data Nodes → [Choose Your Backend!]
                                          ├── ES6 Generator
                                          ├── TypeScript Generator
                                          ├── Python Generator
                                          ├── WASM Generator
                                          ├── LLVM IR Generator
                                          └── Any Future Target!
```

## The Journey

### Where We Started
- **56.2x faster** parser generation with Solar (from 9.89s → 176ms)
- **91% smaller** parser size with Brotli compression (303KB → 27KB)
- Class-based AST with tight coupling to JavaScript

### Where We're Going
- **Universal AST** as pure data structures
- **Multi-target compilation** (not just JavaScript!)
- **Tool-friendly** format for analysis and transformation
- **100% backward compatible** with existing CoffeeScript

## The Seven Data Node Types

Every grammar action in CS3 can be represented using one of these seven data node types. All special directives begin with `$` for consistency and easy identification.

### Position Tracking

Every node includes position information for error reporting, source maps, and tooling:

```typescript
$pos: [startLine, startCol, endLine, endCol]  // 1-indexed
```

Example: `$pos: [10, 2, 14, 5]` means the node spans from line 10 column 2 to line 14 column 5.

### Complete Type Signatures

```typescript
// 1. Reference Node
{$ref: number, prop?: string, call?: string, args?: any[], $pos?: Pos}

// 2. AST Node
{$ast: string | '@', ...properties: any, $pos?: Pos}

// 3. Array Node
{$array: any[], $pos?: Pos} | {$array: {$concat: any[][]}, $pos?: Pos}

// 4. Operation Node
{$op: string, target?: any, args: any[], prop?: string, $pos?: Pos}

// 5. Conditional Node
{$cond: {test: any, then: any, else: any}, $pos?: Pos}

// 6. Sequence Node
{$seq: any[], $as?: string, $use?: string, $pos?: Pos}

// 7. Plain Object Node
{[key: string]: any, $pos?: Pos}  // No other $ prefixed keys

type Pos = [number, number, number, number]  // [startLine, startCol, endLine, endCol]
```

## 1. Reference Node (`$ref`)

**Purpose:** Parameter references with optional property access or method calls

**Signature:** `{$ref: number, prop?: string, call?: string, args?: any[], $pos?: Pos}`

### Examples
```coffee
# Simple reference
$1                              → {$ref: 1, $pos: [1, 1, 1, 2]}
$2                              → {$ref: 2, $pos: [2, 5, 2, 6]}
<passthrough>                   → {$ref: 1, $pos: [1, 1, 1, 12]}

# Property access
$1.original                     → {$ref: 1, prop: 'original', $pos: [3, 1, 3, 11]}
$1.generated                    → {$ref: 1, prop: 'generated', $pos: [4, 1, 4, 12]}

# Method calls
$1.toString()                   → {$ref: 1, call: 'toString', args: [], $pos: [5, 1, 5, 13]}
$1.slice(1, -1)                → {$ref: 1, call: 'slice', args: [1, -1], $pos: [6, 1, 6, 15]}
```

## 2. Type Node (`$type`)

**Purpose:** Creates Abstract Syntax Tree nodes with the specified type and properties

**Signature:** `{$type: string | '@', ...properties: any, $pos?: Pos}`

**Special Value:** `'@'` means use the production rule name as the type

### Examples
```coffee
# Implicit type (using '@' for rule name)
# In Root rule:
o 'Body', $type: '@', body: $ref: 1
→ {$type: 'Root', body: {$ref: 1}, $pos: [1, 1, 1, 12]}

# In Block rule:
o 'INDENT Body OUTDENT', $type: '@', statements: $ref: 2
→ {$type: 'Block', statements: {$ref: 2}, $pos: [2, 1, 2, 24]}

# Explicit type (when different from rule name)
# In Identifier rule:
o 'IDENTIFIER', $type: 'IdentifierLiteral', name: $ref: 1
→ {$type: 'IdentifierLiteral', name: {$ref: 1}, $pos: [3, 1, 3, 9]}

# Complex AST nodes
new If $2, $3, type: $1         → {
  $type: 'If',
  test: {$ref: 2},
  consequent: {$ref: 3},
  kind: {$ref: 1},
  $pos: [10, 1, 14, 5]
}

new Op '+', $1, $3              → {
  $type: 'Op',
  operator: '+',
  left: {$ref: 1},
  right: {$ref: 3},
  $pos: [15, 3, 15, 18]
}
```

## 3. Array Node (`$array`)

**Purpose:** Array literals and concatenation operations

**Signature:** `{$array: any[], $pos?: Pos} | {$array: {$concat: any[][]}, $pos?: Pos}`

### Examples
```coffee
# Array literals
[]                              → {$array: [], $pos: [1, 1, 1, 2]}
[$1]                            → {$array: [{$ref: 1}], $pos: [2, 1, 2, 4]}
[$1, $3]                        → {$array: [{$ref: 1}, {$ref: 3}], $pos: [3, 1, 3, 8]}

# Concatenation
$1.concat $3                    → {$array: {$concat: [{$ref: 1}, {$ref: 3}]}, $pos: [4, 1, 4, 12]}
[].concat $2, $3                → {$array: [{$ref: 2}, {$ref: 3}], $pos: [5, 1, 5, 16]}
```

## 4. Operation Node (`$op`)

**Purpose:** Method calls, mutations, and helper functions

**Signature:** `{$op: string, target?: any, args: any[], prop?: string, $pos?: Pos}`

### Examples
```coffee
# Method calls on nodes
$1.addBody $2                   → {$op: 'addBody', target: {$ref: 1}, args: [{$ref: 2}], $pos: [1, 1, 1, 13]}
$1.push $3                      → {$op: 'push', target: {$ref: 1}, args: [{$ref: 3}], $pos: [2, 1, 2, 10]}

# Helper functions
Block.wrap [$1]                 → {$op: 'Block.wrap', args: [{$array: [{$ref: 1}]}], $pos: [3, 1, 3, 15]}
extend $2, soak: yes            → {$op: 'extend', args: [{$ref: 2}, {soak: true}], $pos: [4, 1, 4, 20]}
LOC(1) $1                       → {$op: 'LOC', args: [1, {$ref: 1}], $pos: [5, 1, 5, 9]}
```

## 5. Conditional Node (`$cond`)

**Purpose:** Ternary conditionals and if-then-else expressions

**Signature:** `{$cond: {test: any, then: any, else: any}, $pos?: Pos}`

### Examples
```coffee
# Ternary expressions
if $2.exclusive then 'exclusive' else 'inclusive' → {
  $cond: {
    test: {$ref: 2, prop: 'exclusive'},
    then: 'exclusive',
    else: 'inclusive'
  },
  $pos: [1, 1, 1, 50]
}
```

## 6. Sequence Node (`$seq`)

**Purpose:** Multiple operations executed in order, with optional temporary variables

**Signature:** `{$seq: any[], $as?: string, $use?: string, $pos?: Pos}`

### Examples
```coffee
# Chained operations
(new Value $1).add $2           → {
  $seq: [
    {$type: 'Value', base: {$ref: 1}, properties: [], $as: 'temp'},
    {$op: 'add', target: {$use: 'temp'}, args: [{$ref: 2}]}
  ],
  $pos: [1, 1, 1, 21]
}

# Multi-statement actions
$2.implicit = $1.generated; $2  → {
  $seq: [
    {$op: 'set', target: {$ref: 2}, prop: 'implicit', value: {$ref: 1, prop: 'generated'}},
    {$ref: 2}
  ],
  $pos: [2, 1, 2, 30]
}

# Destructuring
[name, index] = $3              → {
  $seq: [
    {$op: 'destructure', pattern: ['name', 'index'], value: {$ref: 3}},
    {$use: 'destructured'}
  ],
  $pos: [3, 1, 3, 18]
}
```

## 7. Plain Object Node (`$obj`)

**Purpose:** Simple property objects that should NOT have an AST type

**Signature:** `{$obj: true, ...properties: any, $pos?: Pos}`

### Examples
```coffee
# Option objects for FOR loops
# In ForSource rule:
o 'FORIN Expression', $obj: yes, source: $ref: 2
→ {source: {$ref: 2}, $pos: [1, 1, 1, 8]}  # No 'type' field!

o 'FOROF Expression', $obj: yes, source: $ref: 2, object: yes
→ {source: {$ref: 2}, object: true, $pos: [2, 1, 2, 12]}

o 'FORIN Expression WHEN Expression', $obj: yes, source: $ref: 2, guard: $ref: 4
→ {source: {$ref: 2}, guard: {$ref: 4}, $pos: [3, 1, 3, 21]}

# Other option objects
soak: yes                       → {soak: true, $pos: [4, 1, 4, 8]}
exclusive: no                   → {exclusive: false, $pos: [5, 1, 5, 12]}
```

## Terminology

**Official CS3 Terms:**

- **Data Node** - Any of the 7 node types (the data structures we create)
- **Node Type** - One of the 7 categories (Reference, Type, Array, Operation, Conditional, Sequence, Plain Object)
- **Pattern Type** - One of the 12 grammar action patterns we match during transformation
- **Directive** - Any property starting with `$` (e.g., `$ref`, `$type`, `$op`, `$pos`)
- **Position** - The `$pos` array tracking source location: `[startLine, startCol, endLine, endCol]` (1-indexed)
- **Processor** - Code that interprets a data node for a specific backend (ES6Processor, PythonProcessor, etc.)
- **Backend** - Complete implementation for a target language (ES6Backend, WASMBackend, etc.)

## Pattern Analysis

### 12 Pattern Types → 7 Data Node Types

Our analysis discovered that **all 399 grammar rules** follow just 12 patterns, which map elegantly to 7 data node types:

| Pattern Type | Example | Maps To | Node Type |
|-------------|---------|---------|----------|
| 1. Passthroughs | `$1`, `<passthrough>` | → | **Reference Node** |
| 2. Property access | `$1.original` | → | **Reference Node** (with prop) |
| 3. Method calls | `$1.toString()` | → | **Reference Node** (with call) |
| 4. Simple AST | `new Value $1` | → | **Type Node** |
| 5. Arrays | `[]`, `[$1]` | → | **Array Node** |
| 6. Plain objects | `soak: yes` | → | **Plain Object Node** |
| 7. Mutations | `$1.add $2` | → | **Operation Node** |
| 8. Conditionals | `if...then...else` | → | **Conditional Node** |
| 9. Chained ops | `(new X).add` | → | **Sequence Node** |
| 10. Multi-statement | `x = y; z` | → | **Sequence Node** |
| 11. Helpers | `Block.wrap`, `extend` | → | **Operation Node** |
| 12. Object.assign | `Object.assign $2, ...` | → | **Operation Node** |

**The Rule:** Every grammar action → matches 1 of 12 patterns → becomes 1 of 7 node types

### Frequency Distribution

| Pattern Category | Count | Percentage | Impact |
|-----------------|-------|------------|--------|
| **Instant Wins** | | | |
| Passthroughs | 60 | 15% | No transformation needed! |
| Arrays/Concat | 40 | 10% | Already data! |
| Plain Objects | 50 | 12% | Already data! |
| **High Impact** | | | |
| AST Creation | 130 | 33% | Simple pattern matching |
| **Long Tail** | | | |
| Method Calls | 20 | 5% | Straightforward ops |
| Complex Logic | 99 | 25% | Needs careful handling |

**Key Insight:** 40% of rules need NO transformation, 70% handled by simple patterns!

## Multi-Backend Architecture

### Universal Compilation Pipeline

```coffee
# One Grammar, Multiple Outputs
Grammar → Parser → Data Nodes → Backend Processor → Target Code
                       ↑
                       |
              Universal Interface
                       |
        ┌──────────────┼──────────────┐
        |              |              |
   ES6Backend    PythonBackend  WASMBackend
```

### Example: Same Data Node, Different Outputs

```coffee
# Data Node (Universal Representation)
{
  $type: 'If',
  test: {$type: 'BinaryOp', op: '>', left: {$ref: 1}, right: {$type: 'Number', value: 0}},
  consequent: {$type: 'Call', callee: 'print', args: [{$type: 'String', value: 'positive'}]},
  alternate: null
}

# ES6 Output
if (x > 0) {
  print("positive");
}

# Python Output
if x > 0:
    print("positive")

# WASM Output (WAT)
(if (i32.gt_s (local.get $x) (i32.const 0))
  (then (call $print (i32.const 0)))
)
```

### Backend Implementation

```coffee
class ES6Backend
  processNode: (node) ->
    # Position info available for error reporting
    pos = node.$pos  # [startLine, startCol, endLine, endCol]

    return @processReference(node)    if node.$ref?
    return @processASTNode(node)      if node.$type?
    return @processArray(node)        if node.$array?
    return @processOperation(node)    if node.$op?
    return @processConditional(node)  if node.$cond?
    return @processSequence(node)     if node.$seq?
    return @processPlainObject(node)

class PythonBackend
  # Same interface, different implementation!
  processNode: (node) ->
    # Python-specific code generation
    # Can use node.$pos for source maps
```

## Implementation Details

### Pattern Matching

The transformation requires ~12 pattern matchers that map to these 7 data node types:

```coffee
patterns = [
  # Simple references
  /^\$(\d+)$/                    # → {$ref: 1}
  /^<passthrough>$/              # → {$ref: 1}

  # Property/method access
  /^\$(\d+)\.(\w+)$/            # → {$ref: 1, prop: 'propertyName'}
  /^\$(\d+)\.(\w+)\((.*)\)$/   # → {$ref: 1, call: 'methodName', args: [...]}

  # AST nodes
  /^new (\w+)\s*(.*)$/          # → {$type: 'ClassName', ...parseArgs(...)}

  # Arrays
  /^\[(.*)\]$/                  # → {$array: [parseElements('1')]}
  /^\$(\d+)\.concat\s+(.*)$/    # → {$array: {$concat: [...]}}

  # Operations
  /^\$(\d+)\.(add|push|...)$/   # → {$op: 'methodName', target: {$ref: 1}, ...}
  /^(Block\.wrap|extend)\s+/    # → {$op: 'helperName', args: [...]}

  # Conditionals
  /^if .* then .* else .*$/     # → {$cond: {...}}

  # Complex
  /\(new .+\)\.\w+/             # → {$seq: [...]}
  /.*;.*$/                       # → {$seq: [...]}
]
```

### Processing Data Nodes

```coffee
processNode = (node, params) ->
  # Position available for all nodes
  if node.$pos? and params.trackPositions
    @recordPosition(node.$pos)

  # Check for $ directives
  if node.$ref?    then return processReference(node, params)
  if node.$type?   then return createASTNode(node, params)
  if node.$array?  then return processArray(node, params)
  if node.$op?     then return processOperation(node, params)
  if node.$cond?   then return processConditional(node, params)
  if node.$seq?    then return processSequence(node, params)

  # No $ fields (except $pos) = plain object
  return processPlainObject(node, params)
```

## Comparison with Other Approaches

| Project | Approach | Pros | Cons |
|---------|----------|------|------|
| **Babel/TypeScript** | Hand-written parser | Full control | Thousands of lines |
| **Ohm.js** | Separate grammar/semantics | Clean separation | Two-phase processing |
| **PEG.js** | Embedded JS actions | Simple | Grammar tied to JS |
| **Tree-sitter** | Declarative fields | Automatic nodes | Less flexible |
| **CoffeeScript 3** | Data-only actions | Pure data, multi-target | Need processors |

CS3's approach is **unique**: keeping actions IN the grammar but as DATA instead of code!

## Benefits

### For Developers
1. **Multi-target compilation**: Write CoffeeScript, deploy anywhere
2. **Better tooling**: AST explorers, linters, type checkers
3. **Easier debugging**: Data is inspectable, serializable

### For the Language
1. **Future-proof**: New backends without grammar changes
2. **Standardizable**: Could define an ESTree-like standard
3. **Optimizable**: Data transformations before code generation

### Technical Advantages
1. **Declarative**: Grammar is pure data, no function execution
2. **Consistent**: All special directives use `$` prefix
3. **Complete**: All 399 existing grammar rules represented
4. **Type-safe**: Clear structure for TypeScript/Flow
5. **Testable**: Data transformations easier than functions
6. **Portable**: Serializable to JSON, MessagePack, etc.

## Backend Architecture

### Naming Convention

**Backend** = Complete implementation for compiling CS3 data nodes to a target language

Examples:
- **ES6Backend** - Compiles to ES6 JavaScript
- **PythonBackend** - Compiles to Python 3
- **WASMBackend** - Compiles to WebAssembly
- **TypeScriptBackend** - Compiles to TypeScript with types
- **RustBackend** - Compiles to Rust

### Directory Structure

```
coffeescript/
├── src/
│   ├── grammar.coffee       # Original grammar
│   └── grammar-cs3.coffee   # Transformed data-oriented grammar
├── backends/
│   ├── es6/
│   │   ├── index.coffee     # ES6Backend main class
│   │   ├── emitter.coffee   # Code generation
│   │   ├── optimizer.coffee # ES6-specific optimizations
│   │   ├── helpers.js       # Runtime helpers
│   │   ├── test/            # Backend-specific tests
│   │   └── README.md        # ES6 backend documentation
│   ├── python/
│   │   ├── index.coffee     # PythonBackend main class
│   │   ├── emitter.coffee   # Python code generation
│   │   ├── pythonic.coffee  # Python idiom transformer
│   │   ├── stdlib.py        # Python runtime support
│   │   └── examples/        # Example compilations
│   ├── wasm/
│   │   ├── index.coffee     # WASMBackend main class
│   │   ├── wat.coffee       # WAT text format emitter
│   │   ├── binary.coffee    # WASM binary emitter
│   │   ├── memory.coffee    # Memory management
│   │   └── spec/            # WASM specifications
│   └── shared/
│       ├── base.coffee      # BaseBackend class
│       ├── visitor.coffee   # AST visitor utilities
│       └── sourcemap.coffee # Source map generation
└── work/                     # Development workspace
```

### Backend Interface

```coffee
# backends/shared/base.coffee
class BaseBackend
  constructor: (@options = {}) ->
    @sourceMaps = @options.sourceMaps ? false
    @optimize = @options.optimize ? false

  compile: (dataNodes) ->
    # Main entry point
    ast = @preprocess(dataNodes)
    code = @emit(ast)
    code = @optimize(code) if @optimize
    @postprocess(code)

  processNode: (node) ->
    # Must be implemented by each backend
    throw new Error("processNode must be implemented")
```

### Why Directories (Not Single Files)

1. **Complexity** - Backends need multiple components (emitter, optimizer, runtime)
2. **Testing** - Each backend needs its own test suite
3. **Documentation** - EBNF grammars, examples, usage guides
4. **Evolution** - Room to grow as backends mature
5. **Resources** - Templates, helpers, standard libraries

## Implementation Roadmap

### Phase 1: Foundation (Current)
✅ Solar parser generator (56.2x speedup)
✅ Grammar analysis (399 rules → 12 patterns → 7 node types)
✅ CS3 specification document
✅ Node type definitions with position tracking
⬜ Pattern matcher implementation

### Phase 2: Transformation
⬜ Transform grammar.coffee using pattern matchers
⬜ Implement 7 node processors
⬜ Create compatibility layer
⬜ Validate with test suite (1473 tests)

### Phase 3: Backend Implementation
⬜ BaseBackend abstract class (shared/base.coffee)
⬜ ES6Backend (default, backward compatible)
⬜ TypeScriptBackend (with type inference)
⬜ PythonBackend (proof of concept)
⬜ WASMBackend (performance)

### Phase 4: Ecosystem
⬜ AST explorer tool
⬜ Plugin system for custom backends
⬜ Documentation and migration guide
⬜ Community feedback and iteration

## Success Metrics

- **100% backward compatibility** (all 1473 tests pass)
- **No performance regression** (< 4s test suite)
- **At least 3 working backends** (ES6, TypeScript, one other)
- **Reduced parser complexity** (data vs functions)
- **Community adoption** (plugins, tools, backends)

## The Promise of CS3

CoffeeScript 3 isn't just an update—it's a **paradigm shift**. By treating the AST as pure data, we unlock possibilities that were previously unimaginable:

- Compile CoffeeScript to Python for data science
- Generate WASM for browser performance
- Target LLVM for native applications
- Create domain-specific backends (SQL, GraphQL, etc.)

The grammar becomes a **universal translator**, and CoffeeScript becomes not just a language, but a **platform for language innovation**.

## The Ultimate Destination: Rip

While CoffeeScript 3 revolutionizes the existing language, it also serves as the **proving ground** for something greater: **Rip**, a new programming language that:

- **Builds on** CS3's data-oriented grammar foundation
- **Transcends** the JavaScript ecosystem limitations
- **Targets** multiple platforms natively from day one
- **Embraces** the "grammar as data" philosophy at its core

The journey from CoffeeScript → CS3 → Rip represents an evolution from:
- **Language tied to JavaScript** → **Language with multiple targets** → **Truly universal language**

### Why This Path?

1. **CS3 proves the concept** with an existing, battle-tested language
2. **Real-world validation** through CoffeeScript's user base
3. **Incremental evolution** allows learning and refinement
4. **Community building** around the data-oriented approach

Rip will inherit all the lessons learned from CS3, starting with a clean slate and the power of universal compilation built-in from the beginning.

---

*"The best abstractions are those that hide complexity while revealing possibility."* - CS3 Philosophy

*"Every language should compile to every platform."* - The Rip Manifesto
