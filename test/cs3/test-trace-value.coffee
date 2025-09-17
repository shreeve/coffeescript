#!/usr/bin/env coffee

# Trace what happens to the Value node

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'
nodes = require '../../lib/coffeescript/nodes'

# Test the simplest possible code
testCode = "42"
console.log "Testing: '#{testCode}'"

# Create custom backend to trace Value handling
class TraceBackend extends ES5Backend
  evaluateDirective: (directive, frame, ruleName) ->
    result = super(directive, frame, ruleName)
    
    # Log when we handle $ary
    if directive?.$ary?
      console.log "\n=== After $ary in #{ruleName} ==="
      console.log "Input directive:", JSON.stringify(directive)
      console.log "Result type:", result?.constructor?.name or typeof result
      console.log "Result is array:", Array.isArray(result)
      if Array.isArray(result)
        for item, i in result
          if item instanceof nodes.Base
            console.log "  Item #{i}: #{item.constructor.name} node"
          else
            console.log "  Item #{i}:", typeof item, JSON.stringify(item)[0..100]
    
    result
    
  reduce: (ruleName, directive, frame) ->
    # Log Body reduction in detail
    if ruleName is 'Body' and directive?.$ary?
      console.log "\n=== Body REDUCE with $ary ==="
      console.log "Directive:", JSON.stringify(directive)
      console.log "Frame RHS:"
      for slot, i in frame.rhs
        if slot?.value instanceof nodes.Base
          console.log "  Slot #{i+1}: #{slot.value.constructor.name} node"
        else
          console.log "  Slot #{i+1}:", JSON.stringify(slot?.value)[0..200]
    
    result = super(ruleName, directive, frame)
    
    if ruleName is 'Body' and directive?.$ary?
      console.log "Body result type:", result?.constructor?.name or typeof result
      console.log "Body result:", JSON.stringify(result)[0..200]
    
    result

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode, {}
  
  i = 0
  lexIface =
    lex: ->
      return 1 if i >= tokens.length
      t = tokens[i++]
      @yytext = t[1]
      @yylloc = t[2]
      @yylineno = if t[2] then t[2].first_line else 0
      @yyleng = String(@yytext).length
      parserCS3.parser.symbolIds[t[0]] or parserCS3.parser.symbolIds[t[1]]
    setInput: -> i = 0
    upcomingInput: -> ''
  
  backend = new TraceBackend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  
  console.log "\n=== DONE ==="
  
catch e
  console.log "ERROR:", e.message
  console.log e.stack
