{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Test problematic numbers
testCode = """
float = 3.141_592_653
"""

console.log "Testing numeric literal:", testCode

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode
  
  console.log "Tokens:"
  for token in tokens when token[0] is 'NUMBER'
    console.log "  NUMBER: '#{token[1]}', parsedValue: #{token.parsedValue}"
  
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
      # Store parsedValue from token if available
      @parsedValue = t.parsedValue if t.parsedValue?
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
  console.log "\nGenerated:\n#{generated}"
  
  # Check if it's valid JS
  require('vm').createScript(generated)
  console.log "Valid JavaScript!"
  
catch err
  console.log "\nError:", err.message
  console.log "Generated code has underscores:", generated if generated?.includes('_')
