#!/usr/bin/env coffee

# Debug complex @param patterns in classes
CoffeeScript = require './lib/coffeescript'

testCases = [
  {
    name: "Simple @param with super"
    code: """
    class Child extends Parent
      constructor: (@name) ->
        super()
    """
  }
  {
    name: "@param with default value and super"
    code: """
    class Child extends Parent
      constructor: (@name = 'default') ->
        super()
    """
  }
  {
    name: "Multiple @params with super"
    code: """
    class Child extends Parent
      constructor: (@name, @age) ->
        super()
    """
  }
  {
    name: "Mixed params with super"
    code: """
    class Child extends Parent
      constructor: (options, @name) ->
        super(options)
    """
  }
  {
    name: "@param in destructuring with super"
    code: """
    class Child extends Parent
      constructor: ({@name}) ->
        super()
    """
  }
  {
    name: "Complex destructuring with super"
    code: """
    class Child extends Parent
      constructor: ({@name, @age}, options) ->
        super(options)
    """
  }
]

for test in testCases
  console.log "Test: #{test.name}"
  console.log "Code:"
  console.log test.code

  try
    result = CoffeeScript.compile test.code, {bare: true, cs3: true}
    console.log "  ✅ Compiles"
  catch err
    console.log "  ❌ Error: #{err.message}"
  console.log ""
