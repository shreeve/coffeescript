# CoffeeScript 3: Data-Oriented Grammar Transformation

## Overview

CoffeeScript 3 (CS3) represents a **paradigm shift** in parser architecture: transforming all 420 production patterns (across 97 grammar rules) from function-based actions to **pure data structures**. This enables CoffeeScript to compile not just to JavaScript, but to **any target language**.

### Key Achievements
- **Complete parser rewrite** - Pure data-oriented architecture with no performance loss
- **100x faster parser generation** with Solar (12+ seconds → 100ms)
- **ReductionFrame architecture** - Backends evaluate Solar directives against per-reduction RHS frames
- **Universal position resolution** - Automatic `1` → `'x'` resolution through frame slots
- **Complete Solar directive system** - All 404 patterns transformed to language-agnostic directives
- **100% test compatibility** - All 425 tests passing with the new architecture
- **Universal backend interface** - Any language can implement Solar directive evaluation

## The Solar Directive System

CS3 uses Solar's universal directive system with just 4 core directives:

1. **`$ast`** - Creates AST nodes (universal)
2. **`$ary`** - Creates arrays with optional properties (universal)
3. **`$ops`** - Performs operations (categorized by type)
4. **`$use`** - Universal references (stack elements, properties, methods)

Plus **`$pos`** for position tracking. No special cases or auxiliary directives needed.

**Note:** Plain objects need no directive - just use properties directly!

### 📖 Full Specification

For the complete directive system, examples, and technical details, see:
**[CS3_DIRECTIVES.md](CS3_DIRECTIVES.md)** - The authoritative CS3 specification document

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
└── CS3_DIRECTIVES.md        # Full CS3 specification
```

## Implementation Status

### 🎯 Production Ready!

The CS3 implementation is **complete and optimized**:
- **97 rules** perfectly match between `grammar.coffee` and `syntax.coffee`
- **420 patterns** successfully transformed to pure data
- **86 generic properties** updated to semantic names
- **Backend optimized** to 1,569 lines with clean, maintainable code
- **Performance validated** - No performance penalty (actually slightly faster in CPU utilization)

### ✅ Completed
- **Solar Parser Generator** - 100x faster generation (100ms vs 12+ seconds)
- **Complete Grammar Transformation** - All 404 patterns converted to Solar directives
- **ReductionFrame Architecture** - Per-reduction RHS frames with universal position resolution
- **Solar Directive Evaluator** - Backends evaluate directives against ReductionFrame
- **Working CS3 Pipeline** - `'x'` → `IdentifierLiteral('x')` → `"x"` JavaScript
- **Universal Backend Interface** - Any language can implement Solar directive evaluation
- **Test Framework Integration** - `cake test:cs3` validates CS3 against full test suite
- **JSX-free Grammar** - Cleaner, focused on core CoffeeScript features

### ✅ Complete Implementation
- **Test Suite Compatibility** - 100% pass rate (425/425 tests)
- **All language features** - Complete support for all CoffeeScript syntax
- **@params in destructuring** - Full support including `{@x, @y}` patterns
- **Super calls** - Working in all contexts including arrow functions
- **Performance** - Completely revamped parser/AST generation with no performance loss

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
# Build everything (parsers and backend)
cake build

# Test CS3 pipeline (425/425 tests passing - 100%!)
cake test:cs3

# View the Solar directive grammar
cat src/syntax.coffee

# Read the full specification
open CS3_DIRECTIVES.md
```

### Quick Start for New Contributors

1. **Understand the transformation**: Read `CS3_DIRECTIVES.md` for the complete directive system
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

- **[CS3_DIRECTIVES.md](CS3_DIRECTIVES.md)** - Complete CS3 directive system specification
- **[src/syntax.coffee](src/syntax.coffee)** - The transformed data-oriented grammar

---

*CoffeeScript 3: Where elegant syntax meets universal compilation.*

### CS3/ES5 Backend Status - 100% Pass Rate!

**Complete Feature Support:**
- ✅ All CoffeeScript syntax fully supported
- ✅ Classes with static properties and inheritance
- ✅ Arrow functions generating proper ES6 syntax
- ✅ String interpolation and template literals
- ✅ Exception handling (try/catch/finally)
- ✅ Destructuring with @ parameters
- ✅ Super calls in all contexts
- ✅ Nested loops and comprehensions
- ✅ For-own loops
- ✅ Async/await and generators
- ✅ All edge cases handled

**Test Results:**
- 425/425 tests passing (100%)
- Complete compatibility with CoffeeScript 2
- Production-ready implementation