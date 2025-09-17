#!/usr/bin/env coffee

# Analyze test failures to identify most impactful fixes

fs = require 'fs'
path = require 'path'
{Lexer} = require './lib/coffeescript/lexer'
parserCS3 = require './lib/coffeescript/parser-cs3'
ES5Backend = require './lib/backends/es5'

# Error categories
errors = {}
totalTests = 0
passedTests = 0

# Compile function
compileCS3 = (code) ->
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
  ast.compile(backend.compileOptions)

# Test directory
testDir = path.join __dirname, 'test', 'cs3'
testFiles = fs.readdirSync(testDir).filter (file) -> 
  file.endsWith('.test.coffee')

# Process each test file
for testFile in testFiles
  continue if testFile is '30-super-advanced.test.coffee' # Skip super test
  
  content = fs.readFileSync path.join(testDir, testFile), 'utf8'
  tests = content.split(/(?=test ')/).filter (t) -> t.trim()
  
  for test in tests
    totalTests++
    testName = test.match(/test '([^']+)'/)?[1] or 'unnamed'
    
    try
      compiled = compileCS3 test
      # Try to run it
      eval compiled
      passedTests++
    catch e
      # Categorize error
      msg = e.message
      errorKey = 
        if msg.includes('Cannot read properties of undefined')
          "undefined property access: #{msg.match(/reading '([^']+)'/)?[1] or 'unknown'}"
        else if msg.includes('Cannot read properties of null')
          "null property access: #{msg.match(/reading '([^']+)'/)?[1] or 'unknown'}"
        else if msg.includes('is not a function')
          fnMatch = msg.match(/(.+) is not a function/)
          "not a function: #{fnMatch?[1] or msg}"
        else if msg.includes('is not iterable')
          "not iterable"
        else if msg.includes('TODO:')
          msg.match(/TODO: .+/)?[0] or msg
        else if msg.includes('unexpected')
          "parse error: #{msg}"
        else if msg.includes('reserved word')
          "parse error: #{msg}"
        else if msg.includes('Assignment to constant')
          "const assignment"
        else if msg.includes('is not defined')
          varMatch = msg.match(/(.+) is not defined/)
          "undefined: #{varMatch?[1] or msg}"
        else
          msg[0..50]
      
      errors[errorKey] ?= 0
      errors[errorKey]++

# Sort by frequency
sorted = Object.entries(errors).sort (a, b) -> b[1] - a[1]

console.log "\n===== CS3 Failure Analysis ====="
console.log "Total tests: #{totalTests}"
console.log "Passed: #{passedTests} (#{(passedTests/totalTests*100).toFixed(1)}%)"
console.log "Failed: #{totalTests - passedTests} (#{((totalTests-passedTests)/totalTests*100).toFixed(1)}%)"
console.log "\nTop failure categories:"
for [error, count], i in sorted[0..15]
  console.log "  #{count}x - #{error}"
