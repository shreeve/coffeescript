# CS3 Compiler Integration
# This module connects the CS3 parser with the ES5 backend

# Import dependencies
if typeof require isnt 'undefined'
  {Lexer} = require './lexer'
  parser = require './parser-cs3'  # Use CS3 parser
  ES5Backend = require '../../backends/es5/index'

# Main compile function
compileCS3 = (code, options = {}) ->
  # Step 1: Tokenize using CoffeeScript's lexer
  lexer = new Lexer()
  tokens = lexer.tokenize code, options

  # Step 2: Set up parser with proper lexer interface
  tokenIndex = 0

  # Create a lexer interface for the parser
  lexerInterface =
    lex: ->
      if tokenIndex >= tokens.length
        return 1  # EOF symbol

      token = tokens[tokenIndex++]
      @yytext = token[0]
      @yylloc = token[2] if token[2]

      # Map CoffeeScript token types to parser symbols
      tokenType = token[0]

      # Return the token type for the parser
      return tokenType

    setInput: (input) ->
      # Not used in our implementation
      return

  # Step 3: Parse tokens into CS3 data AST
  parser.lexer = lexerInterface
  try
    dataAST = parser.parse()
  catch error
    throw new Error "CS3 Parser error: #{error.message}"

  # Step 4: Convert CS3 data AST to JavaScript using ES5 backend
  backend = new ES5Backend(options)
  javascript = backend.generate dataAST

  return javascript

# Parse function for getting raw CS3 AST
parseCS3 = (code, options = {}) ->
  lexer = new Lexer()
  tokens = lexer.tokenize code, options

  tokenIndex = 0
  lexerInterface =
    lex: ->
      if tokenIndex >= tokens.length
        return 1
      token = tokens[tokenIndex++]
      @yytext = token[0]
      @yylloc = token[2] if token[2]
      return token[0]
    setInput: -> return

  parser.lexer = lexerInterface
  parser.parse()

# Export functions
exports.compileCS3 = compileCS3
exports.parseCS3 = parseCS3
