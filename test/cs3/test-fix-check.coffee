#!/usr/bin/env coffee

# Check if our fix is working but JSON.stringify is misleading us

{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'
nodes = require '../../lib/coffeescript/nodes'

# Test the simplest possible code
testCode = "42"
console.log "Testing: '#{testCode}'"

try
  lexer = new Lexer()
  tokens = lexer.tokenize testCode, {}
  
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
  
  console.log "\nAST type:", ast?.constructor?.name
  console.log "AST is Root node:", ast instanceof nodes.Root
  console.log "AST.body type:", ast?.body?.constructor?.name
  console.log "AST.body is Block:", ast?.body instanceof nodes.Block
  console.log "AST.body.expressions:", ast?.body?.expressions
  console.log "AST.body.expressions length:", ast?.body?.expressions?.length
  
  if ast?.body?.expressions?[0]
    firstExpr = ast.body.expressions[0]
    console.log "\nFirst expression type:", firstExpr?.constructor?.name
    console.log "First expression is node:", firstExpr instanceof nodes.Base
    console.log "First expression value:", firstExpr
  
  if ast?.compile
    js = ast.compile(backend.compileOptions)
    console.log "\n=== COMPILED JS ==="
    console.log "Length:", js.length
    console.log "Content:", js or "(empty)"
    
catch e
  console.log "ERROR:", e.message
  console.log e.stack
