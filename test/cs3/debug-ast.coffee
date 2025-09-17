#!/usr/bin/env coffee

# Debug what the AST looks like

fs = require 'fs'
{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'

console.log "=== CS3 AST INSPECTION ==="
console.log ""

compile = (code, label) ->
  console.log "#{label}: '#{code}'"
  console.log ""
  
  try
    lexer = new Lexer()
    tokens = lexer.tokenize code, {}
    
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
    
    console.log "AST Structure:"
    console.log JSON.stringify(ast, null, 2)
    console.log ""
    
    # Check what type of object we got
    console.log "AST info:"
    console.log "  Type:", ast?.constructor?.name or typeof ast
    console.log "  Has compile method:", ast?.compile?
    console.log "  Has compileNode method:", ast?.compileNode?
    console.log "  Properties:", Object.keys(ast or {})
    console.log ""
    
    # Check the body
    if ast?.body
      console.log "Body info:"
      console.log "  Type:", ast.body?.constructor?.name or typeof ast.body
      console.log "  Has expressions:", ast.body?.expressions?
      console.log "  Expressions length:", ast.body?.expressions?.length
      if ast.body?.expressions?.length > 0
        console.log "  First expression:", JSON.stringify(ast.body.expressions[0], null, 2)
    console.log ""
    
    # Try to compile
    if ast?.compile
      result = ast.compile(backend.compileOptions)
      console.log "Compiled JS:"
      console.log result or "(empty)"
    else
      console.log "Cannot compile - no compile method"
      
  catch e
    console.log "Error:", e.message
    console.log e.stack
    
  console.log "\n" + "="*50 + "\n"

# Test increasingly complex code
compile "42", "Test 1: Simple number"
compile "x = 42", "Test 2: Assignment"  
compile "x = 42\ny = x", "Test 3: Multiple statements"
compile "fn = -> 42", "Test 4: Function"
compile "test 'name', -> 1", "Test 5: Function call"
