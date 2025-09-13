# CS3 Compiler Integration
# This module connects the CS3 parser with the ES5 backend

# Import dependencies
{Lexer} = require './lexer'
parser = require './parser-cs3'  # Use CS3 parser
ES5Backend = require '../../backends/es5/index'

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
  tokens = lexer.tokenize code

  # Setup parser with the lexer tokens
  parser.lexer =
    lex: ->
      token = tokens.shift()
      return 1 unless token  # EOF

      # Preserve token properties (CS3 needs this for things like 'not in')
      # token[1] might be a wrapped String object with properties
      @yytext = token[1]
      @yylloc = token[2] or {}

      # Return the token type ID
      parser.symbols_[token[0]] or token[0]

    setInput: ->
      # Reset function

  # Parse and return the AST
  parser.parse()

# Browser support
if typeof window isnt 'undefined'
  window.CoffeeScriptCS3 =
    compile: exports.compileCS3
