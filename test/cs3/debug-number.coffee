{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

# Test problematic numbers
testCode = """
float = 3.141_592_653
exp = 1.23e4_5
"""

console.log "Testing numeric literals with separators..."

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode
  
  console.log "\nTokens:"
  for token in tokens when token[0] is 'NUMBER'
    console.log "  NUMBER: '#{token[1]}'"
    console.log "    parsedValue:", token[1].parsedValue if token[1].parsedValue?
  
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
      # Store parsedValue if it exists
      @parsedValue = t[1].parsedValue if t[1]?.parsedValue?
      parserCS3.parser.symbolIds[t[0]] or parserCS3.parser.symbolIds[t[1]]
    setInput: -> i = 0
    upcomingInput: -> ''
    
  # Set up parser with ES5 backend
  backend = new ES5Backend()
  
  # Hook the NumberLiteral creation
  origEvaluate = backend.evaluateDirective
  backend.evaluateDirective = (directive, frame, ruleName) ->
    if directive.$ast is 'NumberLiteral'
      console.log "\nNumberLiteral directive:"
      console.log "  value:", directive.value
      console.log "  parsedValue:", directive.parsedValue
      
      # Call original and inspect result
      result = origEvaluate.call(this, directive, frame, ruleName)
      console.log "  Created node with value:", result.value
      result
    else
      origEvaluate.call(this, directive, frame, ruleName)
  
  parserCS3.parser.yy = { backend }
  parserCS3.parser.lexer = lexIface
  
  # Parse
  ast = parserCS3.parse()
  
  # Generate
  generated = backend.generate ast
  console.log "\nGenerated:\n#{generated}"
  
catch err
  console.log "\nError:", err.message
