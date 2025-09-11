# CS3/ES5 Backend - Remaining Known Bugs

## Summary
The CS3/ES5 backend is mostly functional but has 3 critical bugs that prevent the test suite from passing.

## Critical Bugs (Must Fix)

### 1. ❌ Variable Name Conflict in Nested Loops
**Status:** CONFIRMED  
**Impact:** Causes infinite loops in test #1643 and incorrect behavior in nested loops  
**Description:** When compiling nested loops with destructuring, CS3 incorrectly uses the same variable name for both the outer loop counter and the inner loop's destructured variable.

**Example:**
```coffeescript
for x in ['a', 'b']      # Outer loop
  for i,j in [1,2]       # Inner loop with destructuring
    console.log x, i, j
```

**Current Output (CS3):**
```javascript
for (i = 0, len = ref.length; i < len; i++) {        // ❌ Uses 'i' as outer loop counter
  x = ref[i];
  for (j = k = 0, len1 = ref1.length; k < len1; j = ++k) {
    i = ref1[j];    // ❌ Overwrites outer loop counter!
```

**Expected Output (Regular CoffeeScript):**
```javascript
for (k = 0, len = ref.length; k < len; k++) {        // ✅ Uses 'k' as outer loop counter
  x = ref[k];
  for (j = l = 0, len1 = ref1.length; l < len1; j = ++l) {
    i = ref1[j];    // ✅ 'i' is only the destructured value
```

**Result:** Only processes 2 iterations instead of 4 (or causes infinite loop in complex cases)

---

### 2. ❌ Super Calls in Classes
**Status:** CONFIRMED  
**Impact:** Super calls in class methods throw empty error  
**Description:** When using `super` in class methods, CS3 compilation throws an error with no message.

**Example:**
```coffeescript
class A
  method: -> "A"
class B extends A  
  method: -> super + "B"
```

**Expected:** Should return "AB"  
**Actual:** Throws error with empty message

---

### 3. ⚠️ Array Elisions (Partial Issue)
**Status:** PARTIALLY WORKING  
**Impact:** Array elisions compile but produce incorrect output  
**Description:** Array elisions (holes in arrays) compile without error but produce incorrect JavaScript.

**Example:**
```coffeescript
[1,,3]  # Array with hole at index 1
```

**Expected Output:**
```javascript
[1, void 0, 3]  // or [1, , 3] with proper handling
```

**Actual Output:**
```javascript
[1]  // ❌ Hole is completely omitted
```

---

## Test Results

When running `COFFEESCRIPT_CS3=true npm test`:
- **Loop variable conflict** causes test #1643 in `test/assignment.coffee` to hang indefinitely
- **Super calls** cause class-related tests to fail with empty errors
- **Array elisions** cause incorrect array behavior but don't crash

## Priority

1. **HIGH:** Fix loop variable conflict (blocks test suite)
2. **HIGH:** Fix super calls (breaks class functionality)
3. **MEDIUM:** Fix array elisions (incorrect behavior but doesn't crash)

## Notes

Other features that were tested and work correctly:
- ✅ For-from loops
- ✅ Basic splatted destructuring assignments
- ✅ Property splatted destructuring (`[o.a...]`)
- ✅ Complex destructuring patterns (`@o.a`, `f().a`, `o?.a`)
- ✅ String interpolation
- ✅ Module loading (command.js exists and loads)

## Files to Modify

To fix these bugs, changes are likely needed in:
1. `backends/es5/index.coffee` - ES5 backend node conversion
2. `src/nodes.coffee` - Core node compilation logic (for loop variable allocation)
3. `src/scope.litcoffee` - Scope management for variable name allocation
