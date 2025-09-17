CoffeeScript = require '../../lib/coffeescript'
{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Test the problematic line
testCode = """
exp = 1.23e4_5  # Separators in exponent
"""

console.log "Testing code:", testCode

# Try with CS2
try
  result = CoffeeScript.compile testCode, {bare: yes}
  console.log "\nCS2 Success:", result
catch err
  console.log "\nCS2 Error:", err.message

# Try with CS3
try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode
  console.log "\nTokens:", tokens[0..5].map((t) -> "#{t[0]}:#{t[1]}").join(", ")
  
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
  console.log "\nCS3 Generated:", generated
catch err
  console.log "\nCS3 Error:", err.message
  console.log err.stack
