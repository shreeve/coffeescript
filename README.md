# CoffeeScript 3: Data-Oriented Grammar Transformation

## Overview

CoffeeScript 3 (CS3) represents a **paradigm shift** in parser architecture: transforming all 420 production patterns (across 97 grammar rules) from function-based actions to **pure data structures**. This enables CoffeeScript to compile not just to JavaScript, but to **any target language**.

### Key Achievements
- **100x faster** parser generation with Solar (12+ seconds → 100ms)
- **ReductionFrame architecture** - backends evaluate Solar directives against per-reduction RHS frames
- **Universal position resolution** - automatic `1` → `'x'` resolution through frame slots
- **Complete Solar directive system** - all 404 patterns transformed to language-agnostic directives
- **Working CS3 pipeline** - `'x'` → `IdentifierLiteral('x')` → `"x"` JavaScript
- **Revolutionary backend interface** - any language can implement Solar directive evaluation

## The Solar Directive System

CS3 uses Solar's universal directive system - 6 language-agnostic directives that work for any grammar:

1. **`$ast`** - Creates AST nodes (universal)
2. **`$ary`** - Creates arrays (universal)
3. **`$ops`** - Performs operations (categorized by type)
4. **`$use`** - Universal references (stack elements, properties, methods, variables)
5. **`$seq`** - Sequences of operations (universal)
6. **`$ite`** - If-Then-Else conditionals (universal)

Plus **`$pos`** for position tracking and **`$var`** for temporary variables.

**Note:** Plain objects need no directive - just use properties directly!

### 📖 Full Specification

For the complete directive system, examples, and technical details, see:
**[CS3_SYNTAX.md](CS3_SYNTAX.md)** - The authoritative CS3 specification document

## Quick Example

```coffee
# Old (function-based)
SimpleAssignable: [
  o 'Identifier', -> new Value $1
]
Class: [
  o 'CLASS SimpleAssignable EXTENDS Expression', -> new Class $2, $4
]

# New (data-oriented with semantic names)
SimpleAssignable: [
  o 'Identifier', $ast: 'Value', val: 1  # 'val' not 'base'!
]
Class: [
  o 'CLASS SimpleAssignable EXTENDS Expression', $ast: '@', variable: 2, parent: 4
  # Clear semantic names: 'variable' and 'parent', not 'arg1' and 'arg2'
]
```

## Architecture

```
CoffeeScript Code → Solar Parser → ReductionFrame → Solar Directive Evaluator → Target Code
                    (100ms gen)     (Per-reduction   (Universal backend)       ├── JavaScript ✅
                                    RHS frames)                               ├── Python
                                                                              ├── WASM
                                                                              └── Any Language
```

**ReductionFrame Innovation**: Backends evaluate Solar directives against **per-reduction RHS frames**, enabling:
- **Universal position resolution** (`1` → actual token value)
- **Language-agnostic evaluation** (any backend can implement Solar directive processing)
- **Clean separation** (parser stays dumb, backends stay smart)

### Project Structure

```
coffeescript/
├── src/
│   ├── grammar.coffee        # Original class-based grammar
│   ├── syntax.coffee         # NEW: Data-oriented grammar
│   └── cs3-*.coffee          # CS3 transformation tools
├── backends/
│   ├── es6/                  # JavaScript backend
│   ├── python/               # Python backend (planned)
│   └── wasm/                 # WebAssembly backend (planned)
└── CS3_SYNTAX.md            # Full CS3 specification
```

## Implementation Status

### 🎯 Validation Complete!

The transformation has been **thoroughly validated**:
- **97 rules** perfectly match between `grammar.coffee` and `syntax.coffee`
- **420 patterns** successfully transformed to pure data
- **86 generic properties** updated to semantic names
- **Zero** remaining function calls, class instantiations, or helper functions

### ✅ Completed
- **Solar Parser Generator** - 100x faster generation (100ms vs 12+ seconds)
- **Complete Grammar Transformation** - All 404 patterns converted to Solar directives
- **ReductionFrame Architecture** - Per-reduction RHS frames with universal position resolution
- **Solar Directive Evaluator** - Backends evaluate directives against ReductionFrame
- **Working CS3 Pipeline** - `'x'` → `IdentifierLiteral('x')` → `"x"` JavaScript
- **Universal Backend Interface** - Any language can implement Solar directive evaluation
- **Test Framework Integration** - `cake test:cs3` validates CS3 against full test suite
- **JSX-free Grammar** - Cleaner, focused on core CoffeeScript features

### 🚧 In Progress
- **Test Suite Compatibility** - At 97.2% pass rate (413/425 tests)
- **@params in constructors** - Need thisAssignments after super() calls
- **Else-if chains** - Fixing else branch preservation
- **Nested loops** - Variable name collision prevention

### 📋 TODO
- Complete additional backend implementations (Python, WASM, LLVM)
- Source map support for debugging
- AST explorer tool for visualization
- Plugin system for custom backends
- Performance benchmarking suite

## Key Innovation

CS3's approach is **revolutionary**: **Solar directives** provide universal, language-agnostic AST representation!

This means:
- **Direct directive consumption** - backends process Solar directives without normalization
- **Universal target support** - any language can consume Solar directives
- **Parser generator agnostic** - Solar directives work with any grammar
- **Zero intermediate formats** - clean, minimal data pipeline

## The Future: Rip

CoffeeScript 3 is a stepping stone toward **Rip**, a truly universal programming language that:
- Builds on CS3's data-oriented foundation
- Targets multiple platforms natively
- Provides seamless interop with any host platform
- Enables true "write once, run anywhere"

## Getting Started

```bash
# Build the CS3 Solar parser
cake build:parser-cs3

# Test CS2 CoffeeScript (1470/1473 tests passing)
npm test

# Test CS3 pipeline (413/425 tests passing - 97.2%!)
cake test:cs3

# View the Solar directive grammar
cat src/syntax.coffee

# Read the full specification
open CS3_SYNTAX.md
```

### Quick Start for New Contributors

1. **Understand the transformation**: Read `CS3_SYNTAX.md` for the complete directive system
2. **Compare the grammars**: Open `src/grammar.coffee` (old) and `src/syntax.coffee` (new) side by side
3. **See it in action**: Look at the `Class` rule transformation as a representative example
4. **Key insight**: We're not changing WHAT the grammar does, just HOW it's expressed (functions → data)

## Contributing

CS3 is an ambitious project that needs community involvement:

1. **Backend Development** - Help implement Python, WASM, or other backends
2. **Testing** - Ensure compatibility with existing CoffeeScript code
3. **Tooling** - Build AST explorers, linters, and development tools
4. **Documentation** - Improve examples and migration guides

## Philosophy

> "Make the common case easy, and the rare case possible."

> "The best abstractions are those that hide complexity while revealing possibility."

> "Every language should compile to every platform." - The Rip Manifesto

## Learn More

- **[CS3_SYNTAX.md](CS3_SYNTAX.md)** - Complete CS3 directive system specification
- **[src/syntax.coffee](src/syntax.coffee)** - The transformed data-oriented grammar

---

*CoffeeScript 3: Where elegant syntax meets universal compilation.*

### CS3/ES5 Backend Status - 97.2% Pass Rate!

**Major Achievements:**
- ✅ Static properties (@staticProp) - FIXED
- ✅ Arrow functions generating proper ES6 syntax
- ✅ String interpolation fully working
- ✅ Exception handling complete
- ✅ Class inheritance and super calls

**Remaining Issues (12 failing tests):**
- @params in derived constructors with super() - needs thisAssignments after super
- Else-if chains losing else branches (3 tests)
- Nested loops variable collision (2 tests)
- Nested comprehensions and for-own loops (2 tests)
- Multiline implicit calls and nested ternary operators (2 tests)
- Super with method delegation (1 test)
- Implicit returns in complex conditionals (2 tests)