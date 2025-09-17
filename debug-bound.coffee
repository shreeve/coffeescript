{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'
nodes = require './lib/coffeescript/nodes'

testCode = '''
@arrow = =>
  super.method()
'''

console.log "Testing bound function detection:"

# Monitor Code node creation
origCodeConstructor = nodes.Code
nodes.Code = class extends origCodeConstructor
  constructor: (params, body, funcGlyph, paramStart) ->
    console.log "\n=== Creating Code node ==="
    console.log "  funcGlyph:", funcGlyph
    console.log "  funcGlyph.glyph:", funcGlyph?.glyph
    console.log "  bound will be:", funcGlyph?.glyph is '=>'
    super(params, body, funcGlyph, paramStart)
    console.log "  this.bound:", @bound

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
  parserCS3.parser.yy = { backend }
  parserCS3.parser.lexer = lexIface
  
  ast = parserCS3.parse()
  js = backend.generate ast
  
  console.log "\nGenerated JavaScript:"
  console.log js
  
catch err
  console.log "\n✗ Error:", err.message
