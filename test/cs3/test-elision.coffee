fs = require 'fs'
path = require 'path'

# Load CS3 parser and backend
{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

lexer = new Lexer()

testCode = """
[, , third] = [1, 2, 3, 4]
"""

console.log "Testing elision:", testCode

try
  # Tokenize
  tokens = lexer.tokenize testCode
  console.log "\nTokens:"
  for token in tokens[0..10]
    console.log "  #{token[0]}: '#{token[1]}'"

  # Create lexer interface for Solar parser
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

  # Set up parser with ES5 backend
  backend = new ES5Backend()
  parserCS3.parser.yy = { backend }
  parserCS3.parser.lexer = lexIface

  # Parse
  ast = parserCS3.parse()
  console.log "\nParsed AST:", JSON.stringify(ast, null, 2).slice(0, 1000)

  # Generate
  generated = backend.generate ast
  console.log "\nGenerated:", generated
catch err
  console.error "\nError:", err.message
  console.error err.stack
