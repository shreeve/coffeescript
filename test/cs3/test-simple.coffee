#!/usr/bin/env coffee

# Simplest possible test of CS3 parser

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Test the simplest possible code
testCode = "42"
console.log "Testing: '#{testCode}'"

# Create custom backend to trace everything
class TraceBackend extends ES5Backend
  reduce: (ruleName, directive, frame) ->
    console.log "\n=== REDUCE: #{ruleName} ==="
    console.log "Directive:", JSON.stringify(directive)
    console.log "Frame RHS length:", frame.rhs?.length
    
    if frame.rhs
      for item, i in frame.rhs
        console.log "  Slot #{i+1}:", JSON.stringify(item?.value)[0..100] if item?.value?
    
    result = super(ruleName, directive, frame)
    console.log "Result:", result?.constructor?.name or typeof result
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
  
  console.log "\n=== FINAL AST ==="
  console.log "Type:", ast?.constructor?.name
  console.log "Has compile:", ast?.compile?
  
  if ast?.compile
    js = ast.compile(backend.compileOptions)
    console.log "\n=== COMPILED JS ==="
    console.log js
    
catch e
  console.log "ERROR:", e.message
  console.log e.stack
