#!/usr/bin/env coffee

# Debug specific issues with the backend

CoffeeScript = require './lib/coffeescript'
process.env.COFFEESCRIPT_CS3 = 'true'

console.log "Debugging Backend Issues"
console.log "=" * 60

# Issue 1: Loop variables
console.log "\n1. Loop variable compilation:"
code = '''
for x in ['a', 'b']
  for i,j in [1,2]
    null
'''
js = CoffeeScript.compile(code, bare: true)
console.log js
# Look for the variable used in outer loop
outerLoop = js.match(/for \((\w+) = 0/)?[1]
innerLoop = js.match(/for \(j = (\w+) = 0/)?[1]
innerDestructure = js.match(/(\w+) = ref1\[j\]/)?[1]
console.log "Outer loop counter: #{outerLoop}"
console.log "Inner loop counter: #{innerLoop}"
console.log "Inner destructured var: #{innerDestructure}"
if outerLoop == innerDestructure
  console.log "❌ CONFLICT: Outer loop counter '#{outerLoop}' conflicts with destructured '#{innerDestructure}'"

# Issue 2: Super calls debug
console.log "\n2. Super call compilation:"
code = '''
class B extends A
  method: -> super
'''
try
  js = CoffeeScript.compile(code, bare: true)
  console.log "Compiled successfully:"
  console.log js.split('\n').slice(0, 10).join('\n')
catch e
  console.log "Compilation error:", e.message or "(empty)"
  console.log "Stack:", e.stack?.split('\n')[0..2].join('\n')

# Issue 3: Array elisions
console.log "\n3. Array elision compilation:"
code = '[1,,3]'
try
  # First check what CS3 parses
  cs3Compiler = require './lib/coffeescript/cs3-compiler'
  ast = cs3Compiler.parseCS3(code)
  console.log "CS3 AST:", require('util').inspect(ast, depth: 5)

  # Then compile
  js = CoffeeScript.compile(code, bare: true)
  console.log "Compiled JS:", js.trim()
catch e
  console.log "Error:", e.message
