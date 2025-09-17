#!/usr/bin/env coffee

# Find where the Body array gets corrupted

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'
nodes = require '../../lib/coffeescript/nodes'

console.log "Testing Body array corruption"
console.log ""

# Track the array through reductions
bodyArray = null

class TrackingBackend extends ES5Backend
  reduce: (ruleName, directive, frame) ->
    if ruleName is 'Body'
      console.log "\n=== Body reduction ==="
      console.log "Directive:", JSON.stringify(directive)
      console.log "Frame slots:", frame.rhs.length
      
      for slot, i in frame.rhs
        val = slot?.value
        if Array.isArray(val)
          console.log "  Slot #{i+1}: Array with #{val.length} items"
          for item, j in val
            if item instanceof nodes.Base
              console.log "    [#{j}]: #{item.constructor.name} node"
            else
              console.log "    [#{j}]:", typeof item, item
        else if val instanceof nodes.Base
          console.log "  Slot #{i+1}: #{val.constructor.name} node"
        else
          console.log "  Slot #{i+1}:", typeof val, JSON.stringify(val)[0..50]
    
    result = super(ruleName, directive, frame)
    
    if ruleName is 'Body'
      console.log "Body result:", typeof result
      if Array.isArray(result)
        console.log "  Array with #{result.length} items"
        for item, j in result
          if item instanceof nodes.Base
            console.log "    [#{j}]: #{item.constructor.name} node"
          else
            console.log "    [#{j}]:", typeof item, JSON.stringify(item)[0..100]
        
        # Save reference to track corruption
        if directive.$ary
          bodyArray = result
          console.log "  Saved bodyArray reference"
    
    result

testCode = "42"

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
  
  backend = new TrackingBackend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  
  console.log "\n=== Final check ==="
  console.log "bodyArray still has #{bodyArray?.length} items"
  if bodyArray?[0]
    if bodyArray[0] instanceof nodes.Base
      console.log "bodyArray[0] is still a #{bodyArray[0].constructor.name}"
    else
      console.log "bodyArray[0] has been corrupted to:", bodyArray[0]
  
catch e
  console.log "ERROR:", e.message
  console.log e.stack
