{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'
fs = require 'fs'

# Read full test file
fullCode = fs.readFileSync('20-advanced-patterns.test.coffee', 'utf8')
lines = fullCode.split('\n')

# Try to compile progressively more lines to find where the error occurs
step = 10
for endLine in [step..lines.length] by step
  testCode = lines[0...endLine].join('\n')

  try
    lexer = new Lexer()
    tokens = lexer.tokenize testCode

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

    # Generate
    generated = backend.generate ast

  catch err
    if err.message.includes("can't be assigned")
      console.log "Error found when compiling up to line #{endLine}:"
      console.log "Error:", err.message
      console.log "\nLines #{endLine-step} to #{endLine}:"
      console.log lines[endLine-step...endLine].map((l, i) -> "#{endLine-step+i+1}: #{l}").join('\n')
      break

console.log "\nDone"
