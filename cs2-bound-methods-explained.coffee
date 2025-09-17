#!/usr/bin/env coffee

console.log """
============================================================
How CS2 Handles Bound Methods (Fat Arrow =>) in Classes
============================================================

CS2's approach happens in src/nodes.coffee Class compilation:

1. During walkBody():
   - Collects all methods with bound:true into @boundMethods array

2. In proxyBoundMethods():
   - For each bound method, creates an assignment:
     this.method = this.method.bind(this)
   - Stores these in @ctor.thisAssignments

3. In Code (constructor) compilation:
   - Adds thisAssignments to the constructor body:
     @body.expressions.unshift thisAssignments...

Example transformation:
"""

CoffeeScript = require './lib/coffeescript'

code = """
class Button
  constructor: (@label) ->

  # This fat arrow method should be bound
  click: =>
    console.log @label
"""

console.log "Input CoffeeScript:"
console.log code

js = CoffeeScript.compile(code, {bare: true})
console.log "\nCS2 Generated JavaScript:"
console.log js

console.log """
============================================================
The Challenge for CS3:
============================================================

The bound method handling happens in CS2's Class node compilation,
not during AST creation. The backend creates the AST, but the
Class node's compileNode method is what:

1. Detects bound methods
2. Modifies the constructor
3. Adds the bind() calls

To fix this in CS3, we would need to either:

Option 1: Modify CS2's Class compilation logic
- Complex because it expects specific AST structure
- Would need to understand CS3's AST differences

Option 2: Handle in the ES5 backend
- Detect bound methods when creating the Class node
- Find or create the constructor
- Add bind assignments to the constructor body
- This is doable but requires significant backend changes

Option 3: Post-process the AST
- After creating the Class node, walk it to find bound methods
- Modify the constructor node to add bind calls
- This might be the cleanest approach
"""
