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
  
  # Write to file for inspection
  fs.writeFileSync('/tmp/generated.js', generated)
  console.log "Written to /tmp/generated.js"
  
  # Try to parse it with Node's parser
  require('vm').createScript(generated)
  console.log "Valid JavaScript syntax!"
  
catch err
  console.log "\nError:", err.message
  if generated
    lines = generated.split('\n')
    console.log "\nLast few lines of generated code:"
    console.log lines.slice(-10).join('\n')
