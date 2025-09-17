{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

testCode = '''
class Derived extends Base
  constructor: (@derived) ->
    super()
'''

console.log "Debugging derived constructor:"

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

  # Hook to see Code directives
  origEval = backend.evaluateDirective
  backend.evaluateDirective = (directive, frame, ruleName) ->
    if directive?.$ast is 'Code'
      console.log "Code directive:"
      console.log "  params:", directive.params
      console.log "  body type:", typeof directive.body

      # Check if body contains super
      bodyEval = origEval.call(this, directive.body, frame, ruleName)
      hasSuper = false
      if bodyEval?.expressions
        for expr in bodyEval.expressions
          if expr?.constructor?.name is 'SuperCall' or expr?.constructor?.name is 'Call' and expr?.variable?.constructor?.name is 'Super'
            hasSuper = true
            break
      console.log "  has super in body:", hasSuper

    origEval.call(this, directive, frame, ruleName)

  parserCS3.parser.yy = { backend }
  parserCS3.parser.lexer = lexIface

  # Parse
  ast = parserCS3.parse()

  # Generate
  generated = backend.generate ast
  console.log "\nGenerated JavaScript:"
  console.log generated

catch err
  console.log "\nError:", err.message
  console.log err.stack?.slice(0, 500)
