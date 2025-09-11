# CS3/ES5 Test Suite Integration Analysis

## Current Test Suite Architecture

The CoffeeScript test suite runs via `npm test` which executes `node ./bin/cake test`. Here's how it currently works:

1. **Test Runner**: `Cakefile` defines the `test` task that calls `runTests(CoffeeScript)`
2. **CoffeeScript Loading**: Tests import from `./lib/coffeescript`
3. **Compilation**: Tests use `CoffeeScript.compile(code, options)`
4. **Test Files**: Located in `test/` directory, written in CoffeeScript
5. **Execution**: Tests are compiled and executed using the standard CoffeeScript compiler

## Key Requirements for CS3/ES5 Testing

### 1. Parser Management
Currently, only one parser can exist at `lib/coffeescript/parser.js`:
- **Old Parser**: Generated from `src/grammar.coffee` - works with existing CoffeeScript
- **CS3 Parser**: Generated from `src/syntax.coffee` - outputs CS3 data nodes

**Solution**: Need to maintain both parsers and switch between them.

### 2. Compiler Integration
The CS3 compiler (`lib/coffeescript/cs3-compiler.js`) needs to be integrated into the CoffeeScript API:
- Current: `CoffeeScript.compile()` uses old parser + class-based AST
- Needed: `CoffeeScript.compile()` can use CS3 parser + ES5 backend

### 3. API Compatibility
Tests expect standard CoffeeScript API:
```javascript
CoffeeScript.compile(code, options)
CoffeeScript.run(code, options)
CoffeeScript.eval(code, options)
```

## Implementation Strategy

### Option 1: Dual Parser Files (Recommended)
```
lib/coffeescript/
  parser.js         # Old parser (default)
  parser-cs3.js     # CS3 parser
  cs3-compiler.js   # CS3 integration
```

**Implementation**:
1. Generate both parsers to different files
2. Modify `cs3-compiler.js` to load `parser-cs3.js`
3. Add CS3 mode to CoffeeScript API

### Option 2: Runtime Parser Switching
```javascript
// In lib/coffeescript/coffeescript.js
CoffeeScript.compile = function(code, options) {
  if (options.cs3) {
    return require('./cs3-compiler').compileCS3(code, options);
  }
  // ... existing compile logic
}
```

### Option 3: Separate Test Command
```json
// In package.json
"scripts": {
  "test": "node ./bin/cake test",
  "test:cs3": "node ./bin/cake test:cs3"
}
```

## Required Changes

### 1. Generate Both Parsers
```bash
# Generate old parser
coffee solar.coffee src/grammar.coffee -o lib/coffeescript/parser.js

# Generate CS3 parser
coffee solar.coffee src/syntax.coffee -o lib/coffeescript/parser-cs3.js
```

### 2. Update CS3 Compiler
```javascript
// lib/coffeescript/cs3-compiler.js
parser = require('./parser-cs3');  // Use CS3 parser
```

### 3. Integrate into CoffeeScript API
```javascript
// lib/coffeescript/coffeescript.js
exports.compile = function(code, options) {
  if (options?.cs3 || process.env.COFFEESCRIPT_CS3) {
    return require('./cs3-compiler').compileCS3(code, options);
  }
  // ... existing logic
};
```

### 4. Create CS3 Test Task
```coffee
# Cakefile
task 'test:cs3', 'run tests using CS3/ES5 backend', ->
  process.env.COFFEESCRIPT_CS3 = 'true'
  runTests(CoffeeScript).catch -> process.exit 1
```

## Expected Challenges

1. **Location Data**: CS3 AST may not have same location data format
2. **Error Messages**: Error reporting might differ
3. **Feature Parity**: Some edge cases might not be implemented
4. **Performance**: CS3 → ES5 conversion adds overhead

## Test Coverage Analysis

The test suite covers:
- **Core Language**: Variables, functions, classes, etc. (✅ ES5 backend supports)
- **Advanced Features**: Generators, async/await, destructuring (⚠️ May need work)
- **Edge Cases**: Complex expressions, precedence (✅ Should work)
- **Error Handling**: Syntax errors, runtime errors (⚠️ May differ)

## Recommended Approach

1. **Phase 1**: Set up dual parser system
2. **Phase 2**: Integrate CS3 compiler with options flag
3. **Phase 3**: Run simple tests to verify basic functionality
4. **Phase 4**: Fix failing tests incrementally
5. **Phase 5**: Achieve full test suite compatibility

## Commands to Run Tests

Once implemented:
```bash
# Run with old parser (default)
npm test

# Run with CS3/ES5 backend
COFFEESCRIPT_CS3=true npm test
# or
npm run test:cs3
```

## Success Metrics

- [ ] All 1369 tests pass with CS3/ES5 backend
- [ ] Performance within 2x of original compiler
- [ ] Error messages are clear and helpful
- [ ] No regressions in functionality
