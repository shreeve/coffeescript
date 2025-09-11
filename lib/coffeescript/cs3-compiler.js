// CS3 Compiler Integration
// This module connects the CS3 parser with the ES5 backend

(function() {
  var ES5Backend, Lexer, parser;

  // Import dependencies
  if (typeof require !== 'undefined') {
    Lexer = require('./lexer').Lexer;
    parser = require('./parser-cs3');  // Use CS3 parser
    ES5Backend = require('../../backends/es5/index.js');
  }

  // Main compile function
  function compileCS3(code, options) {
    options = options || {};

    // Step 1: Tokenize using CoffeeScript's lexer
    var lexer = new Lexer();
    var tokens = lexer.tokenize(code, options);

    // Step 2: Set up parser with proper lexer interface
    var tokenIndex = 0;

    // Create a lexer interface for the parser
    var lexerInterface = {
      lex: function() {
        if (tokenIndex >= tokens.length) {
          return 1; // EOF symbol
        }

        var token = tokens[tokenIndex++];

        // Handle token value - may be a string, object, or String object
        var tokenValue = token[1];
        if (typeof tokenValue === 'object' && tokenValue != null) {
          // Check if it's a String object (has valueOf or toString)
          if (tokenValue.constructor === String || tokenValue.valueOf) {
            // It's a String object with properties
            this.yytext = tokenValue.valueOf ? tokenValue.valueOf() : tokenValue.toString();
            // Copy properties from the String object
            for (var prop in tokenValue) {
              if (tokenValue.hasOwnProperty(prop)) {
                this[prop] = tokenValue[prop];
              }
            }
          } else {
            // Regular object
            this.yytext = tokenValue;
          }
        } else {
          // Simple string or primitive
          this.yytext = tokenValue;
        }

        this.yylloc = token[2];
        this.yylineno = token[2] ? token[2].first_line : 0;
        this.yyleng = String(this.yytext).length;

        // Look up token ID in parser's symbol table
        var tokenType = token[0];
        var tokenId = parser.parser.symbolIds[tokenType];

        // If not found, try as a literal token
        if (tokenId === undefined) {
          // For literal tokens like '=', '+', etc.
          tokenId = parser.parser.symbolIds[token[1]];
        }

        // Still not found? Use the error token
        if (tokenId === undefined) {
          console.error('Unknown token:', tokenType, token[1]);
          tokenId = 2; // error token
        }

        return tokenId;
      },

      setInput: function() {
        tokenIndex = 0;
      },

      upcomingInput: function() {
        return "";
      }
    };

    // Step 3: Parse to CS3 AST
    parser.parser.lexer = lexerInterface;
    parser.parser.yy = {}; // CS3 doesn't need yy helpers

    var ast;
    try {
      ast = parser.parse();
    } catch (error) {
      // Enhance error message
      if (error.message && error.message.indexOf('Object prototype') !== -1) {
        throw new Error('Parser initialization error - ensure CS3 parser is properly generated');
      }
      throw error;
    }

    // Step 4: Generate JavaScript using ES5 backend
    var backend = new ES5Backend(options);
    var jsCode = backend.generate(ast);

    return jsCode;
  }

  // Export the compile function
  if (typeof exports !== 'undefined') {
    exports.compileCS3 = compileCS3;
  }

  // Also make it available globally in browser
  if (typeof window !== 'undefined') {
    window.CoffeeScriptCS3 = {
      compile: compileCS3
    };
  }

})();
