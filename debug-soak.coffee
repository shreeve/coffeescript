#!/usr/bin/env coffee

# Debug soaked access

fs = require 'fs'
{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

# Test soaked access/calls
testCode = """
obj =
  method: -> 42

result = obj.method?()
result2 = obj.missing?()
"""

console.log "Testing code:"
console.log testCode
console.log ""

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
  
  backend = new ES5Backend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  console.log "✓ Parsed"
  
  js = ast.compile(backend.compileOptions)
  console.log "✓ Compiled!"
  console.log "\nJS output:"
  console.log js
  
catch e
  console.log "✗ Error:", e.message
  if e.stack
    console.log "\nStack:"
    lines = e.stack.split('\n')
    for line in lines[0..8]
      console.log line
