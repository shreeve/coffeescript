# CoffeeScript 3: Data-Oriented Grammar Transformation

**Principle:** "Make the common case easy, and the rare case possible."

## Overview

CoffeeScript 3 (CS3) represents a paradigm shift from class-based AST nodes to data-oriented structures. This transformation enables:

- **Multi-target compilation** (ES6, Python, WASM, LLVM IR)
- **Simpler AST manipulation** (plain objects vs class instances)
- **Better performance** (no class overhead)
- **Cleaner grammar** (data declarations vs imperative code)
- **100% backward compatible** with existing CoffeeScript

## The CS3 Directive System

The CS3 directive system provides a clean, categorized approach to AST transformation with clear separation between **creation** and **operation**. Every directive starts with `$` for easy identification.

### 1️⃣ AST Creation (`$ast`)

Creates Abstract Syntax Tree nodes with a `type` field.

```coffee
# Explicit type
$ast: 'If', condition: 2, body: 3         # Creates If node
$ast: 'Value', val: 1                     # Note: 'val' not 'base'!
$ast: 'Op', args: [1, 2]                  # Positional args for Op nodes

# Implicit type (@ = use rule name)
$ast: '@', condition: 2, body: 3          # Uses rule name as type
```

### 2️⃣ Array Creation (`$ary`)

Creates arrays without a type field.

```coffee
$ary: []                # Empty array
$ary: [1]               # Single element from position 1
$ary: [1, 3, 5]         # Multiple elements from positions
$ary: [{$ast: 'Literal', value: 'foo'}]   # Can contain complex nodes
```

### 3️⃣ Object Creation (`$obj`)

Creates plain objects without a type field.

```coffee
$obj: {}                           # Empty object
$obj: {name: 1, value: 3}          # Properties from positions
$obj: {foo: 'bar', baz: 2}         # Mixed literal and positional
```

### 4️⃣ Operations (`$ops`)

Performs operations on existing objects, **categorized by type** for clarity.

#### Array Operations
```coffee
$ops: 'array', append: [1, 3]     # $1.push($3) - mutates array
$ops: 'array', gather: [1, 2, 4]  # Append + flatten multiple arrays
```

#### Value Node Operations
```coffee
$ops: 'value', add: [1, 2]        # $1.add($2) - add accessor
```

#### If Node Operations
```coffee
$ops: 'if', addElse: [1, 3]       # $1.addElse($3) - add else branch
```

#### Loop Operations
```coffee
$ops: 'loop', addBody: [1, 2]     # $1.addBody($2)
$ops: 'loop', addSource: [1, 2]   # $1.addSource($2)
```

#### Property Operations
```coffee
$ops: 'prop', set: {target: 2, property: 'implicit', value: true}
```

### 5️⃣ References (`$use`)

Access to parser stack elements, properties, methods, and variables.

```coffee
# Simple (common case - 80%)
1                                  # Direct position reference
3                                  # Element at position 3

# Complex (rare case - 20%)
{$use: 1, prop: 'value'}          # $1.value
{$use: 1, prop: 'original'}       # $1.original
{$use: 1, method: 'toString'}     # $1.toString()
{$use: 1, method: 'slice', args: [1, -1]}  # $1.slice(1, -1)
```

### 6️⃣ Control Flow

#### Sequence (`$seq`)
For multi-step operations:
```coffee
$seq: [
  {$var: 'temp', value: 1}              # Create temp variable
  {$ops: 'array', append: ['temp', 2]}  # Use temp
  {$use: 'temp'}                         # Return temp
]
```

#### If-Then-Else (`$ite`)
For conditional logic:
```coffee
$ite: {test: 1, then: 2, else: 3}       # Ternary conditional
```

### 7️⃣ Metadata (`$pos`)

Position tracking for source location:
```coffee
$pos: 1                            # Copy position from element 1
$pos: [1, 3]                       # Range from element 1 to 3
$pos: [startLine, startCol, endLine, endCol]  # Explicit position
```

## Key Design Decisions

### CREATE vs OPERATE
- **Create directives**: `$ast`, `$ary`, `$obj` - make new things
- **Operation directive**: `$ops` - modify existing things
- Clear separation prevents confusion

### Categorized Operations
Operations are grouped by what they operate on:
- `$ops: 'array', append:` - clearly an array operation
- `$ops: 'value', add:` - clearly a value operation
- No ambiguity about target type

### Semantic Naming
- `val` not `base` for Value nodes (clearer)
- `args` for Op nodes (positional parameters)
- `append` vs `gather` (mutate vs flatten)
- `addElse` not just `add` (specific to If nodes)

### Block Elimination
- No more `Block.wrap` - just use arrays!
- `Root` body is an array, not a Block
- Simpler, cleaner, no wrapper classes needed

### Common vs Rare
- **Common (80%)**: Simple numbers like `1`, `2`, `3`
- **Rare (20%)**: Complex like `{$use: 1, method: 'slice', args: [1, -1]}`
- Optimize for the common case!

## Operations Reference

### Array Operations
| Operation | Behavior | Example |
|-----------|----------|---------|
| `append` | Push to end (mutates) | `[1,2] + 3 → [1,2,3]` |
| `gather` | Append + flatten | `[1,2] + [3] + [4,5] → [1,2,3,4,5]` |

### Value Operations
| Operation | Behavior | Example |
|-----------|----------|---------|
| `add` | Add accessor/property | `value.add(accessor)` |

### If Operations
| Operation | Behavior | Example |
|-----------|----------|---------|
| `addElse` | Add else branch | `if.addElse(elseBlock)` |

### Loop Operations
| Operation | Behavior | Example |
|-----------|----------|---------|
| `addBody` | Add loop body | `for.addBody(block)` |
| `addSource` | Add loop source | `for.addSource(array)` |

### Property Operations
| Operation | Behavior | Example |
|-----------|----------|---------|
| `set` | Set property value | `obj.prop = value` |

## Pattern Analysis

Our analysis discovered that **all 399 grammar rules** follow just 12 patterns, which map elegantly to 7 directive types:

### 12 Pattern Types → 7 Directives

| Pattern Type | Example | Maps To | Directive |
|-------------|---------|---------|----------|
| 1. Passthroughs | `$1` | → | Direct number or `$use` |
| 2. Property access | `$1.original` | → | `$use` with prop |
| 3. Method calls | `$1.toString()` | → | `$use` with method |
| 4. Simple AST | `new Value $1` | → | `$ast` |
| 5. Arrays | `[]`, `[$1]` | → | `$ary` |
| 6. Plain objects | `soak: yes` | → | `$obj` |
| 7. Mutations | `$1.add $2` | → | `$ops` |
| 8. Conditionals | `if...then...else` | → | `$ite` |
| 9. Chained ops | `(new X).add` | → | `$seq` |
| 10. Multi-statement | `x = y; z` | → | `$seq` |
| 11. Helpers | `Block.wrap`, `extend` | → | `$ops` or `$ary` |
| 12. Object.assign | `Object.assign $2, ...` | → | `$ops` |

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

## Migration from Old System

### Old → New Mappings

| Old | New | Reason |
|-----|-----|--------|
| `$ops: 'concat', target: 1, args: [3]` | `$ops: 'array', append: [1, 3]` | Categorized |
| `$ops: 'addElse', target: 1, args: [3]` | `$ops: 'if', addElse: [1, 3]` | Type-specific |
| `$ast: 'Value', base: 1` | `$ast: 'Value', val: 1` | Semantic |
| `$ast: 'Op', first: 1, second: 2` | `$ast: 'Op', args: [1, 2]` | Positional |
| `$ops: 'Block.wrap', args: [1]` | `$ary: [1]` | No wrapper needed |
| `{$ref: 1}` | `1` | Simplified |
| `$ref` → `$rhs` → `$use` | `$use` | Unified all references |

## Backend Architecture

```
coffeescript/
├── src/
│   ├── grammar.coffee        # Original class-based grammar
│   ├── syntax.coffee         # NEW: Data-oriented grammar
│   ├── cs3-processor.coffee  # Processes data nodes
│   └── cs3-pattern-matcher.coffee  # Transforms patterns
├── backends/
│   ├── es6/
│   │   └── index.coffee     # ES6 code generator
│   ├── python/
│   │   └── index.coffee     # Python code generator
│   ├── wasm/
│   │   └── index.coffee     # WASM code generator
│   └── shared/
│       └── base-backend.coffee  # Shared backend interface
```

## Implementation Status

### ✅ Completed
- Directive system design
- Pattern analysis (399 rules → 12 patterns → 7 directives)
- Minimal viable implementation for `square.coffee`
- Core transformation engine (`cs3-pattern-matcher-v2.coffee`)
- Data node processor (`cs3-processor.coffee`)
- Basic ES6 backend
- Integration testing framework
- Major optimizations:
  - `$ref` → `$use` (better naming)
  - `{$use: 1}` → `1` (simplified references)
  - Categorized operations (`$ops: 'array', append:`)
  - Semantic property names (`val` not `base`)
  - `Block.wrap` elimination (just use arrays)

### 🚧 In Progress
- Full `syntax.coffee` transformation (350/399 rules done)
- Remaining TODOs: Complex For loops, value operations

### 📋 TODO
- Complete backend implementations
- Source map support
- Optimization passes
- Documentation and examples

## Benefits

1. **Type Safety**: Categorized operations prevent misuse
2. **Readability**: Intent is crystal clear
3. **Simplicity**: Common cases are trivial
4. **Extensibility**: Easy to add new operations or backends
5. **Consistency**: All directives follow same patterns
6. **Performance**: No class instantiation overhead
7. **No Magic**: Everything is explicit and traceable

## The Philosophy

This transformation embodies several key principles:

- **Data over Code**: Declarative data structures over imperative actions
- **Explicit over Implicit**: Clear directives over hidden behavior
- **Simple over Complex**: Arrays over wrapper classes
- **Categorized over Flat**: Grouped operations over generic names
- **Common over Rare**: Optimize for the 80% case

## Future: The Rip Programming Language

CoffeeScript 3 is a stepping stone toward **Rip**, a truly universal programming language that can compile to any target. The data-oriented AST is the foundation that makes this possible.

Rip will:
- Use CS3's data-oriented AST as its IR
- Support gradual typing
- Compile to any language or runtime
- Provide seamless interop with host platforms
- Enable true "write once, run anywhere"

## Conclusion

The CS3 transformation represents a fundamental reimagining of how parsers and compilers can work. By separating the **what** (data structures) from the **how** (implementation), we gain unprecedented flexibility and clarity.

The journey from CoffeeScript's elegant syntax through CS3's data-oriented transformation to Rip's universal compilation is not just an evolution—it's a revolution in how we think about programming languages.
