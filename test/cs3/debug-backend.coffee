#!/usr/bin/env coffee

# Debug what the backend is receiving and producing

fs = require 'fs'
{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'

class DebugBackend
  constructor: (@options = {}) ->
    @compileOptions = 
      bare: true
      header: false
    @allReductions = []
    @rootNode = null
    
  reduce: (ruleName, directive, frame) ->
    # Log everything
    info = 
      rule: ruleName
      directive: directive
      frameLength: frame?.rhs?.length
      
    @allReductions.push info
    
    # Try to build a simple node
    result = @evaluate directive, frame, ruleName
    
    # Capture root
    if ruleName is 'Root'
      @rootNode = result
      console.log "ROOT CAPTURED:", JSON.stringify(result, null, 2)[0..500]
      
    result
    
  evaluate: (d, fr, rn=null) ->
    # Simple evaluation
    if typeof d is 'number'
      return fr.rhs[d-1]?.value
      
    if typeof d is 'string'
      return d
      
    if d?.type
      return d
      
    if d?.$ast
      # Build AST node based on $ast type
      switch d.$ast
        when 'Root'
          # Create a Root node
          nodes = require '../../lib/coffeescript/nodes'
          body = @evaluate(d.body, fr, rn) or new nodes.Block()
          return new nodes.Root(body)
          
        when 'Block'
          nodes = require '../../lib/coffeescript/nodes'
          expressions = d.expressions or []
          block = new nodes.Block()
          for expr in expressions
            evaluated = @evaluate(expr, fr, rn)
            block.expressions.push evaluated if evaluated
          return block
          
        when 'Assign'
          nodes = require '../../lib/coffeescript/nodes'
          variable = @evaluate(d.variable, fr, rn)
          value = @evaluate(d.value, fr, rn)
          return new nodes.Assign(variable, value) if variable and value
          
        when 'Value'
          nodes = require '../../lib/coffeescript/nodes'
          val = @evaluate(d.val, fr, rn)
          return new nodes.Value(val) if val
          
        when 'IdentifierLiteral'
          nodes = require '../../lib/coffeescript/nodes'
          value = @evaluate(d.value, fr, rn)
          return new nodes.IdentifierLiteral(value)
          
        when 'NumberLiteral'
          nodes = require '../../lib/coffeescript/nodes'
          value = @evaluate(d.value, fr, rn)
          return new nodes.NumberLiteral(value)
          
    if d?.$use
      # Reference to frame slot
      return fr.rhs[d.$use - 1]?.value
      
    # Return as-is
    d

console.log "=== BACKEND DEBUG ==="
console.log ""

testCode = "x = 42"
console.log "Testing:", testCode
console.log ""

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode, {}
  console.log "Tokens:", tokens.map((t) -> "#{t[0]}:#{t[1]}").join(', ')
  console.log ""
  
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
  
  backend = new DebugBackend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  result = parserCS3.parse()
  
  console.log ""
  console.log "Parse result type:", result?.constructor?.name
  console.log "Parse result:", JSON.stringify(result, null, 2)[0..500]
  console.log ""
  console.log "All reductions:"
  for red, i in backend.allReductions
    if typeof red.directive is 'object'
      dir = JSON.stringify(red.directive)[0..80]
    else
      dir = String(red.directive)
    console.log "  #{i+1}. #{red.rule}: #{dir}"
    
catch e
  console.log "Error:", e.message
  console.log e.stack
