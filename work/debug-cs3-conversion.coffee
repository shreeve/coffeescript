#!/usr/bin/env coffee

# Debug CS3 conversion issue

Solar = require '../solar'
syntax = require '../src/syntax'

# Check what's in the syntax
console.log "First Root rule:"
console.log JSON.stringify(syntax.grammar.Root[0], null, 2)
console.log ""
console.log "Second Root rule:"
console.log JSON.stringify(syntax.grammar.Root[1], null, 2)
console.log ""

# Create generator
generator = new Solar.Generator(syntax, {})

# Check CS3 mode
console.log "CS3 mode detected: #{generator.cs3Mode}"
console.log ""

# Try converting a simple CS3 directive manually
testDirective = {$ast: '@', body: []}
console.log "Test directive:"
console.log JSON.stringify(testDirective)

# Check if it's an object
console.log "typeof testDirective: #{typeof testDirective}"
console.log ""

# Try to generate and see what happens
console.log "Generating parser..."
try
  parserCode = generator.generate()

  # Find the problematic line
  lines = parserCode.split('\n')
  problemLine = lines.find (line) -> line.includes('[object Object]')

  if problemLine
    console.log "Found problem line:"
    console.log problemLine

    # Find surrounding context
    idx = lines.indexOf(problemLine)
    console.log "\nContext:"
    for i in [Math.max(0, idx-3)...Math.min(lines.length, idx+4)]
      console.log "#{i}: #{lines[i]}"
  else
    console.log "No [object Object] found in generated code!"
catch e
  console.error "Error:", e.message
