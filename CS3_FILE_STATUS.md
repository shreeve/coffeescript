# CS3 File Status - Coffee Sources vs JavaScript

## File Relationships

### 1. ✅ **backends/es5/index.coffee** → **backends/es5/index.js**
- **Source**: `backends/es5/index.coffee` (22KB)
- **Compiled**: `backends/es5/index.js` (27KB)
- **Status**: ✅ In sync - coffee source compiles to match the JS file
- **Purpose**: ES5 backend that converts CS3 AST to legacy CoffeeScript AST

### 2. ✅ **src/cs3-compiler.coffee** → **lib/coffeescript/cs3-compiler.js**
- **Source**: `src/cs3-compiler.coffee` (NEW - just created)
- **Compiled**: `lib/coffeescript/cs3-compiler.js` (just recompiled)
- **Status**: ✅ In sync - coffee source now exists and compiles to JS
- **Purpose**: Integration layer connecting CS3 parser with ES5 backend

### 3. ⚙️ **src/syntax.coffee** → **lib/coffeescript/parser-cs3.js** (via solar.coffee)
- **Source**: `src/syntax.coffee` (CS3 grammar definition)
- **Generator**: `solar.coffee` (parser generator)
- **Generated**: `lib/coffeescript/parser-cs3.js` (285KB)
- **Status**: ⚙️ Generated file - not directly compiled from coffee
- **Purpose**: CS3 parser generated from grammar definition
- **Build Command**: `coffee solar.coffee src/syntax.coffee lib/coffeescript/parser-cs3.js`

## Primary Source Files

All CS3 functionality should now be modified via these CoffeeScript source files:

1. **`backends/es5/index.coffee`** - ES5 backend implementation
2. **`src/cs3-compiler.coffee`** - CS3 compiler integration
3. **`src/syntax.coffee`** - CS3 grammar definition
4. **`solar.coffee`** - Parser generator (tool, not compiled)

## Build Process

```bash
# Compile ES5 backend
coffee -c backends/es5/index.coffee

# Compile CS3 compiler integration
coffee -c src/cs3-compiler.coffee
mv src/cs3-compiler.js lib/coffeescript/cs3-compiler.js

# Generate CS3 parser from grammar
coffee solar.coffee src/syntax.coffee lib/coffeescript/parser-cs3.js
```

## Integration Status

⚠️ **Not Yet Integrated**: To actually use CS3, need to modify `src/coffeescript.coffee` to check for CS3 mode and call the CS3 compiler:

```coffeescript
# In src/coffeescript.coffee, compile function:
if (options.cs3 or process.env.COFFEESCRIPT_CS3) and not options.ast
  return require('./cs3-compiler').compileCS3 code, options
```

Then compile: `coffee -c src/coffeescript.coffee`

---

*All CS3 source files are now in CoffeeScript as requested.*
