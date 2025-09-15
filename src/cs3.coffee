# CS3 Compiler Integration
# This module connects the CS3 parser with the ES5 backend

# Import dependencies
{Lexer} = require './lexer'
parser = require './parser-cs3'  # Use CS3 parser
ES5Backend = require '../backends/es5/index'  # ES5 backend in lib/backends/es5/

# Main compile function
exports.compileCS3 = (code, options = {}) ->
  # Step 1: Tokenize using CoffeeScript's lexer
  lexer = new Lexer()
  tokens = lexer.tokenize code, options

  # Step 2: Set up parser with proper lexer interface
  tokenIndex = 0

  # Create a lexer interface for the parser
  lexerInterface =
    lex: ->
      return 1 if tokenIndex >= tokens.length  # EOF symbol

      token = tokens[tokenIndex++]

      # Handle token value - may be a string, object, or String object
      tokenValue = token[1]
      if typeof tokenValue is 'object' and tokenValue?
        # Check if it's a String object (has valueOf or toString)
        if tokenValue.constructor is String or tokenValue.valueOf
          # It's a String object with properties
          # CS3 parser expects the String object itself with all properties
          @yytext = tokenValue
        else
          # Regular object
          @yytext = tokenValue
      else
        # Simple string or primitive
        @yytext = tokenValue

      @yylloc = token[2]
      @yylineno = if token[2] then token[2].first_line else 0
      @yyleng = String(@yytext).length

      # Look up token ID in parser's symbol table
      tokenType = token[0]
      tokenId = parser.parser.symbolIds[tokenType]

      # If not found, try as a literal token
      if tokenId is undefined
        # For literal tokens like '=', '+', etc.
        tokenId = parser.parser.symbolIds[token[1]]

      # Still not found? Use the error token
      if tokenId is undefined
        console.error 'Unknown token:', tokenType, token[1]
        tokenId = 2  # error token

      tokenId

    setInput: ->
      tokenIndex = 0

    upcomingInput: ->
      ""

  # Step 3: Parse to CS3 AST
  parser.parser.lexer = lexerInterface
  parser.parser.yy = {}  # CS3 doesn't need yy helpers

  try
    ast = parser.parse()
  catch error
    # Enhance error message
    if error.message and error.message.indexOf('Object prototype') isnt -1
      throw new Error 'Parser initialization error - ensure CS3 parser is properly generated'
    throw error

  # Step 4: Generate JavaScript using ES5 backend
  backend = new ES5Backend(options)
  jsCode = backend.generate ast

  jsCode

# Export a parse-only function for debugging
exports.parseCS3 = (code) ->
  lexer = new Lexer()
  tokens = lexer.tokenize code, {}

  # Create lexer interface like in compileCS3
  tokenIndex = 0
  lexerInterface =
    lex: ->
      return 1 if tokenIndex >= tokens.length  # EOF symbol

      token = tokens[tokenIndex++]

      # Handle token value
      tokenValue = token[1]
      if typeof tokenValue is 'object' and tokenValue?
        @yytext = tokenValue
      else
        @yytext = tokenValue

      @yylloc = token[2]
      @yylineno = if token[2] then token[2].first_line else 0
      @yyleng = String(@yytext).length

      # Look up token ID in parser's symbol table
      tokenType = token[0]
      tokenId = parser.parser.symbolIds[tokenType]

      # If not found, try as a literal token
      if tokenId is undefined
        tokenId = parser.parser.symbolIds[token[1]]

      # Still not found? Use the error token
      if tokenId is undefined
        console.error 'Unknown token:', tokenType, token[1]
        tokenId = 2  # error token

      tokenId

    setInput: ->
      tokenIndex = 0

    upcomingInput: ->
      ""

  # Set up parser
  parser.parser.lexer = lexerInterface
  parser.parser.yy = {}

  # Parse and return the AST
  parser.parse()

# CoffeeScript-Compatible API for testing
# (Enables running test suite with 'cake test:cs3')

# Standard compile method (alias for compileCS3)
exports.compile = exports.compileCS3

# Execute compiled CS3 code
exports.run = (code, options = {}) ->
  # Use Node.js require system for execution
  vm = require 'vm'
  fs = require 'fs'
  path = require 'path'
  mainModule = require.main

  # Set up execution context like traditional CoffeeScript.run
  mainModule.filename = process.argv[1] =
    if options.filename then fs.realpathSync(options.filename) else 'repl'

  mainModule.moduleCache and= {}

  dir = if options.filename?
    path.dirname fs.realpathSync options.filename
  else
    fs.realpathSync '.'
  mainModule.paths = require('module')._nodeModulePaths dir

  mainModule.options = options
  options.filename = mainModule.filename
  options.inlineMap = true

  # Compile with CS3 pipeline
  try
    compiledJS = exports.compileCS3 code, options

    # Execute the compiled JavaScript
    mainModule._compile compiledJS, mainModule.filename
  catch error
    throw error

# Register CS3 for .coffee file extensions
exports.register = ->
  # Register CS3 compile handler for .coffee files
  require.extensions['.coffee'] = (module, filename) ->
    raw = require('fs').readFileSync filename, 'utf8'
    # Strip BOM if present
    stripped = if raw.charCodeAt(0) is 0xFEFF then raw.substring 1 else raw

    try
      compiled = exports.compileCS3 stripped, {filename}
      module._compile compiled, filename
    catch error
      # Add filename info to error for better debugging
      error.filename = filename
      throw error

  # Also register literate extensions
  require.extensions['.litcoffee'] = require.extensions['.coffee.md'] = require.extensions['.coffee']

# Version compatibility
packageJson = require '../../package.json'
exports.VERSION = packageJson.version

# Browser support
if typeof window isnt 'undefined'
  window.CoffeeScriptCS3 =
    compile: exports.compileCS3
    run: exports.run