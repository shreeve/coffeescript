fs = require 'fs'
{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Read the full test file
testCode = fs.readFileSync('15-advanced-literals.test.coffee', 'utf8')

console.log "Compiling 15-advanced-literals.test.coffee with CS3..."

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
  
  console.log "Success! Generated #{generated.length} characters of JS"
  
  # Try to run it
  eval generated
  console.log "Code executed without errors!"
  
catch err
  console.log "\nError:", err.message
  console.log "At line:", err.location?.first_line if err.location
  # Find the token around the error
  if i > 0 and i <= tokens.length
    console.log "Near token #{i}:", tokens[i-1..i+1].map((t) -> "#{t[0]}:#{t[1]}").join(", ")
