#!/usr/bin/env coffee

###
CS3/ES5 Test Runner
===================
Executes all test files in the test/cs3 directory
Usage: ./bin/coffee test/cs3/test-cs3.coffee
###

fs = require 'fs'
path = require 'path'
CoffeeScript = require '../../lib/coffeescript'

# ANSI colors
green = '\x1B[0;32m'
red = '\x1B[0;31m'
yellow = '\x1B[0;33m'
bold = '\x1B[0;1m'
reset = '\x1B[0m'

# Test tracking
passed = 0
failed = 0
errors = []

# Simple test function
global.test = (name, fn) ->
  try
    fn()
    passed++
    console.log "#{green}✓#{reset} #{name}"
  catch e
    failed++
    errors.push {name, error: e.message}
    console.log "#{red}✗#{reset} #{name}: #{e.message}"

# Test helpers
global.eq = (actual, expected) ->
  if actual isnt expected
    throw new Error "Expected #{expected}, got #{actual}"

global.ok = (value) ->
  throw new Error "Expected truthy value" unless value

global.throws = (fn, message) ->
  try
    fn()
    throw new Error "Expected error: #{message}"
  catch e
    throw e if e.message is "Expected error: #{message}"

global.arrayEq = (actual, expected) ->
  throw new Error "Arrays have different lengths" unless actual.length is expected.length
  for val, i in expected
    throw new Error "Arrays differ at index #{i}" unless actual[i] is val

global.deepEqual = (actual, expected) ->
  JSON.stringify(actual) is JSON.stringify(expected)

# Compile with CS3
compileCS3 = (code, options = {}) ->
  options.cs3 = true
  CoffeeScript.compile code, options

# Run a test file
runTestFile = (filepath) ->
  console.log "\n#{bold}Testing: #{path.basename(filepath)}#{reset}"
  code = fs.readFileSync(filepath, 'utf8')

  try
    # Compile with CS3
    js = compileCS3(code, bare: true, filename: filepath)

    # Run the compiled code
    eval(js)
  catch e
    failed++
    errors.push {name: filepath, error: e.message}
    console.log "#{red}Compilation/Runtime Error: #{e.message}#{reset}"

# Main
console.log "#{bold}CS3/ES5 Test Suite#{reset}\n"

# Find all test files in the current directory (test/cs3/)
testDir = __dirname
testFiles = fs.readdirSync(testDir)
  .filter (f) -> f.endsWith('.test.coffee')
  .sort()  # Ensure tests run in order
  .map (f) -> path.join(testDir, f)

# Run each test file
for file in testFiles
  runTestFile(file)

# Summary
console.log "\n#{bold}Results:#{reset}"
console.log "#{green}Passed: #{passed}#{reset}"
if failed > 0
  console.log "#{red}Failed: #{failed}#{reset}"
  console.log "\n#{bold}Errors:#{reset}"
  for {name, error} in errors
    console.log "  #{red}#{name}:#{reset} #{error}"
else
  console.log "#{green}All tests passed!#{reset}"

process.exit(if failed > 0 then 1 else 0)
