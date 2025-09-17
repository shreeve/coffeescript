#!/usr/bin/env coffee

# Debug the $ary directive issue

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Test the simplest possible code
testCode = "42"
console.log "Testing: '#{testCode}'"

# Create custom backend to trace $ary handling
class TraceBackend extends ES5Backend
  evaluateDirective: (directive, frame, ruleName) ->
    # Special logging for $ary
    if directive?.$ary?
      console.log "\n=== $ary directive in #{ruleName} ==="
      console.log "Array items:", directive.$ary
      console.log "Frame RHS:"
      for item, i in frame.rhs
        console.log "  Slot #{i+1}:", JSON.stringify(item?.value)[0..200] if item?.value?
      
      result = super(directive, frame, ruleName)
      console.log "Result after $ary processing:", JSON.stringify(result)[0..200]
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
  
  console.log "\n=== FINAL AST ==="
  console.log "Type:", ast?.constructor?.name
  console.log "Body:", ast?.body
  console.log "Body expressions:", ast?.body?.expressions
  
  if ast?.compile
    js = ast.compile(backend.compileOptions)
    console.log "\n=== COMPILED JS ==="
    console.log js or "(empty)"
    
catch e
  console.log "ERROR:", e.message
  console.log e.stack
