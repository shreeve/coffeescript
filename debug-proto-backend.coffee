#!/usr/bin/env coffee

# Debug prototype access in backend

fs = require 'fs'
{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

class DebugBackend extends ES5Backend
  evaluateDirective: (directive, frame, ruleName = null) ->
    if directive?.$ast is 'Value'
      console.log "\n=== Creating Value ==="
      console.log "Inner:", directive.inner
      console.log "Properties:", directive.properties
      
    if directive?.$ast is 'Access'
      console.log "\n=== Creating Access ==="
      console.log "Name:", directive.name
      console.log "Shorthand:", directive.shorthand
      console.log "Soak:", directive.soak
    
    try
      result = super(directive, frame, ruleName)
      
      if directive?.$ast is 'Value' and result
        console.log "  Result Value.base:", result.base?.constructor?.name
        console.log "  Result Value.properties:", result.properties?.length
        if result.properties
          for prop, i in result.properties
            console.log "    Property #{i}:", prop
      
      result
    catch e
      console.log "  Error in evaluateDirective:", e.message
      throw e

# Test prototype access
testCode = """
Boolean::custom = 5
"""

console.log "Testing:", testCode

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
  
  backend = new DebugBackend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  console.log "\n✓ Parsed"
  
  js = ast.compile(backend.compileOptions)
  console.log "✓ Compiled!"
  
catch e
  console.log "\n✗ Error:", e.message
  console.log "Stack:", e.stack.split('\n')[0..3].join('\n')
