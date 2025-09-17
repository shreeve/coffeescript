#!/usr/bin/env coffee

# Debug @ symbol handling

fs = require 'fs'
{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

# Test @ symbol
testCode = """
obj =
  value: 42
  getValue: -> @value
"""

console.log "Testing code:"
console.log testCode
console.log ""

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode, {}
  
  console.log "Tokens:"
  for token, i in tokens[0..15]
    [tag, value] = token
    console.log "  #{i}: [#{tag}, #{JSON.stringify(value)}]"
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
  console.log "\nStack:"
  lines = e.stack.split('\n')
  for line in lines[0..8]
    console.log line
