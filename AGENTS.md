# AGENTS.md

## Project Overview

This is **CoffeeScript 3 (CS3)**, a revolutionary data-oriented transformation of CoffeeScript that enables compilation to any target language (JavaScript, Python, WASM, etc.) through the **Solar directive system**.

**Current Status**: 97.2% test pass rate (413/425 tests passing) with the CS3 parser + ES5 backend.

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

# Run CS3 tests (Solar parser - 97.2% pass rate)
cake test:cs3

# Run specific CS3 test file
./bin/coffee test/cs3/08-classes.test.coffee

# Compare CS2 vs CS3 on same tests
cd test/cs3
coffee cs2-runner.coffee  # Should pass 100%
coffee cs3-runner.coffee  # Currently 413/425 (97.2%)
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
- `src/syntax.coffee` - NEW: Solar directive grammar (CS3)
- `lib/coffeescript/parser.js` - CS2 parser (generated from grammar.coffee)
- `lib/coffeescript/parser-cs3.js` - CS3 parser (generated from syntax.coffee)

### Backend
- `backends/es5/index.coffee` - ES5 backend that evaluates Solar directives
- `lib/backends/es5/index.js` - Compiled version (copy here after changes!)

### Test Runners
- `test/cs3/cs3-runner.coffee` - Runs tests with CS3 parser + ES5 backend
- `test/cs3/cs2-runner.coffee` - Runs tests with CS2 parser (for comparison)
- `test/cs3/*.test.coffee` - 32 test files with 425 tests total

### Documentation
- `CS3_SYNTAX.md` - Complete Solar directive specification
- `test/cs3/PROGRESS.md` - Detailed fix history and current issues
- `test/cs3/README.md` - Test suite documentation

## Current Working State

### ✅ What's Working (413 tests)
- Basic literals, arrays, objects, functions
- Classes with inheritance and **static properties** (just fixed!)
- String interpolation, template literals
- Exception handling (try/catch/finally)
- Loops, conditionals, operators
- Arrow functions (generates proper ES6 `() =>`)
- Destructuring with defaults
- Async/await, generators
- Import/export modules

### ❌ Remaining Issues (12 failing tests)

1. **@params in derived constructors** (2 tests)
   - Problem: `constructor(base, @derived)` with `super(base)` doesn't assign `this.derived`
   - Location: `test/cs3/26-advanced-classes.test.coffee`
   - Fix needed: Insert thisAssignments after super() call, not before

2. **Else-if chains** (3 tests)
   - Problem: Chained `else if` loses the else branch
   - Location: Various test files
   - Fix attempted: addElse operation exists but doesn't persist

3. **Nested loops** (2 tests)
   - Problem: Variable name collision in nested iterations
   - Location: Loop-related tests
   - Issue: Inner loop reuses outer loop's variable name

4. **Nested comprehensions** (2 tests)
   - Problem: Complex array/object comprehensions fail
   - Related to nested loop issue

5. **Other edge cases** (3 tests)
   - Multiline implicit calls
   - Nested ternary operators
   - Super with method delegation

## Recent Fixes Applied

The most recent work focused on class features:

```coffee
# FIXED: Static properties now work!
class MyClass
  @staticProp: 42  # Now generates: MyClass.staticProp = 42

# STILL BROKEN: @params with super
class Derived extends Base
  constructor: (base, @derived) ->
    super(base)  # Should assign this.derived = derived after super
```

The fix for static properties involved setting `this=true` on Value nodes with ThisLiteral base in object context Assign nodes. See commit `9cf03f8f` for details.

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

## Next Priority Issues

Based on impact and complexity:

1. **@params with super** - High impact (2 tests), known solution
2. **Else-if chains** - High impact (3 tests), needs investigation
3. **Nested loops** - Medium impact (2 tests), variable scoping issue

## Tips for New Agent

- The CS3 parser IS working correctly - issues are in the ES5 backend
- Always compile and copy backend changes to lib/ directory
- Use CS2 output as the "correct" reference
- The Solar directive system is documented in CS3_SYNTAX.md
- Test progress is tracked in test/cs3/PROGRESS.md
- Don't try to change the parser (syntax.coffee) - focus on backends/es5/index.coffee

## Security Notes

- No credentials or API keys in this repo
- All test files are safe to execute
- Backend compilation is sandboxed

## Project Context

This is part of transforming CoffeeScript into a universal language that can compile to any target. The Solar directive system provides language-agnostic AST representation. This work will eventually lead to **Rip**, a truly universal programming language.

**Repository**: https://github.com/shreeve/coffeescript (cs3 branch)
**Current commit**: 9cf03f8f (as of last update)

