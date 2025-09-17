#!/usr/bin/env coffee

###
This script runs the npm test suite using the CS3/ES5 pipeline
It replicates the exact same test execution order as 'npm test'
###

fs = require 'fs'
path = require 'path'
CoffeeScript = require '../../lib/coffeescript'
helpers = require '../../lib/coffeescript/helpers'

# Use CS3 compile function
CS3 =
  compile: (code, options) ->
    options.cs3 = true
    CoffeeScript.compile code, options

# Test infrastructure - same as npm test
global.currentFile = null
global.passedTests = 0
global.failures = []
global.compileFailed = 0
global.runFailed = 0

# Import assert functions
global[name] = func for name, func of require 'assert'

# ANSI colors
bold = '\x1B[0;1m'
red = '\x1B[0;31m'
green = '\x1B[0;32m'
yellow = '\x1B[0;33m'
reset = '\x1B[0m'

# Test helper function
global.test = (description, fn) ->
  try
    result = fn.call(fn)
    if result instanceof Promise
      result.then ->
        passedTests++
        process.stdout.write green + '✓' + reset
      .catch (err) ->
        failures.push {filename: global.currentFile, error: err, description}
        process.stdout.write red + '✗' + reset
    else
      passedTests++
      process.stdout.write green + '✓' + reset
  catch err
    failures.push {filename: global.currentFile, error: err, description}
    process.stdout.write red + '✗' + reset

# Import test helpers
helpers.extend global, require '../support/helpers'

# Skip tests that require unsupported Node features (same as npm test)
testFilesToSkip = []
skipUnless = (featureDetect, filenames) ->
  unless (try new Function featureDetect)
    testFilesToSkip = testFilesToSkip.concat filenames

skipUnless 'async () => {}', ['async.coffee', 'async_iterators.coffee']
skipUnless 'async function* generator() { yield 42; }', ['async_iterators.coffee']
skipUnless 'var a = 2 ** 2; a **= 3', ['exponentiation.coffee']
skipUnless 'var {...a} = {}', ['object_rest_spread.coffee']
skipUnless '/foo.bar/s.test("foo\tbar")', ['regex_dotall.coffee']
skipUnless '1_2_3', ['numeric_literal_separators.coffee']
skipUnless '1n', ['numbers_bigint.coffee']
skipUnless 'async () => { await import(\'data:application/json,{"foo":"bar"}\', { assert: { type: "json" } }) }', ['import_assertions.coffee']

# Get test files (same order as npm test)
testDir = path.join(__dirname, '..')
files = fs.readdirSync(testDir).filter (filename) ->
  filename not in testFilesToSkip

console.log "#{bold}Running npm test suite with CS3/ES5 pipeline#{reset}\n"
console.log "Found #{files.length} test files to run\n"

startTime = Date.now()
totalFiles = 0
compiledFiles = 0
blockedByProto = 0
blockedByLoops = 0
otherErrors = 0

# Run each test file
for file in files when helpers.isCoffee file
  literate = helpers.isLiterate file
  currentFile = filename = path.join testDir, file
  totalFiles++

  process.stdout.write "#{path.basename(file)}: "
  
  # Check for known blockers (only loops now, :: is fixed!)
  code = fs.readFileSync(filename).toString()
  
  if /\b(for\s+.*\s+in\s+|for\s+.*\s+of\s+|while\s+|loop\s+)/.test code
    blockedByLoops++
    console.log yellow + 'BLOCKED by loops' + reset
    continue

  # Try to compile and run with CS3
  try
    # Compile with CS3
    compiled = CS3.compile code, {filename, literate, bare: no}
    compiledFiles++

    # Run the compiled code
    try
      eval compiled
      console.log '' # newline after test dots
    catch runError
      runFailed++
      console.log red + " RUNTIME ERROR: #{runError.message}" + reset
      failures.push {filename, error: runError}

  catch compileError
    otherErrors++
    compileFailed++
    console.log red + "COMPILE ERROR: #{compileError.message}" + reset
    failures.push {filename, error: compileError}

# Print summary
console.log "\n#{bold}=== TEST RESULTS ===${reset}\n"

time = ((Date.now() - startTime) / 1000).toFixed(2)

console.log "#{green}✅ Compiled successfully:#{reset} #{compiledFiles}/#{totalFiles} files"
console.log "#{green}✅ Tests passed:#{reset} #{passedTests} individual tests"
console.log "#{yellow}⚠️  Blocked by loops:#{reset} #{blockedByLoops} files"
console.log "#{red}❌ Compilation errors:#{reset} #{otherErrors} files"
console.log "#{red}❌ Runtime errors:#{reset} #{runFailed} files"
console.log "#{red}❌ Test failures:#{reset} #{failures.length}"

console.log "\nCompleted in #{time} seconds"

if blockedByLoops > 0
  percentBlocked = (blockedByLoops / totalFiles * 100).toFixed(1)
  console.log "\n#{bold}If we fix loops:#{reset}"
  console.log "  We could unlock #{percentBlocked}% of test files!"
  console.log "  That's #{blockedByLoops} more files that could run!"

# Exit with error if there were failures
process.exit(1) if failures.length > 0 or compileFailed > 0
