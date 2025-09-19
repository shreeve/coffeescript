# AGENTS.md

## Project Overview

This is **CoffeeScript 3 (CS3)**, a revolutionary data-oriented transformation of CoffeeScript that enables compilation to any target language (JavaScript, Python, WASM, etc.) through the **Solar directive system**.

**Current Status**: 100% test pass rate (425/425 tests passing) with the CS3 parser + ES5 backend.

## Key Innovation

CS3 uses **ReductionFrame-based Solar directive evaluation** - a universal backend interface where any language can evaluate Solar directives against per-reduction frames. This replaces the old function-based grammar with pure data structures.

## Setup Commands

```bash
# Install dependencies
npm install

# Build the CS3 Solar parser (100ms generation time!)
cake build:parser-cs3

# Run CS2 tests (traditional parser - 100% pass rate)
npm test

# Run CS3 tests (Solar parser - 100% pass rate)
cake test:cs3

# Run specific CS3 test file
./bin/coffee test/cs3/08-classes.test.coffee

# Compare CS2 vs CS3 on same tests
cd test/cs3
coffee cs2-runner.coffee  # Passes 100%
coffee cs3-runner.coffee  # Passes 100%
```

## Architecture

```
CoffeeScript Code → Solar Parser → ReductionFrame → Solar Directive Evaluator → Target Code
                    (parser-cs3.js)                (backends/es5/index.coffee)   ├── JavaScript ✅
                                                                                  ├── Python (TODO)
                                                                                  └── WASM (TODO)
```

## Critical Files

### Grammar Files
- `src/grammar.coffee` - Original function-based grammar (CS2)
- `src/syntax.coffee` - Solar directive grammar (CS3)
- `lib/coffeescript/parser.js` - CS2 parser (generated from grammar.coffee)
- `lib/coffeescript/parser-cs3.js` - CS3 parser (generated from syntax.coffee)

### Backend
- `backends/es5/index.coffee` - ES5 backend that evaluates Solar directives
- `lib/backends/es5/index.js` - Compiled version (copy here after changes)

### Test Runners
- `test/cs3/cs3-runner.coffee` - Runs tests with CS3 parser + ES5 backend
- `test/cs3/cs2-runner.coffee` - Runs tests with CS2 parser (for comparison)
- `test/cs3/*.test.coffee` - 32 test files with 425 tests total

### Documentation
- `CS3_SYNTAX.md` - Complete Solar directive specification
- `test/cs3/README.md` - Test suite documentation

## Complete Feature Support

### ✅ All Features Working (425/425 tests)
- Basic literals, arrays, objects, functions
- Classes with inheritance and static properties
- String interpolation, template literals
- Exception handling (try/catch/finally)
- Loops, conditionals, operators
- Arrow functions (generates proper ES6 `() =>`)
- Destructuring with defaults and @ parameters
- Async/await, generators
- Import/export modules
- Super calls in constructors and methods
- Super with method delegation
- Nested loops and comprehensions
- Multiline implicit calls
- Ternary operators
- For-own loops

## Development Workflow

### Making Backend Changes

1. Edit `backends/es5/index.coffee`
2. Compile: `coffee -c backends/es5/index.coffee`
3. Copy to lib: `cp backends/es5/index.js lib/backends/es5/index.js`
4. Test: `cd test/cs3 && coffee cs3-runner.coffee`

### Debugging a Specific Test

```coffee
# Create a minimal test file
cat > test-debug.coffee << 'EOF'
{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

testCode = '''
# Your test code here
'''

lexer = new Lexer()
tokens = lexer.tokenize testCode

# ... (see existing debug files for full pattern)
EOF

coffee test-debug.coffee
```

### Common Debug Patterns

1. **Monitor directive evaluation**: Override `backend.evaluateDirective`
2. **Monitor node creation**: Override node constructors (e.g., `nodes.Assign`)
3. **Check AST structure**: Log the parsed AST before generation
4. **Compare with CS2**: Run same code through CS2 to see expected output

## Code Patterns

### Solar Directives (Data-Oriented)

```coffee
# Creating nodes
$ast: 'Value', val: 1              # Note: 'val' not 'base'!
$ast: '@', variable: 2, parent: 4  # @ uses rule name as type

# Operations (categorized by type)
$ops: 'array', append: [1, 3]      # Array operations
$ops: 'value', add: [1, 2]         # Value operations
$ops: 'if', addElse: [1, 3]        # If operations

# Simple references (80% of cases)
1  # Direct position reference
2  # Another position

# Complex references (20% of cases)
{$use: 1, prop: 'value'}           # Access property
```

## Git Workflow

```bash
# After making changes
coffee -c backends/es5/index.coffee
cp backends/es5/index.js lib/backends/es5/index.js
cd test/cs3
coffee cs3-runner.coffee 2>&1 | tail -5  # Check pass rate

# If good, commit
git add -A
git commit -m "Clear description of what was fixed"
git push
```

## Key Implementation Details

### Variable Context System
The backend implements a variable context (`@variableContext`) for handling `$var` and `$use` directives within sequences, essential for complex variable binding in grammar rules.

### Loop Variable Management
Nested loops use unique iterator variables (k, l, m, n...) to avoid collisions with user-declared variables.

### @ Parameter Destructuring
The backend transforms CS3's Assign nodes for @ parameters into CS2-style Value nodes with proper PropertyName access for correct thisAssignment generation.

### Super Call Handling
Super nodes preserve accessor and literal properties from the grammar, enabling proper compilation of `super.method()` calls in all contexts.

## Tips for Contributors

- The CS3 parser works correctly - backend handles AST transformation
- Always compile and copy backend changes to lib/ directory
- Use CS2 output as the "correct" reference
- The Solar directive system is documented in CS3_SYNTAX.md
- Focus on backends/es5/index.coffee for fixes

## Security Notes

- No credentials or API keys in this repo
- All test files are safe to execute
- Backend compilation is sandboxed

## Project Context

This is part of transforming CoffeeScript into a universal language that can compile to any target. The Solar directive system provides language-agnostic AST representation. This work will eventually lead to **Rip**, a truly universal programming language.

**Repository**: https://github.com/shreeve/coffeescript (cs3 branch)