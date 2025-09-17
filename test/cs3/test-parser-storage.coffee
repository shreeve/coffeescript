#!/usr/bin/env coffee

# Test how the parser stores reduction results

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
nodes = require '../../lib/coffeescript/nodes'

console.log "Testing parser storage of reduction results"
console.log ""

# Create a minimal backend that tracks what gets stored
class MinimalBackend
  constructor: ->
    @bodyResult = null
    @rootResult = null
    
  reduce: (ruleName, directive, frame) ->
    console.log "REDUCE #{ruleName}:", JSON.stringify(directive)[0..100]
    
    # Manually handle the key reductions
    switch ruleName
      when 'AlphaNumeric'
        # Create a NumberLiteral
        new nodes.NumberLiteral frame.rhs[0].value
        
      when 'Literal'
        # Pass through
        frame.rhs[0].value
        
      when 'Value'
        # Create a Value node
        new nodes.Value frame.rhs[0].value
        
      when 'Expression'
        # Pass through
        frame.rhs[0].value
        
      when 'Line'
        # Pass through
        frame.rhs[0].value
        
      when 'Body'
        if directive.$ary
          # Return an array with the item
          result = [frame.rhs[0].value]
          @bodyResult = result
          console.log "  Body returning array with:", result[0]?.constructor?.name
          result
        else
          # Pass through
          frame.rhs[0].value
          
      when 'Root'
        # Get the body
        body = frame.rhs[0].value
        console.log "  Root received body:", body
        console.log "  Body is array:", Array.isArray(body)
        if Array.isArray(body)
          console.log "  Body[0] type:", body[0]?.constructor?.name
          console.log "  Body[0] is Value:", body[0] instanceof nodes.Value
        
        # Create Root with Block
        bodyArray = if Array.isArray(body) then body else []
        root = new nodes.Root new nodes.Block bodyArray
        @rootResult = root
        root
        
      else
        null

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
  
  backend = new MinimalBackend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  
  console.log "\n=== RESULTS ==="
  console.log "Backend bodyResult[0]:", backend.bodyResult?[0]?.constructor?.name
  console.log "Backend rootResult:", backend.rootResult?.constructor?.name
  console.log "AST:", ast?.constructor?.name
  console.log "AST.body.expressions:", ast?.body?.expressions
  
  if ast?.compile
    js = ast.compile { bare: true }
    console.log "\nCompiled JS:", js
    
catch e
  console.log "ERROR:", e.message
  console.log e.stack
