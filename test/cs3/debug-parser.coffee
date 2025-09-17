#!/usr/bin/env coffee

# Debug CS3 parser - is it even parsing?

fs = require 'fs'
{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

console.log "=== CS3 PARSER DIAGNOSTIC ==="
console.log ""

# Test 1: Simplest possible code
simpleCode = "x = 42"
console.log "Test 1: '#{simpleCode}'"

try
  # Step 1: Tokenize
  lexer = new Lexer()
  tokens = lexer.tokenize simpleCode, {}
  console.log "  ✓ Tokenized: #{tokens.length} tokens"
  console.log "    Tokens:", (t[0] for t in tokens).join(', ')
  
  # Step 2: Parse with CS3
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
  
  backend = new ES5Backend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  console.log "  ✓ Parsed successfully!"
  console.log "    AST type:", ast?.constructor?.name or typeof ast
  console.log "    AST:", JSON.stringify(ast, null, 2)[0..200] + "..."
  
  # Step 3: Try to compile
  if ast?.compile
    js = ast.compile(backend.compileOptions)
    console.log "  ✓ Compiled!"
    console.log "    JS:", js[0..100] + "..."
  else if backend?.generate
    js = backend.generate(ast)
    console.log "  ✓ Generated via backend!"
    console.log "    JS:", js[0..100] + "..."
  else
    console.log "  ✗ No compile method on AST and no generate on backend"

catch e
  console.log "  ✗ Error:", e.message
  console.log "    Stack:", e.stack.split('\n')[0..3].join('\n')

console.log ""
console.log "Test 2: Simple test function"
testCode = """
test 'simple test', ->
  x = 1
  eq x, 1
"""

console.log "Code:"
console.log testCode
console.log ""

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode, {}
  console.log "  ✓ Tokenized: #{tokens.length} tokens"
  
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
  
  backend = new ES5Backend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  console.log "  ✓ Parsed!"
  console.log "    AST type:", ast?.constructor?.name or typeof ast
  
  if ast?.compile
    js = ast.compile(backend.compileOptions)
    console.log "  ✓ Compiled!"
    console.log ""
    console.log "Generated JavaScript:"
    console.log "===================="
    console.log js
    console.log "===================="
  else
    console.log "  ✗ AST has no compile method"

catch e
  console.log "  ✗ Error:", e.message
  console.log "    At:", e.stack.split('\n')[1]

console.log ""
console.log "Test 3: Let's see what the backend's reduce method gets"
console.log ""

class DebugBackend extends ES5Backend
  constructor: (options) ->
    super(options)
    @reductions = []
    
  reduce: (ruleName, directive, frame) ->
    @reductions.push { ruleName, directive: JSON.stringify(directive)[0..100] }
    super(ruleName, directive, frame)

try
  simpleCode2 = "test 'name', -> eq 1, 1"
  lexer = new Lexer()
  tokens = lexer.tokenize simpleCode2, {}
  
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
  
  backend = new DebugBackend()
  parserCS3.parser.lexer = lexIface
  parserCS3.parser.yy = { backend }
  
  ast = parserCS3.parse()
  
  console.log "Parser reductions (first 10):"
  for red, idx in backend.reductions[0..9]
    console.log "  #{idx + 1}. #{red.ruleName}: #{red.directive}"
  
  if backend.reductions.length > 10
    console.log "  ... and #{backend.reductions.length - 10} more"

catch e
  console.log "  Error:", e.message
