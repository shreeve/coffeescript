# Remaining CS3/ES5 Backend Issues (Guidance for Next Agent)

This document captures the failing tests, observed behavior, suspected root causes, pointers to relevant code, and concrete fix approaches. Tackle in order.

## 1) Else-if chain persistence (else lost)
- Tests:
  - `test/cs3/06-conditionals.test.coffee` — "chained conditionals": Expected medium, got large
  - `test/cs3/24-control-flow.test.coffee` — "if-else chains": Expected zero, got large
- Symptom: Else-if chains behave as simple if/else; the else-if branch is not being preserved, skewing results.
- Likely cause:
  - In our backend we sometimes set `elseBody` directly instead of building chains via `nodes.If.addElse`, so `isChain` is not set. This affects ternary compilation and association.
- Relevant code:
  - Backend If construction: `backends/es5/index.coffee` within evaluateDirective for `when 'If', 'if'` and solarNodeToClass for `'if'`/`'unless'`.
  - `lib/coffeescript/nodes.js` `If.addElse`, `If.compileExpression` (uses `isChain`).
- Approach:
  - Ensure that when the else branch is itself an `If`, attach it using `ifNode.addElse(elseIfNode)` (not by assigning `elseBody`).
  - Verify both evaluateDirective path and solarNodeToClass path; both must create chains consistently.
- Gotchas: Mixed sources (evaluateDirective vs. solarNodeToClass) must behave identically; dangling arrays should be wrapped in `Block` before `addElse`.
- Acceptance: Both tests pass; nested ternaries also likely improve.

## 2) Static property emission (@static)
- Test: `test/cs3/26-advanced-classes.test.coffee` — "class with static properties": Expected 42, got undefined
- Symptom: `@staticProp: 42` inside class does not result in `ClassName.staticProp = 42`.
- Likely cause:
  - Static property entries inside class body are not being turned into `ClassProperty` or post-class assignment.
- Relevant code:
  - `lib/coffeescript/nodes.js` `Class.addInitializerExpression`, `validClassProperty`, `ClassProperty`.
  - Backend: `backends/es5/index.coffee` When building `Class`, the body array may contain Assigns that need to become class properties.
- Approach:
  - Preferred: Allow `nodes.Class` to hoist class properties by passing the raw object-style Assign into the body (not mutated to `this.*`). Ensure body nodes are genuine `Assign` forms that `validClassProperty` recognizes (i.e., `Value(ThisLiteral)::Access(PropertyName)` for static? or `Value(PropertyName)` with looksStatic).
  - Alternative: After creating the `Class`, append post-assignments `ClassName.prop = value` for each static property found in body (if hoisting route is complicated).
- Acceptance: The test reads `MyClass.staticProp === 42`.

## 3) @params assignment after super() in derived constructors
- Test: `test/cs3/26-advanced-classes.test.coffee` — "class with super in constructor": Expected d, got undefined
- Symptom: `(@derived)` is not assigned after `super(base)`; sometimes engine error "Must call super constructor ... before accessing 'this'".
- Likely cause:
  - Our shim that fakes `eachSuperCall` returns true without placing `thisAssignments` onto the real `SuperCall`. This can cause pre-super `this` access or duplicate super logic.
- Relevant code:
  - Backend: `backends/es5/index.coffee` around `Code` construction where `eachSuperCall` and validation are monkey-patched.
  - `lib/coffeescript/nodes.js` `Code.expandCtorSuper(thisAssignments)` expects to find a `SuperCall` and attach `expressions = thisAssignments`.
- Approach:
  - Remove the "always found" shim. Normalize `Call(Super, ...)` to a `nodes.SuperCall` before `Code.compile` runs and let `expandCtorSuper` attach `thisAssignments` itself.
  - Ensure no `this` access in params before super by not injecting `thisAssignments` until after `super`.
- Acceptance: Both `.base` and `.derived` assigned correctly; no pre-super error.

## 4) @ in destructured parameters
- Test: `test/cs3/28-advanced-functions.test.coffee` — "functions with @ and destructuring": Expected 1, got undefined
- Symptom: `fn = ({@x, @y}) ->` doesn’t assign to `this.x/this.y`.
- Likely cause:
  - Param normalization not marking inner `Value(ThisLiteral)` in object patterns as `this=true`, so `Param.eachName` doesn’t produce `thisAssignments`.
- Relevant code:
  - `lib/coffeescript/nodes.js` `Param.eachName`, `Param.renameParam` logic for object patterns with @.
  - Backend: `backends/es5/index.coffee` under `when 'Param'` for destructured `Obj` params.
- Approach:
  - Ensure that when building a `nodes.Obj` parameter, inner entries like `Value(ThisLiteral, [Access(PropertyName)])` are left intact (not converted) and that `name.generated = false` is set so CS2 logic handles operator tokens.
  - Avoid over-normalizing; rely on `Param.eachName` to push `Assign(Value(ThisLiteral...), temp)` into `thisAssignments`.
- Acceptance: After `fn.call(obj, {x:1, y:2})`, `obj.x=1` and `obj.y=2`.

## 5) Implicit returns in complex conditionals
- Test: `test/cs3/19-edge-cases.test.coffee` — "implicit returns": Expected negative, got zero
- Symptom: Implicit return of else-if chains mis-selected (wrong branch result).
- Likely cause:
  - Same root as else-if chain persistence; else-if not marked as chain, causing wrong ternary nesting.
- Relevant code: Same as issue #1.
- Approach: Fix else-if chaining via `addElse`; verify `If.compileExpression` builds nested `cond ? a : b` trees correctly.
- Acceptance: `fn(-3) => "negative"`.

## 6) Multiline implicit calls
- Test: `test/cs3/23-function-invocation.test.coffee` — "multiline implicit calls": Expected 6, got NaN
- Symptom: Multi-line implicit argument list drops or misorders args (e.g., `fn 1,\n  2,\n  3`).
- Likely cause:
  - `Arguments` building loses items across lines when using `$ary` plus `$ops array.append/gather`.
- Relevant code:
  - Backend: `evaluateDirective` for `'Arguments'` and `'Call'` in `backends/es5/index.coffee`.
  - Parser directives around arguments likely emit `$seq/$ary/$ops` combos.
- Approach:
  - Ensure that `Arguments` always returns a flat array of nodes with `args.implicit` preserved. For `Call`, don’t coerce to `[]` if null; ensure gather/append combines all chunks.
  - Add defensive flatten for nested arrays of args.
- Acceptance: `fn 1,\n 2,\n 3` returns 6.

## 7) Nested ternary operators (precedence/association)
- Test: `test/cs3/20-advanced-patterns.test.coffee` — "nested ternary operators": Expected B, got F
- Symptom: Nested conditional expression associates incorrectly.
- Likely cause:
  - Same as else-if chain issue; if chains not represented as `isChain` and nested `If` in `else`.
- Relevant code: Same as issue #1.
- Approach: Use `addElse` for else-if; verify expression compilation wraps inner conditional in parens when needed (`LEVEL_COND`).
- Acceptance: grade(85) => B; 65 => F.

## 8) Nested loops variable collision
- Test: `test/cs3/05-loops.test.coffee` — "nested loops": Expected 4, got 2
- Symptom: Inner loop overwrites outer index/iterator; total iterations halved.
- Likely cause:
  - Not allocating unique temporaries for inner loops when building `nodes.For` (ivar/kvar collisions).
- Relevant code:
  - `lib/coffeescript/nodes.js` `For.compileNode` uses `scope.freeVariable('i'/'len')` etc.
  - Backend: `backends/es5/index.coffee` building `nodes.For` source/name/index; may pass same `index`/`name` across nesting.
- Approach:
  - Ensure each nested `For` uses distinct `index`/`name` nodes or leave those undefined so `nodes.For` allocates via `scope.freeVariable` per loop. Do not reuse the outer index literal node for inner loops.
- Acceptance: Result array has 4 elements [3,4,6,8].

## 9) Nested comprehensions / for-own
- Tests:
  - `test/cs3/13-comprehensions.test.coffee` — "nested comprehension": Expected 2, got 1
  - `test/cs3/13-comprehensions.test.coffee` — "comprehension with own": Expected truthy value
- Symptom: Inner comprehension drops iterations; `own` flag not enforced.
- Likely cause:
  - Same loop var collision (#8) and/or `own` not set into `nodes.For` (so no `hasProp` guard is emitted).
- Relevant code:
  - Backend `when 'For'` creation: ensure `sourceObj.own` and `sourceObj.object` are correctly populated; do not strip `ownTag`.
  - `lib/coffeescript/nodes.js` `For.addSource` validates `own` and emits guard.
- Approach:
  - Confirm that Solar directives set `own` and `object` and propagate those through `evaluateDirective`. If missing, add mapping. Fix nested var collision per #8.
- Acceptance: nested comprehension yields 2 items; for-own comprehension passes `.hasOwnProperty` check.

## 10) Super edge cases
- Tests:
  - `test/cs3/30-super-advanced.test.coffee` — "super in arrow functions": Super constructor may only be called once
  - `test/cs3/30-super-advanced.test.coffee` — "super with method delegation": (intermediate value).callParentMethod is not a function
- Symptoms:
  - Arrow-function constructor patterns trigger duplicate/misplaced super or pre-super this.
  - Delegated super calls produce call target as an intermediate rvalue.
- Likely causes:
  - The backend shim for `eachSuperCall`/validation masks real structure; `thisAssignments` not attached to actual `SuperCall`.
  - `super.method` lowering produces `(intermediate value).method()` instead of a stable bound reference.
- Relevant code:
  - Backend `Code` creation (monkey patches around lines ~760-795 in `backends/es5/index.coffee`).
  - `lib/coffeescript/nodes.js` `Super`, `SuperCall`, `Code.expandCtorSuper`.
- Approach:
  - Remove the overly broad shim; during AST conversion, convert any `Call(Super, args)` to a `nodes.SuperCall` so `expandCtorSuper` can attach `thisAssignments` to `SuperCall.expressions`.
  - For delegated super calls (e.g., `super.method(args)`), ensure the base is compiled to stable reference (as CS2 does) — verify `Super.compileNode` with accessor handling; if backend emits a temporary `Value` incorrectly, adjust.
- Acceptance: Both super-advanced tests pass; no duplicate super and delegation works.

---

General debugging tips:
- Compare with CS2 output for the same inputs (use `test/cs3/cs2-runner.coffee`).
- Add temporary logs in the backend around If/For/Code/Call construction to verify the structures being fed into `lib/coffeescript/nodes.js`.
- After backend edits: `coffee -c backends/es5/index.coffee && cp backends/es5/index.js lib/backends/es5/index.js && test/cs3/cs3-runner.coffee`.
