# CS3/ES5 Backend: Class Property Conversion Problem

## Overview

The CS3/ES5 backend has a fundamental issue with converting class property assignments from CS3 data nodes to CoffeeScript's class-based AST nodes. This single architectural problem is the root cause of multiple failing test categories, affecting approximately 10-13% of the remaining test failures.

## The Problem

### What Should Happen
In regular CoffeeScript, class properties are correctly converted to prototype assignments:

```coffeescript
# Source CoffeeScript
class C
  prop: 'test'          # Instance property
  @staticProp: 'static' # Static property
```

```javascript
// Expected JavaScript output
C = class C {};
C.prototype.prop = 'test';
C.staticProp = 'static';
```

### What Actually Happens in CS3
The CS3/ES5 backend produces invalid JavaScript syntax:

```javascript
// CS3 Backend (BROKEN)
[C.prototype.prop]: 'test';     // SyntaxError: Unexpected token ':'
[C.staticProp]: 'static';       // SyntaxError: Unexpected token ':'
```

## Root Cause Analysis

### Why Current Code Leads to This Problem

**1. CS3 Data Structure vs Class-Based AST Mismatch**
- CS3 represents class properties as data objects with `type: 'Assign'` and `context: 'object'`
- CoffeeScript's class-based AST expects specific node types for prototype vs static assignments
- The backend's `dataToClass` conversion doesn't distinguish between object literal properties and class properties

**2. Incorrect Property Key Conversion**
In `backends/es5/index.coffee`, the `Assign` handler treats all `context: 'object'` assignments the same way:

```coffeescript
# Current problematic code (lines ~450-460)
when 'Assign'
  if node.context is 'object' and node.expression
    # This creates PropertyName nodes for ALL object contexts
    # But class properties need different handling than object literals
    if base?.type is 'PropertyName'
      variable = @dataToClass base
    else if base?.type is 'IdentifierLiteral'
      variable = new nodes.PropertyName(base.value)  # WRONG for class properties
```

**3. Missing Context Awareness**
The backend doesn't distinguish between:
- Object literal properties: `obj = {prop: value}` → `obj.prop = value`
- Class instance properties: `class C; prop: value` → `C.prototype.prop = value`  
- Class static properties: `class C; @prop: value` → `C.prop = value`

## What Happens as a Result

### Direct Failures
1. **Soaked Constructor Test**: `(new C())?.prop` returns `undefined` instead of expected value because `C.prototype.prop` is never set
2. **Sourcemap Compilation**: `@sourceMaps: Object.create(null)` produces `[SourceMap.sourceMaps]: Object.create(null);` causing `SyntaxError: Unexpected token ':'`
3. **Async Static Methods**: Static method definitions fail due to incorrect property syntax

### Cascading Effects
- Tests that depend on class inheritance fail
- Prototype chain lookups fail
- Static method calls fail
- Class-based patterns throughout the codebase break

## Required Changes to Fix

### 1. Context-Aware Property Conversion
The `Assign` node conversion needs to detect when it's inside a class body:

```coffeescript
when 'Assign'
  if node.context is 'object'
    if @inClassBody  # Need to track this context
      # Handle as class property
      if node.variable.type is 'ThisProperty'
        # Static property: @prop -> ClassName.prop
        createStaticPropertyAssignment(node)
      else
        # Instance property: prop -> ClassName.prototype.prop  
        createInstancePropertyAssignment(node)
    else
      # Handle as object literal property
      createObjectPropertyAssignment(node)
```

### 2. Class Body Context Tracking
Add state tracking to know when processing class body vs object literal:

```coffeescript
dataToClass: (node) ->
  switch node.type
    when 'Class'
      @inClassBody = true
      # ... process class body
      @inClassBody = false
```

### 3. Proper Property Assignment Creation
Create the correct AST nodes for different property types:

```coffeescript
createInstancePropertyAssignment: (node) ->
  # Create: ClassName.prototype.propName = value
  className = @currentClassName
  prototypeAccess = new nodes.Value(
    new nodes.IdentifierLiteral(className),
    [new nodes.Access(new nodes.PropertyName('prototype'))]
  )
  propAccess = new nodes.Value(
    prototypeAccess,
    [new nodes.Access(new nodes.PropertyName(node.variable.name))]
  )
  new nodes.Assign(propAccess, @dataToClass(node.value))
```

## Suggested Resolution Approaches

### Option 1: Backend Enhancement (Recommended)
**Pros**: Maintains current architecture, targeted fix
**Cons**: Requires careful state management in backend

**Implementation Steps**:
1. Add class body context tracking to the backend
2. Enhance `Assign` node conversion with context awareness  
3. Create helper methods for different property assignment types
4. Add tests for class property conversion

**Estimated Effort**: Medium (1-2 days)

### Option 2: Grammar-Level Solution
**Pros**: Cleaner separation of concerns
**Cons**: Requires changes to CS3 grammar and parser

**Implementation Steps**:
1. Modify `src/syntax.coffee` to emit different node types for class properties
2. Add `ClassProperty` and `StaticProperty` node types to CS3
3. Update backend to handle these specific node types
4. Regenerate parser with `cake build:parser`

**Estimated Effort**: High (3-5 days)

### Option 3: Post-Processing Fix
**Pros**: Minimal changes to existing code
**Cons**: Hacky approach, doesn't address root cause

**Implementation Steps**:
1. Let current backend generate invalid syntax
2. Add post-processing step to fix `[ClassName.prop]:` → `ClassName.prop =`
3. Use regex/AST manipulation to correct the output

**Estimated Effort**: Low (few hours) but not recommended

### Option 4: AST Preprocessing
**Pros**: Clean separation, processes data before backend conversion
**Cons**: Adds another pipeline stage

**Implementation Steps**:
1. Add preprocessing step before `dataToClass` conversion
2. Transform class property data nodes into proper assignment structures
3. Mark assignments with class context information
4. Backend processes pre-transformed nodes

**Estimated Effort**: Medium (1-2 days)

## Impact Assessment

### Fixing This Issue Would Resolve
- **Soaked constructor invocations with property access** ✅
- **Sourcemap compilation syntax error** ✅  
- **Async class static method access** ✅
- **Class inheritance and prototype chain issues** ✅
- **Estimated test suite improvement**: +8-10% (from ~87% to ~95-97%)

### Remaining Issues After Fix
- **#4889 nested for-loop variable conflicts** (architectural scope issue)
- **String/whitespace edge cases** (minor formatting differences)
- **Import assertion formatting** (minor shape discrepancies)

## Test Cases for Validation

```coffeescript
# Test Case 1: Instance Properties
class C
  prop: 'test'
instance = new C()
assert instance.prop == 'test'
assert C.prototype.prop == 'test'

# Test Case 2: Static Properties  
class C
  @staticProp: 'static'
assert C.staticProp == 'static'

# Test Case 3: Mixed Properties
class C
  instanceProp: 'instance'
  @staticProp: 'static'
assert new C().instanceProp == 'instance'  
assert C.staticProp == 'static'

# Test Case 4: Soaked Constructor (Original Failing Test)
class C
  constructor: ->
    # constructor logic
  prop: {}
assert (new C())?.prop != undefined

# Test Case 5: Sourcemap Case
class SourceMap
  @sourceMaps: Object.create(null)
assert SourceMap.sourceMaps != undefined
```

## Conclusion

The class property conversion problem is a well-defined, solvable issue that would significantly improve CS3/ES5 backend compatibility. **Option 1 (Backend Enhancement)** is recommended as it provides the best balance of effectiveness and maintainability.

Fixing this single architectural issue would resolve multiple test categories and bring the CS3/ES5 backend to **~95-97% compatibility** with the traditional CoffeeScript pipeline, making it production-ready for most use cases.
