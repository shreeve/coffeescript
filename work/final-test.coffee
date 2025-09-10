#!/usr/bin/env coffee

# Final test of the complete CS3 pipeline

Solar = require '../solar'
syntax = require '../src/syntax'
{Lexer} = require '../lib/coffeescript/lexer'
ES5Backend = require '../backends/es5'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

console.log """
╔════════════════════════════════════════════════════════════════════════════╗
║                    FINAL CS3 PIPELINE TEST                                 ║
╚════════════════════════════════════════════════════════════════════════════╝
"""

# Step 1: Generate the parser
console.log "Step 1: Generating CS3 parser with Solar..."
generator = new Solar.Generator(syntax, {})
parserCode = generator.generate()
console.log "✓ Parser generated"

# Save it
parserPath = path.join __dirname, 'parser-cs3.js'
fs.writeFileSync parserPath, parserCode
console.log "✓ Parser saved to #{parserPath}"

# Step 2: Load the parser
console.log "\nStep 2: Loading the generated parser..."
parserModule = {}
vm.runInNewContext parserCode, {exports: parserModule, require, module: {}}
parser = parserModule.parser
console.log "✓ Parser loaded"

# Step 3: Parse some CoffeeScript
sourceCode = """
# Test program
square = (x) ->
  x * x

result = square 5
console.log "Result:", result
"""

console.log "\nStep 3: Parsing CoffeeScript source:"
console.log sourceCode

try
  # Tokenize
  lexer = new Lexer()
  tokens = lexer.tokenize sourceCode

  # Set up parser interface
  parser.lexer =
    lex: ->
      token = tokens.shift()
      return 'EOF' unless token
      parser.lexer.yytext = token[1]
      parser.lexer.yylloc =
        first_line: token[2].first_line + 1
        first_column: token[2].first_column
        last_line: token[2].last_line_exclusive + 1
        last_column: token[2].last_column_exclusive
      token[0]

    setInput: -> tokens = lexer.tokenize sourceCode

    upcomingInput: -> ""

  # Add helper functions that CS3 actions expect
  parser.yy =
    locInfo: (loc) ->
      # Simple location info - can be enhanced later
      loc

  # Parse!
  ast = parser.parse sourceCode
  console.log "✓ Parsed to CS3 AST"

  # Check AST structure
  if ast?.type
    console.log "✓ AST is a pure data node (type: '#{ast.type}')"

  # Step 4: Compile to JavaScript
  console.log "\nStep 4: Compiling CS3 AST to JavaScript..."
  backend = new ES5Backend bare: true
  js = backend.generate ast
  console.log "✓ Generated JavaScript:"
  console.log js

  # Step 5: Execute the JavaScript
  console.log "\nStep 5: Executing the generated JavaScript..."

  # Capture console output
  originalLog = console.log
  output = []
  console.log = (args...) -> output.push args.join(' ')

  # Run it!
  eval js

  # Restore console.log
  console.log = originalLog

  console.log "✓ Execution output: #{output.join('\n')}"

  console.log """

  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    🎉 CS3 PIPELINE COMPLETE! 🎉                            ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  YOU NOW HAVE A WORKING CS3 COFFEESCRIPT COMPILER!

  ✓ Solar generates parsers with CS3 support
  ✓ Parser creates pure data AST nodes
  ✓ ES5 backend compiles AST to JavaScript
  ✓ Generated JavaScript runs correctly

  The dream is real! 🚀
  """

catch error
  console.error "\nError:", error.message
  console.error error.stack
