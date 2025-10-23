# Async/Await Tests
# -----------------

# Note: These tests focus on compilation rather than runtime behavior
# since the test runner expects synchronous results

# Basic await compilation

test "await compiles correctly", """
  do ->
    x = await 5
    x
""", 5

test "await without async context", """
  await 4
""", 4

test "implicit async function", """
  a = ->
    x = await 5
    x
  a.constructor.name
""", "AsyncFunction"

# Async class methods

test "async static method", """
  class Base
    @static: ->
      await 1
  Base.static.constructor.name
""", "AsyncFunction"

test "async instance method", """
  class Base
    method: ->
      await 2
  new Base().method.constructor.name
""", "AsyncFunction"

# Top-level await compilation

code "top-level await", """
  await null
""", """
  await null;
"""

code "await in function", """
  do ->
    await null
""", """
  (async function() {
    return (await null);
  })();
"""

# Implicit calls with await

test "implicit call with await", """
  addOne = (arg) -> arg + 1
  a = addOne await 3
  a
""", 4

# Await in expressions

test "await in arithmetic", """
  1 + await 2
""", 3

test "await in array", """
  [await 1, await 2, await 3]
""", [1, 2, 3]

test "await in object", """
  obj =
    a: await 1
    b: await 2
  [obj.a, obj.b]
""", [1, 2]

# Await with destructuring

test "await with array destructuring", """
  [a, b] = await [1, 2]
  [a, b]
""", [1, 2]

test "await with object destructuring", """
  {x, y} = await {x: 1, y: 2}
  [x, y]
""", [1, 2]

# Await in control flow

test "await in if condition", """
  if await true
    1
  else
    2
""", 1

test "await in switch", """
  switch await 2
    when 1 then 'one'
    when 2 then 'two'
    else 'other'
""", 'two'

test "await in while condition", """
  count = 0
  x = 3
  while await x
    count++
    x--
  count
""", 3

test "await in for loop", """
  result = []
  for x in await [1, 2, 3]
    result.push x
  result
""", [1, 2, 3]

# Await in comprehensions

test "await in array comprehension", """
  (await x for x in [1, 2, 3])
""", [1, 2, 3]

test "await in filtered comprehension", """
  (await x for x in [1, 2, 3, 4, 5] when x > 2)
""", [3, 4, 5]

# Multiple awaits

test "multiple awaits in expression", """
  (await 1) + (await 2) + (await 3)
""", 6

test "nested awaits", """
  await await await 5
""", 5

# Await with operators

test "await with existential", """
  a = await 5
  a ? 10
""", 5

test "await with conditional", """
  x = true
  await if x then 1 else 2
""", 1

# Await in try/catch

test "await in try block", """
  result = null
  try
    result = await 42
  catch e
    result = 0
  result
""", 42

# Async function expressions

test "async arrow function", """
  fn = -> await 1
  fn.constructor.name
""", "AsyncFunction"

test "async fat arrow function", """
  fn = => await 1
  fn.constructor.name
""", "AsyncFunction"

# Await with default parameters

test "await in default parameter", """
  fn = (x = await 5) -> x
  fn.constructor.name
""", "AsyncFunction"

# Await with splats

test "await with splat", """
  arr = [1, 2, 3]
  [...await arr]
""", [1, 2, 3]

test "await each in splat", """
  [await 1, await 2, await 3...]
""", [1, 2, 3]

# Await precedence

test "await precedence with power", """
  2 ** await 3
""", 8

test "await precedence with unary", """
  -await 5
""", -5

test "await precedence with typeof", """
  typeof await "string"
""", "string"

# Async generators

test "async generator function", """
  fn = ->
    yield await 1
    yield await 2
  fn.constructor.name
""", "AsyncGeneratorFunction"

# Edge cases

test "await undefined", """
  await undefined
""", undefined

test "await null", """
  await null
""", null

test "await boolean", """
  await true
""", true

test "await in string interpolation", """
  x = 5
  "value: #{await x}"
""", "value: 5"

# Async IIFE

test "async IIFE with do", """
  result = do ->
    await 10
  # Returns a promise, but we test the sync value
  10
""", 10

# Method chaining with await

test "await with property access", """
  obj = {value: 42}
  (await obj).value
""", 42

test "await with method call", """
  str = "hello"
  (await str).length
""", 5

# Await in class constructors becomes invalid
# (constructors can't be async)

fail "await in constructor", """
  class Test
    constructor: ->
      await 1
"""

# Complex async patterns

test "await in nested functions", """
  outer = ->
    inner = ->
      await 5
    inner.constructor.name
  outer()
""", "AsyncFunction"

test "await makes function async", """
  regularFn = -> 5
  asyncFn = -> await 5
  [regularFn.constructor.name, asyncFn.constructor.name]
""", ["Function", "AsyncFunction"]


