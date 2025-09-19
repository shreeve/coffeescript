# Minimal Patch to Add CS3 to Commit 817c39a

## Summary

To add CS3 functionality to CoffeeScript commit 817c39a ("Update flatten helper without recursion"), you need:

### 1. Core Files to Add (4 files, ~495KB total)

```bash
# Essential new files
src/syntax.coffee           # 44KB - CS3 grammar in Solar directive format
solar.coffee                # 37KB - Solar parser generator
backends/es5/index.coffee   # 63KB - ES5 backend evaluator
lib/coffeescript/parser-cs3.js  # 351KB - Generated CS3 parser (or generate it)
```

### 2. Minimal File Modifications

#### Cakefile
Add these tasks:
```coffee
# Build the CS3 parser from syntax.coffee using Solar
buildParserCS3 = ->
  helpers.extend global, require 'util'
  syntax = require('./src/syntax')
  language =
    grammar: syntax.grammar    # CS3 uses 'grammar' instead of 'bnf'
    operators: syntax.operators
  {Generator} = require './solar.coffee'
  parser = Generator(language).generate(compress: !true)
  fs.writeFileSync 'lib/coffeescript/parser-cs3.js', parser

# Add the task
task 'build:parser-cs3', 'build the CS3 parser from syntax.coffee using Solar', buildParserCS3

# Add test task
task 'test:cs3', 'run CS3/ES5 test suite', ->
  try execSync 'cd test/cs3 && coffee cs3-runner.coffee', stdio: 'inherit'
  catch e then process.exit 1
```

#### src/command.coffee (optional for CLI)
Add CS3 support at the top:
```coffee
# CS3 plumbing (lexer/parser/backends) for new CLI switches
{Lexer}        = require './lexer'
try parserCS3  = require './parser-cs3' catch err then parserCS3 = null
try ES5Backend = require '../backends/es5/index' catch err then ES5Backend = null
```

### 3. Test Infrastructure (optional but recommended)

```bash
# Test runner and sample tests
test/cs3/cs3-runner.coffee  # Main test runner
test/cs3/*.test.coffee      # Test files (32 files, can start with a few)
```

## Step-by-Step Installation

```bash
# 1. Checkout commit 817c39a
git checkout 817c39a

# 2. Copy the 4 essential files from CS3 branch
git checkout cs3 -- src/syntax.coffee
git checkout cs3 -- solar.coffee
git checkout cs3 -- backends/es5/index.coffee
git checkout cs3 -- backends/es5/index.js  # Compiled version

# 3. Apply minimal Cakefile changes
# Edit Cakefile to add buildParserCS3 function and tasks

# 4. Build the CS3 parser
cake build:parser-cs3

# 5. Copy the test runner (optional)
git checkout cs3 -- test/cs3/cs3-runner.coffee
git checkout cs3 -- test/cs3/01-literals.test.coffee  # Sample test

# 6. Test it
cd test/cs3 && coffee cs3-runner.coffee
```

## Alternative: Minimal Standalone Test

If you just want to test CS3 without modifying the build system:

```coffee
# test-cs3.coffee
{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './backends/es5'

code = '''
x = 42
console.log x
'''

lexer = new Lexer()
tokens = lexer.tokenize code
backend = new ES5Backend()
parserCS3.yy = {backend}
ast = parserCS3.parse tokens

console.log ast.compileToFragments().map((f) -> f.code).join('')
```

## File Sizes

- **Minimal core**: ~144KB (3 source files)
- **With generated parser**: ~495KB (4 files)
- **With test suite**: ~600KB (including test runner and a few tests)

## Notes

1. The CS3 parser can be generated on-demand using `cake build:parser-cs3` instead of committing the 351KB parser-cs3.js file
2. The backends/es5/index.js is the compiled version of index.coffee (needed if not compiling locally)
3. No changes needed to src/nodes.coffee for basic CS3 functionality - the minor changes in the current branch are optimizations
4. No npm dependencies need to be added - Solar is self-contained

## What You Get

- Complete CS3 parser using Solar directives
- ES5 backend that converts Solar directives to CoffeeScript AST nodes
- Ability to compile CoffeeScript through the new data-oriented architecture
- Foundation for multiple backend targets (Python, WASM, etc.)
