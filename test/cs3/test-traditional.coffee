#!/usr/bin/env coffee

###
Run CS3 Test Suite with Traditional CoffeeScript
=================================================
This runs our CS3 test files using the traditional parser/compiler
instead of the CS3/ES5 pipeline, to verify compatibility.
###

fs = require 'fs'
path = require 'path'
CoffeeScript = require '../../lib/coffeescript'

# Test helpers
passedTests = 0
failedTests = 0
errors = []

global.test = (description, fn) ->
  try
    fn()
    passedTests++
    process.stdout.write '.'
  catch error
    failedTests++
    process.stdout.write 'F'
    errors.push {description, error: error.message}

global.eq = (actual, expected) ->
  throw new Error("Expected #{expected}, got #{actual}") unless actual == expected

global.ok = (value) ->
  throw new Error("Expected truthy value, got #{value}") unless value

global.throws = (fn, expected) ->
  try
    fn()
    throw new Error("Expected function to throw")
  catch e
    if expected and e.message.indexOf(expected) == -1
      throw new Error("Expected error containing '#{expected}', got '#{e.message}'")

global.arrayEq = (actual, expected) ->
  throw new Error("Arrays have different lengths") unless actual.length == expected.length
  for val, i in expected
    throw new Error("Arrays differ at index #{i}") unless actual[i] == val

global.deepEqual = (actual, expected) ->
  JSON.stringify(actual) == JSON.stringify(expected)

# Color codes
green = '\x1b[0;32m'
red = '\x1b[0;31m'
yellow = '\x1b[0;33m'
bold = '\x1b[0;1m'
reset = '\x1b[0m'

console.log "#{bold}CS3 Test Suite - Running with Traditional Parser#{reset}\n"

# Get all test files
testDir = __dirname
testFiles = fs.readdirSync(testDir).filter (f) -> f.endsWith('.test.coffee')
testFiles.sort()

totalFiles = testFiles.length
compiledFiles = 0
runFiles = 0

# Run each test file
for filename in testFiles
  filepath = path.join(testDir, filename)
  console.log "\n#{bold}Testing: #{filename}#{reset}"

  try
    # Read the test file
    code = fs.readFileSync(filepath, 'utf8')

    # Compile with TRADITIONAL parser (cs3: false or undefined)
    compiled = CoffeeScript.compile code,
      filename: filename
      bare: true
      cs3: false  # Explicitly use traditional parser

    compiledFiles++

    # Run the compiled JavaScript
    try
      eval(compiled)
      runFiles++
      console.log ''  # newline after dots
    catch runError
      console.log "\n#{red}RUNTIME ERROR: #{runError.message}#{reset}"
      errors.push {description: filename, error: runError.message}

  catch compileError
    console.log "#{red}COMPILATION ERROR: #{compileError.message}#{reset}"
    errors.push {description: filename, error: compileError.message}

# Summary
console.log "\n#{bold}========================================#{reset}"
console.log "#{bold}Results Summary:#{reset}"
console.log "#{bold}========================================#{reset}\n"

console.log "Files:     #{compiledFiles}/#{totalFiles} compiled, #{runFiles}/#{totalFiles} ran"
console.log "Tests:     #{green}Passed: #{passedTests}#{reset}"
console.log "           #{red}Failed: #{failedTests}#{reset}"

if errors.length > 0
  console.log "\n#{bold}Errors:#{reset}"
  for error in errors
    console.log "  #{red}#{error.description}:#{reset} #{error.error}"

successRate = if passedTests + failedTests > 0
  (passedTests / (passedTests + failedTests) * 100).toFixed(1)
else
  "0.0"

console.log "\n#{bold}Success Rate: #{successRate}%#{reset}"

# Comparison
console.log "\n#{bold}========================================#{reset}"
console.log "#{bold}Traditional vs CS3 Comparison:#{reset}"
console.log "#{bold}========================================#{reset}\n"
console.log "Parser:       Traditional (grammar.coffee -> parser.js)"
console.log "AST:          Class-based (nodes.coffee)"
console.log "Tests Run:    CS3 test suite (test/cs3/*.test.coffee)"
console.log "Pass Rate:    #{successRate}%"

# Exit code
process.exit(if failedTests > 0 or errors.length > 0 then 1 else 0)
