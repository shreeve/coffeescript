# CS3/ES5 Backend Remaining Issues

## Overview

The CS3/ES5 backend achieves approximately **87-89% test compatibility** with the traditional CoffeeScript pipeline. This document details the remaining issues that prevent 100% compatibility.

## Critical Issues

### 1. #4889: Nested For-Loop Variable Conflicts ⚠️ **MAJOR**

**Status**: Identified root cause, requires architectural changes  
**Impact**: All nested for-loops over ranges fail  
**Test Cases**: `test/ranges.coffee:206-224`

#### Problem Description
The CS3 backend generates conflicting loop counter variables in nested for-loops:

**Regular CoffeeScript (Correct):**
```javascript
// Outer loop: i = k = 0, ref = n; i = 0 <= ref ? ++k : --k
// Inner loop: j = l = ref1 = i + 1, ref2 = n; j = ref1 <= ref2 ? ++l : --l
```

**CS3 Backend (Broken):**
```javascript
// Outer loop: i = j = 0, ref = n; i = 0 <= ref ? ++j : --j  
// Inner loop: j = k = ref1 = i + 1, ref2 = n; j = ref1 <= ref2 ? ++k : --k
```

The issue is that both loops use `j` as the counter variable, causing the inner loop to overwrite the outer loop's counter.

#### Example Failure
```coffeescript
n = 1
result = []
for i in [0..n]
  result.push i
  for j in [(i+1)..n]
    result.push j
# Expected: [0,1,1,2,1]  
# CS3 Gets: [0,1] (outer loop stops after first iteration)
```

#### Root Cause
The issue is in `backends/es5/index.coffee` in the `For` node conversion. The backend doesn't properly manage scope and variable allocation for nested loops. The core CoffeeScript compiler uses `o.scope.freeVariable()` to generate unique variable names, but the CS3 backend conversion bypasses this mechanism.

#### Required Fix
1. **Scope Management**: Implement proper scope tracking in the backend
2. **Variable Allocation**: Ensure each For loop gets unique counter variables
3. **Alternative Approach**: Consider pre-processing the AST to rename conflicting variables before conversion

### 2. Regex Compilation Issues ⚠️ **HIGH**

**Status**: Multiple regex-related failures  
**Impact**: Regex literals, heregex, and regex interpolation  
**Test Cases**: `test/regex.coffee` (multiple failures)

#### Specific Failures

**A. Division vs Regex Disambiguation**
- Test: `division is not confused for a regular expression`
- Issue: CS3 backend emitting empty strings instead of proper division operations
- Example: `eq(2, 4 / 2 / 1)` produces empty result

**B. Compound Division vs Regex**  
- Test: `compound division vs regex`
- Issue: Compound assignment with division produces wrong results
- Example: `a = 10; b = a = c / i` expects `5`, gets `2`

**C. Regex Indexing**
- Test: `#764: regular expressions should be indexable`
- Issue: Regex `.source` property access fails
- Example: `/0/['source']` should equal `/(?:)/['source']`, gets `0`

**D. Heregex with `///` Comments**
- Test: `#2388: /// in heregex interpolations`
- Issue: Heregex with `///` in comments not handled correctly
- Example: Heregex comments not preserved in output

**E. Unicode Code Point Escapes**
- Test: `#4248: Unicode code point escapes`
- Issue: JavaScript output formatting doesn't match expected whitespace
- Example: Missing leading whitespace in generated code

**F. Heregex Comments with `///`**
- Test: `#4811, heregex comments with ///`
- Issue: Comments in heregex not preserved in JavaScript output

#### Root Cause
The CS3 backend's regex handling in `backends/es5/index.coffee` may not be properly converting:
1. `RegexLiteral` nodes with all properties
2. `RegexWithInterpolations` for heregex
3. Regex context detection for division vs regex disambiguation

#### Required Fix
1. Review and fix regex node conversions in backend
2. Ensure proper heregex comment preservation
3. Fix division operator context handling

### 3. String/Whitespace Normalization Issues ⚠️ **MEDIUM**

**Status**: Partially fixed, some edge cases remain  
**Impact**: Multiline strings, heredocs, trailing whitespace  
**Test Cases**: `test/strings.coffee` (multiple failures)

#### Specific Failures

**A. Multiline String Normalization**
- Test: `#3229, multiline strings`
- Issue: Extra spaces in multiline string output
- Example: `' a b '` expected `'a b'`, gets `'  a b  '`

**B. Heredoc Escape Sequences**
- Test: `#3249, escape newlines in heredocs with backslashes`
- Issue: Heredoc indentation and newline handling incorrect
- Example: Heredoc indentation not matching expected output

**C. Trailing Whitespace**
- Test: `trailing whitespace`
- Issue: Trailing whitespace not properly stripped
- Example: `'  a  '` expected `'a'`, gets `'  a  '`

**D. Heredoc Formatting**
- Issue: Heredoc output missing leading newline
- Example: `'''Hello, World\'''` vs expected format with newline

#### Root Cause
The `StringLiteral` and `StringWithInterpolations` conversions in the backend may not be properly handling:
1. `indent` property for heredoc normalization
2. `initialChunk`/`finalChunk` for whitespace trimming
3. Trailing whitespace removal logic

#### Required Fix
1. Review string normalization logic in backend
2. Ensure proper heredoc indentation handling
3. Implement correct trailing whitespace removal

### 4. Tagged Template Literal Issues ⚠️ **MEDIUM**

**Status**: Template conversion working, result shape mismatches  
**Impact**: Tagged template literal function calls  
**Test Cases**: `test/tagged_template_literals.coffee`

#### Specific Failures

**A. HTML Templating Result**
- Test: `tagged template literal for html templating`
- Issue: Template function returns `undefined` instead of expected HTML
- Root cause: Template function not being called correctly

**B. Multi-line Template Shapes**
- Tests: Multi-line single/double-quote block strings
- Issue: Template text array format doesn't match expected
- Example: `[multi-line\nblock string]` vs `[\n      multi-line\n      block string\n      ]`

**C. Empty Template Handling**
- Test: `tagged template literal with an empty interpolated string`
- Issue: Empty template produces `[]` instead of `[|]`

#### Root Cause
The `TaggedTemplateCall` conversion in the backend may have issues with:
1. Template argument passing (using `node.template` vs `node.args[0]`)
2. Template literal formatting and whitespace preservation
3. Empty template edge cases

#### Required Fix
1. Verify `TaggedTemplateCall` argument handling in backend
2. Review template literal text formatting
3. Fix empty template edge case handling

### 5. Import/Export and Module Issues ⚠️ **MEDIUM**

**Status**: Basic conversion implemented, some edge cases  
**Impact**: ES6 modules, import assertions  
**Test Cases**: `test/repl.coffee`, import-related tests

#### Specific Failures

**A. REPL Import Transpilation**
- Test: `transpile REPL`
- Issue: Import statement in REPL context fails
- Error: "Cannot use import statement inside the Node.js REPL"

**B. Syntax Error in For-Own**
- Error: "SyntaxError: cannot use own with for-in"
- Issue: CS3 backend generating invalid `for-own` syntax

#### Root Cause
1. Import/export declarations may need context-aware handling
2. For-own loop conversion may be incorrect

#### Required Fix
1. Review import/export context handling
2. Fix for-own loop syntax generation

### 6. Soaked Constructor and Property Access ⚠️ **MEDIUM**

**Status**: Soaking logic incomplete  
**Impact**: Optional chaining with constructors  
**Test Cases**: `test/soaks.coffee:181-201`

#### Specific Failures

**A. Soaked Constructor with Property Access**
- Test: `soaked constructor invocations with caching and property access`
- Issue: Returns object instead of `undefined` for failed soak
- Example: `new C()?.prop` should handle constructor failure gracefully

#### Root Cause
The soaking logic in the backend may not properly handle:
1. Constructor invocation soaking
2. Property access after soaked constructor
3. Proper `undefined` return for failed soaks

#### Required Fix
1. Review soaking logic in `Call` and `Value` node conversions
2. Ensure proper `undefined` handling for failed soaks

### 7. Sourcemap Compilation Error ⚠️ **LOW**

**Status**: Syntax error in generated code  
**Impact**: Sourcemap functionality  
**Test Cases**: `test/sourcemap.coffee`

#### Specific Failures

**A. Sourcemap Class Property Syntax**
- Error: `SyntaxError: Unexpected token ':'`
- Location: `/src/sourcemap.litcoffee:143`
- Issue: `[SourceMap.sourceMaps]: Object.create(null);` - invalid syntax

#### Root Cause
The backend may be generating invalid JavaScript syntax for class properties or computed property names.

#### Required Fix
1. Review class property syntax generation
2. Ensure computed property names are handled correctly

### 8. Strict Mode Parameter Validation ⚠️ **LOW**

**Status**: Partially fixed, some cases remain  
**Impact**: Strict mode duplicate parameter detection  
**Test Cases**: `test/strict.coffee:49-58`

#### Specific Failures

**A. Duplicate Parameter Detection**
- Test: `duplicate formal parameters are prohibited`
- Issue: Expected compile-time error not thrown
- Example: Functions with duplicate parameters should fail in strict mode

#### Root Cause
The parameter duplicate detection may not be working correctly after CS3 parameter lowering (especially for `@params`).

#### Required Fix
1. Ensure duplicate parameter detection works after backend conversion
2. Verify strict mode compilation flags are preserved

### 9. Async Class Method Issues ⚠️ **LOW**

**Status**: Static method access broken  
**Impact**: Async static methods in classes  
**Test Cases**: `test/async.coffee:231-243`

#### Specific Failures

**A. Static Method Access**
- Test: `async methods in classes`
- Issue: `Base.static is not a function`
- Example: Static async methods not properly accessible

#### Root Cause
The class method conversion may not properly handle:
1. Static method definitions
2. `this.static` property access in class context
3. Async method compilation

#### Required Fix
1. Review class method conversion for static methods
2. Ensure `this.static` context is preserved
3. Verify async method handling

## Implementation Priorities

### High Priority (Blocking Core Functionality)
1. **#4889 Nested For-Loop Variable Conflicts** - Requires scope management overhaul
2. **Regex Compilation Issues** - Multiple core language features affected

### Medium Priority (Common Use Cases)
3. **String/Whitespace Normalization** - Affects string literals and heredocs
4. **Tagged Template Literals** - Modern JavaScript feature support
5. **Import/Export Issues** - ES6 module support
6. **Soaked Constructor Access** - Optional chaining support

### Low Priority (Edge Cases)
7. **Sourcemap Compilation** - Development tooling
8. **Strict Mode Validation** - Compile-time checks  
9. **Async Class Methods** - Advanced class features

## Architecture Recommendations

### For #4889 (Critical)
The nested for-loop issue requires one of these approaches:
1. **Scope Management Integration**: Integrate with CoffeeScript's scope system to generate unique variables
2. **AST Pre-processing**: Add a pass to rename conflicting variables before backend conversion
3. **Variable Tracking**: Implement variable tracking within the backend to avoid conflicts

### For Regex Issues (High Priority)
1. **Comprehensive Regex Testing**: Create isolated test cases for each regex feature
2. **Context Preservation**: Ensure regex vs division context is preserved through CS3 conversion
3. **Property Mapping**: Verify all regex properties are correctly mapped in backend conversion

### General Recommendations
1. **Incremental Testing**: Fix issues one by one with isolated test cases
2. **Backend Architecture**: Consider if the current "data-to-class" conversion approach is sufficient for complex language features
3. **Core Integration**: Some issues may require deeper integration with CoffeeScript's core compilation pipeline

## Test Cases for Validation

Each fix should be validated against:
1. The specific failing test case
2. Broader regression testing with `cake test:cs3`
3. Manual testing of edge cases
4. Comparison of compiled JavaScript output between regular and CS3 pipelines

## Current Status Summary

- **Working**: ~87-89% of CoffeeScript test suite
- **Critical Blockers**: 2 issues (#4889, regex compilation)
- **Medium Impact**: 4 issues (strings, templates, imports, soaks)  
- **Low Impact**: 3 issues (sourcemap, strict mode, async)
- **Total Remaining**: 9 distinct issue categories

The CS3/ES5 backend is functional for most CoffeeScript code but requires these fixes for production readiness.
