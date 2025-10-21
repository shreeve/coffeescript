#!/usr/bin/env coffee

# Pure ES6 CoffeeScript Test Runner
# Simple, clean testing with just three functions: test, code, fail

import fs from 'fs'
import path from 'path'
import vm from 'vm'
import {fileURLToPath} from 'url'
import CoffeeScript from '../lib/coffeescript/index.js'

# ANSI colors for output
bold   = '\x1B[0;1m'
red    = '\x1B[0;31m'
green  = '\x1B[0;32m'
yellow = '\x1B[0;33m'
reset  = '\x1B[0m'

# Disable colors if requested
if process.env.NODE_DISABLE_COLORS
  bold = red = green = yellow = reset = ''

# Track test results
passed = 0
failed = 0
failures = []
currentFile = null

# Get current directory for ES6 modules
__dirname = path.dirname fileURLToPath(import.meta.url)

# Parse flexible arguments: can be (description, source, expected) or (source, expected)
parseArgs = (args, maxArgs) ->
  if args.length is maxArgs
    args
  else if args.length is maxArgs - 1
    [null, args...]  # No description
  else
    throw new Error "Expected #{maxArgs-1} or #{maxArgs} arguments, got #{args.length}"

# Helper to check equality (handles objects/arrays)
equal = (actual, expected) ->
  if actual is expected
    true
  else if Array.isArray(actual) and Array.isArray(expected)
    return false if actual.length isnt expected.length
    actual.every (val, i) -> equal val, expected[i]
  else if actual?.constructor is Object and expected?.constructor is Object
    keys1 = Object.keys(actual).sort()
    keys2 = Object.keys(expected).sort()
    return false if not equal keys1, keys2
    keys1.every (key) -> equal actual[key], expected[key]
  else
    false

# Test runtime behavior - executes code and compares result
test = (args...) ->
  [description, source, expected] = parseArgs args, 3
  description ?= "test ##{passed + failed + 1}"

  try
    # Compile the CoffeeScript
    compiled = CoffeeScript.compile source, bare: yes, filename: "#{currentFile}:test"

    # Create a clean context for execution
    context =
      console: console
      setTimeout: setTimeout
      setInterval: setInterval
      clearTimeout: clearTimeout
      clearInterval: clearInterval
      Promise: Promise
      Buffer: Buffer
      process: process
      Math: Math
      Date: Date
      Array: Array
      Object: Object
      String: String
      Number: Number
      Boolean: Boolean
      RegExp: RegExp
      Error: Error
      JSON: JSON

    # Run in isolated context
    result = vm.runInNewContext compiled, context,
      filename: "#{currentFile}:test"
      timeout: 5000  # 5 second timeout for tests

    # Handle async results
    checkResult = (actual) ->
      if equal actual, expected
        passed++
        console.log "#{green}  ✓ #{description}#{reset}"
      else
        failed++
        failures.push {currentFile, description, actual, expected, type: 'test'}
        console.log "#{red}  ✗ #{description}${reset}"
        console.log "#{red}    Expected: #{JSON.stringify expected}#{reset}"
        console.log "#{red}    Got:      #{JSON.stringify actual}#{reset}"

    # Check if result is a Promise
    if result?.then
      result.then checkResult, (err) ->
        failed++
        failures.push {currentFile, description, error: err, type: 'test-error'}
        console.log "#{red}  ✗ #{description} (async error)#{reset}"
        console.log "#{red}    #{err.message}#{reset}"
    else
      checkResult result

  catch err
    failed++
    failures.push {currentFile, description, error: err, type: 'test-error'}
    console.log "#{red}  ✗ #{description} (compilation/runtime error)#{reset}"
    console.log "#{red}    #{err.message}#{reset}"

# Test compilation output - compares generated JavaScript
code = (args...) ->
  [description, source, expectedJS] = parseArgs args, 3
  description ?= "code ##{passed + failed + 1}"

  try
    # Compile and normalize whitespace for comparison
    actualJS = CoffeeScript.compile source, bare: yes
    actualClean = actualJS.trim().replace(/\s+/g, ' ')
    expectedClean = expectedJS.trim().replace(/\s+/g, ' ')

    if actualClean is expectedClean
      passed++
      console.log "#{green}  ✓ #{description}#{reset}"
    else
      failed++
      failures.push {currentFile, description, actual: actualJS, expected: expectedJS, type: 'code'}
      console.log "#{red}  ✗ #{description}#{reset}"
      console.log "#{red}    Expected JS:#{reset}"
      console.log "#{yellow}#{expectedJS.split('\n').map((l) -> '      ' + l).join('\n')}#{reset}"
      console.log "#{red}    Generated JS:#{reset}"
      console.log "#{yellow}#{actualJS.split('\n').map((l) -> '      ' + l).join('\n')}#{reset}"

  catch err
    failed++
    failures.push {currentFile, description, error: err, type: 'code-error'}
    console.log "#{red}  ✗ #{description} (compilation error)#{reset}"
    console.log "#{red}    #{err.message}#{reset}"

# Test compilation failures - ensures code properly fails
fail = (args...) ->
  [description, source] = parseArgs args, 2
  description ?= "fail ##{passed + failed + 1}"

  try
    CoffeeScript.compile source, bare: yes
    # If we get here, compilation succeeded when it shouldn't have
    failed++
    failures.push {currentFile, description, type: 'fail-passed'}
    console.log "#{red}  ✗ #{description}#{reset}"
    console.log "#{red}    Expected compilation to fail, but it succeeded#{reset}"
  catch err
    # Good! It failed as expected
    passed++
    console.log "#{green}  ✓ #{description}#{reset}"

# Recursively find all .coffee files in a directory
findCoffeeFiles = (dir) ->
  results = []
  try
    files = fs.readdirSync dir
  catch
    return results

  for file in files
    filePath = path.join dir, file
    try
      stat = fs.statSync filePath
      if stat.isDirectory()
        # Skip node_modules and hidden directories
        continue if file is 'node_modules' or file.startsWith('.')
        results = results.concat findCoffeeFiles(filePath)
      else if file.endsWith('.coffee') and file isnt 'runner.coffee'
        results.push filePath
    catch
      # Skip files we can't access
  results

# Collect test files from command line arguments
collectTestFiles = (paths) ->
  testFiles = []

  for testPath in paths
    # Resolve relative paths
    fullPath = path.resolve testPath

    try
      stat = fs.statSync fullPath
      if stat.isDirectory()
        testFiles = testFiles.concat findCoffeeFiles(fullPath)
      else if stat.isFile() and testPath.endsWith('.coffee')
        testFiles.push fullPath
    catch err
      console.error "#{red}Cannot access: #{testPath}#{reset}"
      console.error "#{red}  #{err.message}#{reset}"

  # Remove duplicates and sort
  Array.from(new Set(testFiles)).sort()

# Main test runner
runTests = (testFiles) ->
  console.log "#{bold}Running #{testFiles.length} test file(s)#{reset}\n"

  for file in testFiles
    currentFile = file
    relativePath = path.relative process.cwd(), file
    console.log "\n#{bold}#{relativePath}:#{reset}"

    try
      source = fs.readFileSync file, 'utf8'

      # Compile the test file
      compiled = CoffeeScript.compile source,
        bare: yes
        filename: file

      # Create context with test functions
      context =
        test: test
        code: code
        fail: fail
        console: console
        setTimeout: setTimeout
        setInterval: setInterval
        clearTimeout: clearTimeout
        clearInterval: clearInterval
        Promise: Promise
        Buffer: Buffer
        process: process
        Math: Math
        Date: Date
        Array: Array
        Object: Object
        String: String
        Number: Number
        Boolean: Boolean
        RegExp: RegExp
        Error: Error
        JSON: JSON

      # Run the test file
      vm.runInNewContext compiled, context,
        filename: file
        timeout: 30000  # 30 second timeout for entire file

    catch err
      failed++
      failures.push {currentFile: file, error: err, type: 'file-error'}
      console.log "#{red}  ✗ Failed to run test file#{reset}"
      console.log "#{red}    #{err.message}#{reset}"

# Parse command line arguments
testPaths = process.argv[2..]
testPaths = ['.'] if testPaths.length is 0

# Collect and run tests
testFiles = collectTestFiles testPaths

if testFiles.length is 0
  console.error "#{red}No test files found#{reset}"
  process.exit 1

startTime = Date.now()
runTests testFiles

# Wait a bit for any async tests to complete
setTimeout ->
  duration = ((Date.now() - startTime) / 1000).toFixed(2)

  console.log "\n#{bold}─────────────────────────────────────#{reset}"

  if failed is 0
    console.log "#{green}#{bold}All tests passed!#{reset}"
    console.log "#{green}✓ #{passed} passing (#{duration}s)#{reset}"
  else
    console.log "#{red}#{bold}Test failures detected${reset}"
    console.log "#{green}✓ #{passed} passing#{reset}"
    console.log "#{red}✗ #{failed} failing#{reset}"
    console.log "#{yellow}Duration: #{duration}s#{reset}"

    if failures.length > 0 and process.env.VERBOSE
      console.log "\n#{bold}Failure Details:#{reset}"
      for failure in failures
        console.log "#{red}  #{failure.currentFile}: #{failure.description or 'File error'}#{reset}"

  process.exit(if failed > 0 then 1 else 0)
, 100  # Small delay to allow async tests to complete
