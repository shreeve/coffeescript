{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

testCode = '''
fn = =>
  42
'''

console.log "Testing arrow function directive:"

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode
  
  console.log "Tokens:"
  for token in tokens
    if token[0] in ['FUNC_ARROW', '=>', 'ARROW', '->']
      console.log "  Found arrow token:", token
  
  i = 0
  lexIface =
    lex: ->
      return 1 if i >= tokens.length
      t = tokens[i++]
      @yytext = t[1]
      @yylloc = t[2]
      @yylineno = if t[2] then t[2].first_line else 0
      parserCS3.parser.symbolIds[t[0]] or parserCS3.parser.symbolIds[t[1]]
    setInput: -> i = 0
    upcomingInput: -> ''
  
  backend = new ES5Backend()
  
  # Monitor all directive evaluations
  origEval = backend.evaluateDirective
  backend.evaluateDirective = (directive, frame, ruleName) ->
    if directive?.$ast in ['Code', 'Function', 'Arrow']
      console.log "\n=== #{directive.$ast} directive ==="
      console.log "  Full:", JSON.stringify(directive).slice(0, 400)
    
    origEval.call(this, directive, frame, ruleName)
  
  parserCS3.parser.yy = { backend }
  parserCS3.parser.lexer = lexIface
  
  ast = parserCS3.parse()
  js = backend.generate ast
  
  console.log "\nGenerated JavaScript:"
  console.log js
  
catch err
  console.log "\n✗ Error:", err.message
