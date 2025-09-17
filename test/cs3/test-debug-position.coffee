#!/usr/bin/env coffee

# Debug position reference evaluation

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Test the simplest possible code
testCode = "42"
console.log "Testing: '#{testCode}'"

# Create custom backend to trace position references
class TraceBackend extends ES5Backend
  evaluateDirective: (directive, frame, ruleName) ->
    # Special logging for position references
    if typeof directive is 'number'
      console.log "\n=== Position reference: #{directive} in #{ruleName} ==="
      value = frame.rhs[directive - 1]?.value
      console.log "Frame slot #{directive} value:", JSON.stringify(value)[0..300]
      console.log "Value type:", value?.constructor?.name or typeof value
      
      result = super(directive, frame, ruleName)
      console.log "Result after evaluation:", result?.constructor?.name or typeof result
      if result?.constructor?.name
        console.log "Result details:", JSON.stringify(result)[0..300]
      return result
    
    super(directive, frame, ruleName)

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
  
  console.log "\n=== FINAL ==="
  
catch e
  console.log "ERROR:", e.message
  console.log e.stack
