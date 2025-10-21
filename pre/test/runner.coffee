#!/usr/bin/env coffee

# Test runner for CoffeeScript 2 test suite
# Usage: coffee runner.coffee [file|directory ...]
# If no arguments provided, runs all tests in current directory

fs              = require 'fs'
path            = require 'path'
CoffeeScript    = require '../lib/coffeescript'
helpers         = require '../lib/coffeescript/helpers'
{Repl}          = require '../lib/coffeescript/repl'

# ANSI Terminal Colors
bold = red = green = yellow = reset = ''
unless process.env.NODE_DISABLE_COLORS
  bold   = '\x1B[0;1m'
  red    = '\x1B[0;31m'
  green  = '\x1B[0;32m'
  yellow = '\x1B[0;33m'
  reset  = '\x1B[0m'

# Parse command line arguments
testPaths = process.argv[2..]
testPaths = ['.'] if testPaths.length is 0  # Default to current directory

# Recursively find all coffee files in a directory
findCoffeeFiles = (dir) ->
  results = []
  try
    files = fs.readdirSync dir
  catch error
    return results  # Directory doesn't exist or can't be read

  for file in files
    filePath = path.join dir, file
    try
      stat = fs.statSync filePath
      if stat.isDirectory()
        results = results.concat findCoffeeFiles(filePath)
      else if helpers.isCoffee(file)
        results.push filePath
    catch error
      # Skip files we can't stat
  results

# Collect all test files to run
testFiles = []
for testPath in testPaths
  try
    stat = fs.statSync testPath
    if stat.isDirectory()
      testFiles = testFiles.concat findCoffeeFiles(testPath)
    else if stat.isFile() and helpers.isCoffee(testPath)
      testFiles.push testPath
  catch error
    console.error "#{red}Cannot access: #{testPath}#{reset}"

if testFiles.length is 0
  console.error "#{red}No test files found#{reset}"
  process.exit 1

# Remove duplicates and sort
testFiles = Array.from(new Set(testFiles)).sort()

# Initialize test environment
runTests = ->
  CoffeeScript.register()

  # These are attached to `global` so that they're accessible from within
  # test files
  global.currentFile = null
  global.passedTests = 0
  global.failures    = []

  # Import all assert functions as globals
  global[name] = func for name, func of require 'assert'

  # Convenience aliases
  global.CoffeeScript = CoffeeScript
  global.Repl   = Repl
  global.bold   = bold
  global.red    = red
  global.green  = green
  global.yellow = yellow
  global.reset  = reset

  # Helper to require modules from the project root
  # This allows tests to work regardless of their directory depth
  global.requireRoot = (modulePath) ->
    require path.resolve(__dirname, '..', modulePath)

  asyncTests = []
  onFail = (description, fn, err) ->
    failures.push
      filename: global.currentFile
      error: err
      description: description
      source: fn.toString() if fn.toString?

  # Our test helper function for delimiting different test cases
  global.test = (description, fn) ->
    try
      fn.test = {description, currentFile}
      result = fn.call(fn)
      if result instanceof Promise # An async test
        asyncTests.push result
        result.then ->
          passedTests++
        .catch (err) ->
          onFail description, fn, err
      else
        passedTests++
    catch err
      onFail description, fn, err

  # Test helper functions (originally from test/support/helpers.coffee)
  # See [http://wiki.ecmascript.org/doku.php?id=harmony:egal](http://wiki.ecmascript.org/doku.php?id=harmony:egal).
  egal = (a, b) ->
    if a is b
      a isnt 0 or 1/a is 1/b
    else
      a isnt a and b isnt b

  # A recursive functional equivalence helper; uses egal for testing equivalence.
  arrayEgal = (a, b) ->
    if egal a, b then yes
    else if a instanceof Array and b instanceof Array
      return no unless a.length is b.length
      return no for el, idx in a when not arrayEgal el, b[idx]
      yes

  diffOutput = (expectedOutput, actualOutput) ->
    expectedOutputLines = expectedOutput.split '\n'
    actualOutputLines = actualOutput.split '\n'
    for line, i in actualOutputLines
      if line isnt expectedOutputLines[i]
        actualOutputLines[i] = "#{yellow}#{line}#{reset}"
    """Expected generated JavaScript to be:
    #{reset}#{expectedOutput}#{red}
      but instead it was:
    #{reset}#{actualOutputLines.join '\n'}#{red}"""

  global.eq = (a, b, msg) ->
    ok egal(a, b), msg or
    "Expected #{reset}#{a}#{red} to equal #{reset}#{b}#{red}"

  global.arrayEq = (a, b, msg) ->
    ok arrayEgal(a, b), msg or
    "Expected #{reset}#{a}#{red} to deep equal #{reset}#{b}#{red}"

  global.eqJS = (input, expectedOutput, msg) ->
    actualOutput = CoffeeScript.compile input, bare: yes
    .replace /^\s+|\s+$/g, '' # Trim leading/trailing whitespace.
    ok egal(expectedOutput, actualOutput), msg or diffOutput expectedOutput, actualOutput

  global.isWindows = -> process.platform is 'win32'

  global.inspect = (obj) ->
    if global.testingBrowser
      JSON.stringify obj, null, 2
    else
      require('util').inspect obj,
        depth: 10
        colors: if process.env.NODE_DISABLE_COLORS then no else yes

  # Helpers to get AST nodes for a string of code.
  global.getAstRoot = getAstRoot = (code) ->
    CoffeeScript.compile code, ast: yes

  # The root node is always a `File` node, so for brevity in the tests return its
  # children from `program.body`.
  getAstExpressions = (code) ->
    ast = getAstRoot code
    ast.program.body

  # Many tests want just the root node.
  global.getAstExpression = (code) ->
    expressionStatementAst = getAstExpressions(code)[0]
    ok expressionStatementAst.type is 'ExpressionStatement', 'Expected ExpressionStatement AST wrapper'
    expressionStatementAst.expression

  global.getAstStatement = (code) ->
    statement = getAstExpressions(code)[0]
    ok statement.type isnt 'ExpressionStatement', "Didn't expect ExpressionStatement AST wrapper"
    statement

  global.getAstExpressionOrStatement = (code) ->
    expressionAst = getAstExpressions(code)[0]
    return expressionAst unless expressionAst.type is 'ExpressionStatement'
    expressionAst.expression

  global.throwsCompileError = (code, compileOpts, args...) ->
    throws -> CoffeeScript.compile code, compileOpts, args...
    throws -> CoffeeScript.compile code, Object.assign({}, (compileOpts ? {}), ast: yes), args...

  global.doesNotThrowCompileError = (code, compileOpts, args...) ->
    doesNotThrow -> CoffeeScript.compile code, compileOpts, args...
    doesNotThrow -> CoffeeScript.compile code, Object.assign({}, (compileOpts ? {}), ast: yes), args...

  # When all tests have run, collect and print errors
  process.on 'exit', ->
    time = ((Date.now() - startTime) / 1000).toFixed(2)
    message = "passed #{passedTests} tests in #{time} seconds#{reset}"
    return log(message, green) unless failures.length
    log "failed #{failures.length} and #{message}", red

    # Group failures by file for better organization
    failuresByFile = {}
    for fail in failures
      {error, filename, description} = fail
      filename = filename or global.currentFile or 'unknown'
      failuresByFile[filename] ?= []
      failuresByFile[filename].push {error, description}

    # Display failures in a concise format
    for filename, fails of failuresByFile
      console.log ''
      log "  #{filename}:", yellow
      for fail in fails
        {error, description} = fail
        if description  # This is a test failure
          log "    ✗ #{description}", red
          errorMessage = error.message or error.toString()
          # Clean up assertion messages to be more readable
          if errorMessage.includes('[ERR_ASSERTION]')
            errorMessage = errorMessage.replace(/^AssertionError \[ERR_ASSERTION\]( \[ERR_ASSERTION\])?: /, '')
          log "      #{errorMessage}", red
          # Show full stack trace in verbose mode
          if process.env.VERBOSE
            stackLines = error.stack.split('\n')[1..]  # Skip first line (error message)
            for line in stackLines[0..4]  # Show first 5 stack frames
              log "      #{line}", red if line
        else  # This is a file-level failure
          log "    ✗ Failed to load file", red
          log "      #{error.message or error.toString()}", red
          # Show stack trace for load failures in verbose mode
          if process.env.VERBOSE and error.stack
            stackLines = error.stack.split('\n')[1..2]  # Just show top 2 frames
            for line in stackLines
              log "      #{line}", red if line

    # Show hint about verbose mode
    unless process.env.VERBOSE
      console.log ''
      log "  Tip: Run with VERBOSE=1 to see full stack traces", yellow
    return

  # Feature detection for skipping unsupported tests
  testFilesToSkip = []
  skipUnless = (featureDetect, filenames) ->
    unless (try new Function featureDetect)
      for filename in filenames
        testFilesToSkip.push filename

  skipUnless 'async () => {}', ['async.coffee', 'async_iterators.coffee']
  skipUnless 'async function* generator() { yield 42; }', ['async_iterators.coffee']
  skipUnless 'var a = 2 ** 2; a **= 3', ['exponentiation.coffee']
  skipUnless 'var {...a} = {}', ['object_rest_spread.coffee']
  skipUnless '/foo.bar/s.test("foo\tbar")', ['regex_dotall.coffee']
  skipUnless '1_2_3', ['numeric_literal_separators.coffee']
  skipUnless '1n', ['numbers_bigint.coffee']
  skipUnless 'async () => { await import(\'data:application/json,{"foo":"bar"}\', { assert: { type: "json" } }) }', ['import_assertions.coffee']

  # Run the test files
  startTime = Date.now()
  for file in testFiles
    basename = path.basename(file)

    # Skip files that require unsupported features
    continue if basename in testFilesToSkip

    literate = helpers.isLiterate file
    currentFile = global.currentFile = file  # Update both local and global

    console.log "#{bold}Running: #{file}#{reset}"

    code = fs.readFileSync file
    try
      CoffeeScript.run code.toString(), {filename: file, literate}
    catch error
      failures.push {filename: file, error}

  # Wait for async tests to complete
  Promise.all(asyncTests).then ->
    Promise.reject() if failures.length isnt 0

# Helper function to log with color
log = (message, color, explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

# Run the tests
console.log "#{bold}Running #{testFiles.length} test file(s)#{reset}\n"
runTests().catch -> process.exit 1
