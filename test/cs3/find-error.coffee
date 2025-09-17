{Lexer} = require '../../lib/coffeescript/lexer'
parserCS3 = require '../../lib/coffeescript/parser-cs3'
ES5Backend = require '../../lib/backends/es5'
fs = require 'fs'

# Read the test file
code = fs.readFileSync('20-advanced-patterns.test.coffee', 'utf8')

# Split into individual tests
tests = code.split(/^test\s+/m).filter(Boolean)

console.log "Found #{tests.length} tests in file"

for test, i in tests
  testCode = "test #{test}"
  testName = test.split('\n')[0]
  
  try
    lexer = new Lexer()
    tokens = lexer.tokenize testCode
    
    j = 0
    lexIface =
      lex: ->
        return 1 if j >= tokens.length
        t = tokens[j++]
        @yytext = t[1]
        @yylloc = t[2]
        @yylineno = if t[2] then t[2].first_line else 0
        parserCS3.parser.symbolIds[t[0]] or parserCS3.parser.symbolIds[t[1]]
      setInput: -> j = 0
      upcomingInput: -> ''
    
    backend = new ES5Backend()
    parserCS3.parser.yy = { backend }
    parserCS3.parser.lexer = lexIface
    
    ast = parserCS3.parse()
    js = backend.generate ast
    # Test passed compilation
  catch err
    console.log "\n❌ Test #{i+1}: #{testName}"
    console.log "   Error: #{err.message}"
    
    # Try to find the problematic line
    lines = testCode.split('\n')
    for line, lineNum in lines
      if line.includes('1') and (line.includes('=') or line.includes('->'))
        console.log "   Line #{lineNum+1}: #{line.trim()}"

console.log "\n✅ Tests that compile successfully are not shown"
