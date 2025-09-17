#!/usr/bin/env coffee

{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

class DebugBackend extends ES5Backend
  evaluateDirective: (directive, frame, ruleName) ->
    result = super directive, frame, ruleName
    # Debug constructor params
    if ruleName is 'Code' and directive.params?
      params = @evaluateDirective directive.params, frame, ruleName
      if params?.length > 0
        console.log "\n=== Code (Constructor/Function) ==="
        console.log "Params count:", params.length
        console.log "FuncGlyph:", directive.funcGlyph
    if ruleName is 'Param'
      name = @evaluateDirective directive.name, frame, ruleName
      value = @evaluateDirective directive.value, frame, ruleName
      console.log "\n=== Param ==="
      console.log "Name type:", name?.constructor?.name
      console.log "Name.this:", name?.this
      console.log "Value:", value
    result

code = """
class Point
  constructor: (@x = 0) ->
"""

console.log "Code:"
console.log code
console.log "=" * 50

lexer = new Lexer()
tokens = lexer.tokenize code, {}

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

try
  ast = parserCS3.parse()
  console.log "\n" + "=" * 50
  console.log "\nAST created successfully"
catch e
  console.log "ERROR:", e.message
