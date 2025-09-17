{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

testCode = '''
@arrow = =>
  super.method()
'''

console.log "Testing Code directive for arrow function:"

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode
  
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
  
  # Monitor Code directive evaluation
  origEval = backend.evaluateDirective
  backend.evaluateDirective = (directive, frame, ruleName) ->
    if directive?.$ast is 'Code'
      console.log "\n=== Code directive ==="
      console.log "  Full directive:", JSON.stringify(directive).slice(0, 500)
      console.log "  funcGlyph:", directive.funcGlyph
      console.log "  bound:", directive.bound
    
    origEval.call(this, directive, frame, ruleName)
  
  parserCS3.parser.yy = { backend }
  parserCS3.parser.lexer = lexIface
  
  ast = parserCS3.parse()
  
  console.log "\n✓ Parse successful!"
  
catch err
  console.log "\n✗ Error:", err.message
