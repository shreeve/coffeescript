# ==============================================================================
# CS3 Syntax - Data-Oriented Grammar for CoffeeScript 3
#
# Automatically generated from grammar.coffee
# 
# KEY CHANGES:
# - Actions are pure data objects, NOT functions
# - Uses CS3 directives: $ast, $ref, $obj, $seq, $ops, $ary, $ite
# - Export key is 'grammar' not 'bnf' to signal data-oriented format
#
# EXAMPLES:
#   Old: o 'Body', -> new Root $1
#   New: o 'Body', $ast: 'Root', body: $ref: 1
# ==============================================================================

# The CoffeeScript parser is generated from this grammar file using a
# bottom-up parser generator. CoffeeScript has a powerful and expressive grammar
# that requires the flexibility of an [SLR(1)](https://en.wikipedia.org/wiki/LR_grammar)
# parser. While LALR(1) parsers are more common, they are too restrictive to
# easily express CoffeeScript's rich syntax, particularly its context-sensitive
# features and flexible statement boundaries. The parser generator creates an
# SLR parser that can handle this grammar effectively. To create the parser, we
# list the pattern to match on the left-hand side, and the action to take
# (usually the creation of syntax tree nodes) on the right. As the parser runs, it
# shifts tokens from our token stream, from left to right, and
# [attempts to match](https://en.wikipedia.org/wiki/Bottom-up_parsing)
# the token sequence against the rules below. When a match can be made, it
# reduces into the [nonterminal](https://en.wikipedia.org/wiki/Terminal_and_nonterminal_symbols)
# (the enclosing name at the top), and we proceed from there.
#
# If you run the `cake build:parser` command, the parser generator constructs a parse table
# from our rules and saves it into `lib/parser.js`.

# Since we're going to be wrapped in a parser function in any case, if our
# action immediately returns a value, we can optimize by removing the function
# wrapper and just returning the value directly.

# Our handy DSL for grammar generation, thanks to
# [Tim Caswell](https://github.com/creationix). For every rule in the grammar,
# we pass the pattern-defining string, the action to run, and extra options,
# optionally. If no action is specified, we simply pass the value of the
# previous nonterminal.
# CS3: The 'o' function now handles pure data actions
o = (patternString, action, options) ->
  patternString = patternString.replace /\s{2,}/g, ' '
  # Action is now a data object, not a function
  [patternString, action, options]
  patternString = patternString.replace /\s{2,}/g, ' '
  patternCount = patternString.split(' ').length
  if action
    # This code block does string replacements in the generated `parser.js`
    # file, replacing the calls to the `LOC` function and other strings as
    # listed below.
    action = if match = unwrap.exec action then match[1] else "(#{action}())"

    # All runtime functions we need are defined on `yy`
    action = action.replace /\bnew /g, '$&yy.'
    action = action.replace /\b(?:Block\.wrap|extend)\b/g, 'yy.$&'

    # Returns strings of functions to add to `parser.js` which add extra data
    # that nodes may have, such as comments or location data. Location data
    # is added to the first parameter passed in, and the parameter is returned.
    # If the parameter is not a node, it will just be passed through unaffected.
    getAddDataToNodeFunctionString = (first, last, forceUpdateLocation = yes) ->
      "yy.addDataToNode(yy, @#{first}, #{if first[0] is '$' then '$$' else '$'}#{first}, #{if last then "@#{last}, #{if last[0] is '$' then '$$' else '$'}#{last}" else 'null, null'}, #{if forceUpdateLocation then 'true' else 'false'})"

    # This code replaces the calls to `LOC` with the `yy.addDataToNode` string
    # defined above. The `LOC` function, when used below in the grammar rules,
    # is used to make sure that newly created node class objects get correct
    # location data assigned to them. By default, the grammar will assign the
    # location data spanned by *all* of the tokens on the left (e.g. a string
    # such as `'Body TERMINATOR Line'`) to the “top-level” node returned by
    # the grammar rule (the function on the right). But for “inner” node class
    # objects created by grammar rules, they won’t get correct location data
    # assigned to them without adding `LOC`.

    # For example, consider the grammar rule `'NEW_TARGET . Property'`, which
    # is handled by a function that returns
    # `new MetaProperty LOC(1)(new IdentifierLiteral $1), LOC(3)(new Access $3)`.
    # The `1` in `LOC(1)` refers to the first token (`NEW_TARGET`) and the `3`
    # in `LOC(3)` refers to the third token (`Property`). In order for the
    # `new IdentifierLiteral` to get assigned the location data corresponding
    # to `new` in the source code, we use
    # `LOC(1)(new IdentifierLiteral ...)` to mean “assign the location data of
    # the *first* token of this grammar rule (`NEW_TARGET`) to this
    # `new IdentifierLiteral`”. The `LOC(3)` means “assign the location data of
    # the *third* token of this grammar rule (`Property`) to this
    # `new Access`”.
    returnsLoc = /^LOC/.test action
    action = action.replace /LOC\(([0-9]*)\)/g, getAddDataToNodeFunctionString('$1')
    # A call to `LOC` with two arguments, e.g. `LOC(2,4)`, sets the location
    # data for the generated node on both of the referenced tokens  (the second
    # and fourth in this example).
    action = action.replace /LOC\(([0-9]*),\s*([0-9]*)\)/g, getAddDataToNodeFunctionString('$1', '$2')
    performActionFunctionString = "$$ = #{getAddDataToNodeFunctionString(1, patternCount, not returnsLoc)}(#{action});"
  else
    performActionFunctionString = '$$ = $1;'

  [patternString, performActionFunctionString, options]

# Grammatical Rules
# -----------------

# In all of the rules that follow, you'll see the name of the nonterminal as
# the key to a list of alternative matches. With each match's action, the
# dollar-sign variables are provided by the parser as references to the value of
# their numeric position, so in this rule:
#
#     'Expression UNLESS Expression'
#
# `$1` would be the value of the first `Expression`, `$2` would be the token
# for the `UNLESS` terminal, and `$3` would be the value of the second
# `Expression`.

# CS3 Grammar Rules
grammar =

  # The **Root** is the top-level node in the syntax tree. Since we parse bottom-up,
  # all parsing must end here.
  Root: [
    o '',                                       -> new Root new Block
    o 'Body', $ast: '@', base: $ref: 1
  ]

  # Any list of statements and expressions, separated by line breaks or semicolons.
  Body: [
    o 'Line'                , $ops: 'Block.wrap', args: [{$ref: 1}]
    o 'Body TERMINATOR Line', $ops: 'push', target: {$ref: 1}, args: [{$ref: 3}]
    o 'Body TERMINATOR'
  ]

  # Block and statements, which make up a line in a body. FuncDirective is a
  # statement, but not included in Statement because that results in an ambiguous
  # grammar.
  Line: [
    o 'Expression'
    o 'ExpressionLine'
    o 'Statement'
    o 'FuncDirective'
  ]

  FuncDirective: [
    o 'YieldReturn'
    o 'AwaitReturn'
  ]

  # Pure statements which cannot be expressions.
  Statement: [
    o 'Return'
    o 'STATEMENT', $ast: 'StatementLiteral', base: $ref: 1
    o 'Import'
    o 'Export'
  ]

  # All the different types of expressions in our language. The basic unit of
  # CoffeeScript is the **Expression** -- everything that can be an expression
  # is one. Blocks serve as the building blocks of many other rules, making
  # them somewhat circular.
  Expression: [
    o 'Value'
    o 'Code'
    o 'Operation'
    o 'Assign'
    o 'If'
    o 'Try'
    o 'While'
    o 'For'
    o 'Switch'
    o 'Class'
    o 'Throw'
    o 'Yield'
  ]

  # Expressions which are written in single line and would otherwise require being
  # wrapped in braces: E.g `a = b if do -> f a is 1`, `if f (a) -> a*2 then ...`,
  # `for x in do (obj) -> f obj when x > 8 then f x`
  ExpressionLine: [
    o 'CodeLine'
    o 'IfLine'
    o 'OperationLine'
  ]

  Yield: [
    o 'YIELD'                      , $ast: 'Op', arg1: {$ref: 1}, arg2: {$ast: 'Value'}
    o 'YIELD Expression'           , $ast: 'Op', first: $ref: 1, second: $ref: 2
    o 'YIELD INDENT Object OUTDENT', $ast: 'Op', first: $ref: 1, second: $ref: 3
    o 'YIELD FROM Expression'      , $ast: 'Op', arg1: '$1.concat($2)', arg2: {$ref: 3}
  ]

  # An indented block of expressions. Note that the [Rewriter](rewriter.html)
  # will convert some postfix forms into blocks for us, by adjusting the
  # token stream.
  Block: [
    o 'INDENT OUTDENT'     , $ast: '@'
    o 'INDENT Body OUTDENT', $ref: 2
  ]

  Identifier: [
    o 'IDENTIFIER', $ast: 'IdentifierLiteral', base: $ref: 1
    o 'JSX_TAG'   , $ast: 'JSXTag', arg1: '$1.toString()', arg2: {}
                                                     tagNameLocationData:                  $1.tagNameToken[2]
                                                     closingTagOpeningBracketLocationData: $1.closingTagOpeningBracketToken?[2]
                                                     closingTagSlashLocationData:          $1.closingTagSlashToken?[2]
                                                     closingTagNameLocationData:           $1.closingTagNameToken?[2]
                                                     closingTagClosingBracketLocationData: $1.closingTagClosingBracketToken?[2]
  ]

  Property: [
    o 'PROPERTY', $ast: 'PropertyName', value: '$1.toString('
  ]

  # Alphanumerics are separated from the other **Literal** matchers because
  # they can also serve as keys in object literals.
  AlphaNumeric: [
    o 'NUMBER', $ast: 'NumberLiteral', arg1: '$1.toString()', arg2: 'parsedValue: $1.parsedValue'
    o 'String'
  ]

  String: [
    o 'STRING'                                , ->
      new StringLiteral(
        $1.slice 1, -1 # strip artificial quotes and unwrap to primitive string
        quote:        $1.quote
        initialChunk: $1.initialChunk
        finalChunk:   $1.finalChunk
        indent:       $1.indent
        double:       $1.double
        heregex:      $1.heregex
      )
    o 'STRING_START Interpolations STRING_END', $ast: 'StringWithInterpolations', arg1: 'Block.wrap($2)', arg2: 'quote: $1.quote', arg3: 'startQuote: (new Literal $1.toString()'
  ]

  Interpolations: [
    o 'InterpolationChunk'               , $ary: [$ref: 1]
    o 'Interpolations InterpolationChunk', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 2}]
  ]

  InterpolationChunk: [
    o 'INTERPOLATION_START Body INTERPOLATION_END'               , $ast: 'Interpolation', base: $ref: 2
    o 'INTERPOLATION_START INDENT Body OUTDENT INTERPOLATION_END', $ast: 'Interpolation', base: $ref: 3
    o 'INTERPOLATION_START INTERPOLATION_END'                    , $ast: 'Interpolation'
    o 'String'                                                   , $ref: 1
  ]

  # The .toString() calls here and elsewhere are to convert `String` objects
  # back to primitive strings now that we've retrieved stowaway extra properties
  Regex: [
    o 'REGEX'                           , $ast: 'RegexLiteral', arg1: '$1.toString()', arg2: 'delimiter: $1.delimiter', arg3: 'heregexCommentTokens: $1.heregexCommentTokens'
    o 'REGEX_START Invocation REGEX_END', $ast: 'RegexWithInterpolations', arg1: {$ref: 2}, arg2: 'heregexCommentTokens: $3.heregexCommentTokens'
  ]

  # All of our immediate values. Generally these can be passed straight
  # through and printed to JavaScript.
  Literal: [
    o 'AlphaNumeric'
    o 'JS'        , $ast: 'PassthroughLiteral', arg1: '$1.toString()', arg2: 'here: $1.here', arg3: 'generated: $1.generated'
    o 'Regex'
    o 'UNDEFINED' , $ast: 'UndefinedLiteral', base: $ref: 1
    o 'NULL'      , $ast: 'NullLiteral', base: $ref: 1
    o 'BOOL'      , $ast: 'BooleanLiteral', arg1: '$1.toString()', arg2: 'originalValue: $1.original'
    o 'INFINITY'  , $ast: 'InfinityLiteral', arg1: '$1.toString()', arg2: 'originalValue: $1.original'
    o 'NAN'       , $ast: 'NaNLiteral', base: $ref: 1
  ]

  # Assignment of a variable, property, or index to a value.
  Assign: [
    o 'Assignable = Expression'               , $ast: '@', first: $ref: 1, second: $ref: 3
    o 'Assignable = TERMINATOR Expression'    , $ast: '@', first: $ref: 1, second: $ref: 4
    o 'Assignable = INDENT Expression OUTDENT', $ast: '@', first: $ref: 1, second: $ref: 4
  ]

  # Assignment when it happens within an object literal. The difference from
  # the ordinary **Assign** is that these allow numbers and strings as keys.
  AssignObj: [
    o 'ObjAssignable'                   , $ast: 'Value', base: $ref: 1
    o 'ObjRestValue'
    o 'ObjAssignable : Expression'      , $ast: 'Assign', arg1: {$ast: 'Value'}, arg2: {$ref: 3}, arg3: 'object', arg4: {}
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'ObjAssignable :
       INDENT Expression OUTDENT',              -> new Assign LOC(1)(new Value $1), $4, 'object',
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'SimpleObjAssignable = Expression', $ast: 'Assign', arg1: {$ast: 'Value'}, arg2: {$ref: 3}, arg3: null, arg4: {}
                                                              operatorToken: LOC(2)(new Literal $2)
    o 'SimpleObjAssignable =
       INDENT Expression OUTDENT',              -> new Assign LOC(1)(new Value $1), $4, null,
                                                              operatorToken: LOC(2)(new Literal $2)
  ]

  SimpleObjAssignable: [
    o 'Identifier'
    o 'Property'
    o 'ThisProperty'
  ]

  ObjAssignable: [
    o 'SimpleObjAssignable'
    o '[ Expression ]'   , $ast: 'Value', value: {$ast: 'ComputedPropertyName'}
    o '@ [ Expression ]' , $ast: 'Value', arg1: {$ast: 'ThisLiteral'}, arg2: {$ary: ['(new ComputedPropertyName($3))']}, arg3: 'this'
    o 'AlphaNumeric'
  ]

  # Object literal spread properties.
  ObjRestValue: [
    o 'SimpleObjAssignable ...', $ast: 'Splat', value: {$ast: 'Value'}
    o '... SimpleObjAssignable', $ast: 'Splat', arg1: {$ast: 'Value'}, arg2: 'postfix: no'
    o 'ObjSpreadExpr ...'      , $ast: 'Splat', base: $ref: 1
    o '... ObjSpreadExpr'      , $ast: 'Splat', arg1: {$ref: 2}, arg2: 'postfix: no'
  ]

  ObjSpreadExpr: [
    o 'ObjSpreadIdentifier'
    o 'Object'
    o 'Parenthetical'
    o 'Super'
    o 'This'
    o 'SUPER OptFuncExist Arguments'              , $ast: 'SuperCall', arg1: {$ast: 'Super'}, arg2: {$ref: 3}, arg3: {$ref: 2, prop: 'soak'}, arg4: {$ref: 1}
    o 'DYNAMIC_IMPORT Arguments'                  , $ast: 'DynamicImportCall', arg1: {$ast: 'DynamicImport'}, arg2: {$ref: 2}
    o 'SimpleObjAssignable OptFuncExist Arguments', $ast: 'Call', arg1: {$ast: 'Value'}, arg2: {$ref: 3}, arg3: {$ref: 2, prop: 'soak'}
    o 'ObjSpreadExpr OptFuncExist Arguments'      , $ast: 'Call', arg1: {$ref: 1}, arg2: {$ref: 3}, arg3: {$ref: 2, prop: 'soak'}
  ]

  ObjSpreadIdentifier: [
    o 'SimpleObjAssignable Accessor', # TODO: Transform manually: (new Value $1).add $2
    o 'ObjSpreadExpr Accessor'      , # TODO: Transform manually: (new Value $1).add $2
  ]

  # A return statement from a function body.
  Return: [
    o 'RETURN Expression'           , $ast: '@', base: $ref: 2
    o 'RETURN INDENT Object OUTDENT', $ast: '@', value: {$ast: 'Value'}
    o 'RETURN'                      , $ast: '@'
  ]

  YieldReturn: [
    o 'YIELD RETURN Expression', $ast: '@', arg1: {$ref: 3}, arg2: 'returnKeyword: (new Literal $2'
    o 'YIELD RETURN'           , $ast: '@', arg1: null, arg2: 'returnKeyword: (new Literal $2'
  ]

  AwaitReturn: [
    o 'AWAIT RETURN Expression', $ast: '@', arg1: {$ref: 3}, arg2: 'returnKeyword: (new Literal $2'
    o 'AWAIT RETURN'           , $ast: '@', arg1: null, arg2: 'returnKeyword: (new Literal $2'
  ]

  # The **Code** node is the function literal. It’s defined by an indented block
  # of **Block** preceded by a function arrow, with an optional parameter list.
  Code: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Block', $ast: '@', arg1: {$ref: 2}, arg2: {$ref: 5}, arg3: {$ref: 4}, arg4: '(new Literal $1'
    o 'FuncGlyph Block'                                , $ast: '@', arg1: {$ary: [{}]}, arg2: {$ref: 2}, arg3: {$ref: 1}
  ]

  # The Codeline is the **Code** node with **Line** instead of indented **Block**.
  CodeLine: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Line', $ast: 'Code', arg1: {$ref: 2}, arg2: '(Block.wrap [$5])', arg3: {$ref: 4}, arg4: {}
                                                              LOC(1)(new Literal $1)
    o 'FuncGlyph Line'                                , $ast: 'Code', arg1: {$ary: [{}]}, arg2: '(Block.wrap [$2])', arg3: {$ref: 1}
  ]

  # CoffeeScript has two different symbols for functions. `->` is for ordinary
  # functions, and `=>` is for functions bound to the current value of *this*.
  FuncGlyph: [
    o '->', $ast: '@', base: $ref: 1
    o '=>', $ast: '@', base: $ref: 1
  ]

  # An optional, trailing comma.
  OptComma: [
    o ''
    o ','
  ]

  # The list of parameters that a function accepts can be of any length.
  ParamList: [
    o '',                                       -> []
    o 'Param'                                               , $ary: [$ref: 1]
    o 'ParamList , Param'                                   , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 3}]
    o 'ParamList OptComma TERMINATOR Param'                 , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
    o 'ParamList OptComma INDENT ParamList OptComma OUTDENT', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
  ]

  # A single parameter in a function definition can be ordinary, or a splat
  # that hoovers up the remaining arguments.
  Param: [
    o 'ParamVar'             , $ast: '@', base: $ref: 1
    o 'ParamVar ...'         , $ast: '@', arg1: {$ref: 1}, arg2: null, arg3: on
    o '... ParamVar'         , $ast: '@', arg1: {$ref: 2}, arg2: null, arg3: 'postfix: no'
    o 'ParamVar = Expression', $ast: '@', first: $ref: 1, second: $ref: 3
    o '...'                  , $ast: 'Expansion'
  ]

  # Function Parameters
  ParamVar: [
    o 'Identifier'
    o 'ThisProperty'
    o 'Array'
    o 'Object'
  ]

  # A splat that occurs outside of a parameter list.
  Splat: [
    o 'Expression ...', $ast: '@', base: $ref: 1
    o '... Expression', $ast: '@', arg1: {$ref: 2}, arg2: '{postfix: no}'
  ]

  # Variables and properties that can be assigned to.
  SimpleAssignable: [
    o 'Identifier'    , $ast: 'Value', base: $ref: 1
    o 'Value Accessor', $ops: 'add', target: {$ref: 1}, args: [{$ref: 2}]
    o 'Code Accessor' , $ast: 'Value', value: '$1).add $2'
    o 'ThisProperty'
  ]

  # Everything that can be assigned to.
  Assignable: [
    o 'SimpleAssignable'
    o 'Array'         , $ast: 'Value', base: $ref: 1
    o 'Object'        , $ast: 'Value', base: $ref: 1
  ]

  # The types of things that can be treated as values -- assigned to, invoked
  # as functions, indexed into, named as a class, etc.
  Value: [
    o 'Assignable'
    o 'Literal'      , $ast: '@', base: $ref: 1
    o 'Parenthetical', $ast: '@', base: $ref: 1
    o 'Range'        , $ast: '@', base: $ref: 1
    o 'Invocation'   , $ast: '@', base: $ref: 1
    o 'DoIife'       , $ast: '@', base: $ref: 1
    o 'This'
    o 'Super'        , $ast: '@', base: $ref: 1
    o 'MetaProperty' , $ast: '@', base: $ref: 1
  ]

  # A `super`-based expression that can be used as a value.
  Super: [
    o 'SUPER . Property'                                     , $ast: '@', arg1: {$ast: 'Access'}, arg2: '(new Literal $1'
    o 'SUPER INDEX_START Expression INDEX_END'               , $ast: '@', arg1: {$ast: 'Index'}, arg2: '(new Literal $1'
    o 'SUPER INDEX_START INDENT Expression OUTDENT INDEX_END', $ast: '@', arg1: {$ast: 'Index'}, arg2: '(new Literal $1'
  ]

  # A “meta-property” access e.g. `new.target` or `import.meta`, where
  # something that looks like a property is referenced on a keyword.
  MetaProperty: [
    o 'NEW_TARGET . Property' , $ast: '@', arg1: {$ast: 'IdentifierLiteral'}, arg2: '(new Access $3'
    o 'IMPORT_META . Property', $ast: '@', arg1: {$ast: 'IdentifierLiteral'}, arg2: '(new Access $3'
  ]

  # The general group of accessors into an object, by property, by prototype
  # or by array index or slice.
  Accessor: [
    o '.  Property' , $ast: 'Access', base: $ref: 2
    o '?. Property' , $ast: 'Access', arg1: {$ref: 2}, arg2: 'soak: yes'
    o ':: Property' , $ary: ['(new Access new PropertyName('prototype')', 'shorthand: yes)', '(new Access $2)']
    o '?:: Property', $ary: ['(new Access new PropertyName('prototype')', 'shorthand: yes', 'soak: yes)', '(new Access $2)']
    o '::'          , $ast: 'Access', arg1: {$ast: 'PropertyName'}, arg2: 'shorthand: yes'
    o '?::'         , $ast: 'Access', arg1: {$ast: 'PropertyName'}, arg2: 'shorthand: yes', arg3: 'soak: yes'
    o 'Index'
  ]

  # Indexing into an object or array using bracket notation.
  Index: [
    o 'INDEX_START IndexValue INDEX_END'               , $ref: 2
    o 'INDEX_START INDENT IndexValue OUTDENT INDEX_END', $ref: 3
    o 'INDEX_SOAK  Index'                              , # TODO: Transform manually: extend $2, soak: yes
  ]

  IndexValue: [
    o 'Expression', $ast: 'Index', base: $ref: 1
    o 'Slice'     , $ast: 'Slice', base: $ref: 1
  ]

  # In CoffeeScript, an object literal is simply a list of assignments.
  Object: [
    o '{ AssignList OptComma }', $ast: 'Obj', arg1: {$ref: 2}, arg2: {$ref: 1, prop: 'generated'}
  ]

  # Assignment of properties within an object literal can be separated by
  # comma, as in JavaScript, or simply by newline.
  AssignList: [
    o '',                                                       -> []
    o 'AssignObj'                                             , $ary: [$ref: 1]
    o 'AssignList , AssignObj'                                , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 3}]
    o 'AssignList OptComma TERMINATOR AssignObj'              , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
    o 'AssignList OptComma INDENT AssignList OptComma OUTDENT', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
  ]

  # Class definitions have optional bodies of prototype property assignments,
  # and optional references to the superclass.
  Class: [
    o 'CLASS'                                          , $ast: '@'
    o 'CLASS Block'                                    , $ast: '@', arg1: null, arg2: null, arg3: {$ref: 2}
    o 'CLASS EXTENDS Expression'                       , $ast: '@', arg1: null, arg2: {$ref: 3}
    o 'CLASS EXTENDS Expression Block'                 , $ast: '@', arg1: null, arg2: {$ref: 3}, arg3: {$ref: 4}
    o 'CLASS SimpleAssignable'                         , $ast: '@', base: $ref: 2
    o 'CLASS SimpleAssignable Block'                   , $ast: '@', arg1: {$ref: 2}, arg2: null, arg3: {$ref: 3}
    o 'CLASS SimpleAssignable EXTENDS Expression'      , $ast: '@', first: $ref: 2, second: $ref: 4
    o 'CLASS SimpleAssignable EXTENDS Expression Block', $ast: '@', first: $ref: 2, second: $ref: 4, third: $ref: 5
  ]

  Import: [
    o 'IMPORT String'                                                                             , $ast: 'ImportDeclaration', arg1: null, arg2: {$ref: 2}
    o 'IMPORT String ASSERT Object'                                                               , $ast: 'ImportDeclaration', arg1: null, arg2: {$ref: 2}, arg3: {$ref: 4}
    o 'IMPORT ImportDefaultSpecifier FROM String'                                                 , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: 'null)', arg3: {$ref: 4}
    o 'IMPORT ImportDefaultSpecifier FROM String ASSERT Object'                                   , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: 'null)', arg3: {$ref: 4}, arg4: {$ref: 6}
    o 'IMPORT ImportNamespaceSpecifier FROM String'                                               , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$2)', arg3: {$ref: 4}
    o 'IMPORT ImportNamespaceSpecifier FROM String ASSERT Object'                                 , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$2)', arg3: {$ref: 4}, arg4: {$ref: 6}
    o 'IMPORT { } FROM String'                                                                    , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: {$ref: 5}
    o 'IMPORT { } FROM String ASSERT Object'                                                      , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: {$ref: 5}, arg4: {$ref: 7}
    o 'IMPORT { ImportSpecifierList OptComma } FROM String'                                       , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: {$ref: 7}
    o 'IMPORT { ImportSpecifierList OptComma } FROM String ASSERT Object'                         , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: {$ref: 7}, arg4: {$ref: 9}
    o 'IMPORT ImportDefaultSpecifier , ImportNamespaceSpecifier FROM String'                      , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$4)', arg3: {$ref: 6}
    o 'IMPORT ImportDefaultSpecifier , ImportNamespaceSpecifier FROM String ASSERT Object'        , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$4)', arg3: {$ref: 6}, arg4: {$ref: 8}
    o 'IMPORT ImportDefaultSpecifier , { ImportSpecifierList OptComma } FROM String'              , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: {$ref: 9}
    o 'IMPORT ImportDefaultSpecifier , { ImportSpecifierList OptComma } FROM String ASSERT Object', $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: {$ref: 9}, arg4: {$ref: 11}
  ]

  ImportSpecifierList: [
    o 'ImportSpecifier'                                                         , $ary: [$ref: 1]
    o 'ImportSpecifierList , ImportSpecifier'                                   , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 3}]
    o 'ImportSpecifierList OptComma TERMINATOR ImportSpecifier'                 , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
    o 'INDENT ImportSpecifierList OptComma OUTDENT'                             , $ref: 2
    o 'ImportSpecifierList OptComma INDENT ImportSpecifierList OptComma OUTDENT', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
  ]

  ImportSpecifier: [
    o 'Identifier'              , $ast: '@', base: $ref: 1
    o 'Identifier AS Identifier', $ast: '@', first: $ref: 1, second: $ref: 3
    o 'DEFAULT'                 , $ast: '@', value: {$ast: 'DefaultLiteral'}
    o 'DEFAULT AS Identifier'   , $ast: '@', arg1: {$ast: 'DefaultLiteral'}, arg2: {$ref: 3}
  ]

  ImportDefaultSpecifier: [
    o 'Identifier', $ast: '@', base: $ref: 1
  ]

  ImportNamespaceSpecifier: [
    o 'IMPORT_ALL AS Identifier', $ast: '@', arg1: {$ast: 'Literal'}, arg2: {$ref: 3}
  ]

  Export: [
    o 'EXPORT { }'                                                       , $ast: 'ExportNamedDeclaration', value: {$ast: 'ExportSpecifierList'}
    o 'EXPORT { ExportSpecifierList OptComma }'                          , $ast: 'ExportNamedDeclaration', value: {$ast: 'ExportSpecifierList'}
    o 'EXPORT Class'                                                     , $ast: 'ExportNamedDeclaration', base: $ref: 2
    o 'EXPORT Identifier = Expression'                                   , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'Assign'}, arg2: {$ref: 4}, arg3: null, arg4: {}
                                                                                                      moduleDeclaration: 'export')
    o 'EXPORT Identifier = TERMINATOR Expression'                        , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'Assign'}, arg2: {$ref: 5}, arg3: null, arg4: {}
                                                                                                      moduleDeclaration: 'export')
    o 'EXPORT Identifier = INDENT Expression OUTDENT'                    , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'Assign'}, arg2: {$ref: 5}, arg3: null, arg4: {}
                                                                                                      moduleDeclaration: 'export')
    o 'EXPORT DEFAULT Expression'                                        , $ast: 'ExportDefaultDeclaration', base: $ref: 3
    o 'EXPORT DEFAULT INDENT Object OUTDENT'                             , $ast: 'ExportDefaultDeclaration', value: {$ast: 'Value'}
    o 'EXPORT EXPORT_ALL FROM String'                                    , $ast: 'ExportAllDeclaration', arg1: {$ast: 'Literal'}, arg2: {$ref: 4}
    o 'EXPORT EXPORT_ALL FROM String ASSERT Object'                      , $ast: 'ExportAllDeclaration', arg1: {$ast: 'Literal'}, arg2: {$ref: 4}, arg3: {$ref: 6}
    o 'EXPORT { } FROM String'                                           , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: {$ref: 5}
    o 'EXPORT { } FROM String ASSERT Object'                             , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: {$ref: 5}, arg3: {$ref: 7}
    o 'EXPORT { ExportSpecifierList OptComma } FROM String'              , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: {$ref: 7}
    o 'EXPORT { ExportSpecifierList OptComma } FROM String ASSERT Object', $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: {$ref: 7}, arg3: {$ref: 9}
  ]

  ExportSpecifierList: [
    o 'ExportSpecifier'                                                         , $ary: [$ref: 1]
    o 'ExportSpecifierList , ExportSpecifier'                                   , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 3}]
    o 'ExportSpecifierList OptComma TERMINATOR ExportSpecifier'                 , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
    o 'INDENT ExportSpecifierList OptComma OUTDENT'                             , $ref: 2
    o 'ExportSpecifierList OptComma INDENT ExportSpecifierList OptComma OUTDENT', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
  ]

  ExportSpecifier: [
    o 'Identifier'              , $ast: '@', base: $ref: 1
    o 'Identifier AS Identifier', $ast: '@', first: $ref: 1, second: $ref: 3
    o 'Identifier AS DEFAULT'   , $ast: '@', arg1: {$ref: 1}, arg2: '(new DefaultLiteral $3'
    o 'DEFAULT'                 , $ast: '@', value: {$ast: 'DefaultLiteral'}
    o 'DEFAULT AS Identifier'   , $ast: '@', arg1: {$ast: 'DefaultLiteral'}, arg2: {$ref: 3}
  ]

  # Ordinary function invocation, or a chained series of calls.
  Invocation: [
    o 'Value OptFuncExist String'   , $ast: 'TaggedTemplateCall', arg1: {$ref: 1}, arg2: {$ref: 3}, arg3: {$ref: 2, prop: 'soak'}
    o 'Value OptFuncExist Arguments', $ast: 'Call', arg1: {$ref: 1}, arg2: {$ref: 3}, arg3: {$ref: 2, prop: 'soak'}
    o 'SUPER OptFuncExist Arguments', $ast: 'SuperCall', arg1: {$ast: 'Super'}, arg2: {$ref: 3}, arg3: {$ref: 2, prop: 'soak'}, arg4: {$ref: 1}
    o 'DYNAMIC_IMPORT Arguments'    , $ast: 'DynamicImportCall', arg1: {$ast: 'DynamicImport'}, arg2: {$ref: 2}
  ]

  # An optional existence check on a function.
  OptFuncExist: [
    o '',                                       -> soak: no
    o 'FUNC_EXIST', # TODO: Transform manually: soak: yes
  ]

  # The list of arguments to a function call.
  Arguments: [
    o 'CALL_START CALL_END'                 , $ary: [{}]
    o 'CALL_START ArgList OptComma CALL_END', $ops: 'set', target: {$ref: 2}, prop: 'implicit', value: '$1.generated; $2'
  ]

  # A reference to the *this* current object.
  This: [
    o 'THIS', $ast: 'Value', value: {$ast: 'ThisLiteral'}
    o '@'   , $ast: 'Value', value: {$ast: 'ThisLiteral'}
  ]

  # A reference to a property on *this*.
  ThisProperty: [
    o '@ Property', $ast: 'Value', arg1: {$ast: 'ThisLiteral'}, arg2: {$ary: ['(new Access($2))']}, arg3: 'this'
  ]

  # The array literal.
  Array: [
    o '[ ]'                           , $ast: 'Arr', value: {$ary: [{}]}
    o '[ Elisions ]'                  , $ast: 'Arr', base: $ref: 2
    o '[ ArgElisionList OptElisions ]', $ast: 'Arr', arg1: '[].concat $2', arg2: {$ref: 3}
  ]

  # Inclusive and exclusive range dots.
  RangeDots: [
    o '..' , # TODO: Transform manually: exclusive: no
    o '...', # TODO: Transform manually: exclusive: yes
  ]

  # The CoffeeScript range literal.
  Range: [
    o '[ Expression RangeDots Expression ]'    , $ast: '@', arg1: {$ref: 2}, arg2: {$ref: 4}, arg3: 'if $3.exclusive then 'exclusive' else 'inclusive''
    o '[ ExpressionLine RangeDots Expression ]', $ast: '@', arg1: {$ref: 2}, arg2: {$ref: 4}, arg3: 'if $3.exclusive then 'exclusive' else 'inclusive''
  ]

  # Array slice literals.
  Slice: [
    o 'Expression RangeDots Expression'    , $ast: 'Range', arg1: {$ref: 1}, arg2: {$ref: 3}, arg3: 'if $2.exclusive then 'exclusive' else 'inclusive''
    o 'Expression RangeDots'               , $ast: 'Range', arg1: {$ref: 1}, arg2: null, arg3: 'if $2.exclusive then 'exclusive' else 'inclusive''
    o 'ExpressionLine RangeDots Expression', $ast: 'Range', arg1: {$ref: 1}, arg2: {$ref: 3}, arg3: 'if $2.exclusive then 'exclusive' else 'inclusive''
    o 'ExpressionLine RangeDots'           , $ast: 'Range', arg1: {$ref: 1}, arg2: null, arg3: 'if $2.exclusive then 'exclusive' else 'inclusive''
    o 'RangeDots Expression'               , $ast: 'Range', arg1: null, arg2: {$ref: 2}, arg3: 'if $1.exclusive then 'exclusive' else 'inclusive''
    o 'RangeDots'                          , $ast: 'Range', arg1: null, arg2: null, arg3: 'if $1.exclusive then 'exclusive' else 'inclusive''
  ]

  # The **ArgList** is the list of objects passed into a function call
  # (i.e. comma-separated expressions). Newlines work as well.
  ArgList: [
    o 'Arg'                                             , $ary: [$ref: 1]
    o 'ArgList , Arg'                                   , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 3}]
    o 'ArgList OptComma TERMINATOR Arg'                 , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
    o 'INDENT ArgList OptComma OUTDENT'                 , $ref: 2
    o 'ArgList OptComma INDENT ArgList OptComma OUTDENT', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
  ]

  # Valid arguments are Blocks or Splats.
  Arg: [
    o 'Expression'
    o 'ExpressionLine'
    o 'Splat'
    o '...'         , $ast: 'Expansion'
  ]

  # The **ArgElisionList** is the list of objects, contents of an array literal
  # (i.e. comma-separated expressions and elisions). Newlines work as well.
  ArgElisionList: [
    o 'ArgElision'
    o 'ArgElisionList , ArgElision'                                         , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 3}]
    o 'ArgElisionList OptComma TERMINATOR ArgElision'                       , $ops: 'concat', target: {$ref: 1}, args: [{$ref: 4}]
    o 'INDENT ArgElisionList OptElisions OUTDENT'                           , $ops: 'concat', target: {$ref: 2}, args: [{$ref: 3}]
    o 'ArgElisionList OptElisions INDENT ArgElisionList OptElisions OUTDENT', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 2}, {$ref: 4}, {$ref: 5}]
  ]

  ArgElision: [
    o 'Arg'         , $ary: [$ref: 1]
    o 'Elisions Arg', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 2}]
  ]

  OptElisions: [
    o 'OptComma'  , $ary: [{}]
    o ', Elisions', # TODO: Transform manually: [].concat $2
  ]

  Elisions: [
    o 'Elision'         , $ary: [$ref: 1]
    o 'Elisions Elision', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 2}]
  ]

  Elision: [
    o ','                 , $ast: '@'
    o 'Elision TERMINATOR', $ref: 1
  ]

  # Just simple, comma-separated, required arguments (no fancy syntax). We need
  # this to be separate from the **ArgList** for use in **Switch** blocks, where
  # having the newlines wouldn't make sense.
  SimpleArgs: [
    o 'Expression'
    o 'ExpressionLine'
    o 'SimpleArgs , Expression'    , # TODO: Transform manually: [].concat $1, $3
    o 'SimpleArgs , ExpressionLine', # TODO: Transform manually: [].concat $1, $3
  ]

  # The variants of *try/catch/finally* exception handling blocks.
  Try: [
    o 'TRY Block'                    , $ast: '@', base: $ref: 2
    o 'TRY Block Catch'              , $ast: '@', first: $ref: 2, second: $ref: 3
    o 'TRY Block FINALLY Block'      , $ast: '@', arg1: {$ref: 2}, arg2: null, arg3: {$ref: 4}, arg4: '(new Literal $3'
    o 'TRY Block Catch FINALLY Block', $ast: '@', arg1: {$ref: 2}, arg2: {$ref: 3}, arg3: {$ref: 5}, arg4: '(new Literal $4'
  ]

  # A catch clause names its error and runs a block of code.
  Catch: [
    o 'CATCH Identifier Block', $ast: '@', first: $ref: 3, second: $ref: 2
    o 'CATCH Object Block'    , $ast: '@', arg1: {$ref: 3}, arg2: '(new Value($2)'
    o 'CATCH Block'           , $ast: '@', base: $ref: 2
  ]

  # Throw an exception object.
  Throw: [
    o 'THROW Expression'           , $ast: '@', base: $ref: 2
    o 'THROW INDENT Object OUTDENT', $ast: '@', value: {$ast: 'Value'}
  ]

  # Parenthetical expressions. Note that the **Parenthetical** is a **Value**,
  # not an **Expression**, so if you need to use an expression in a place
  # where only values are accepted, wrapping it in parentheses will always do
  # the trick.
  Parenthetical: [
    o '( Body )'               , $ast: 'Parens', base: $ref: 2
    o '( INDENT Body OUTDENT )', $ast: 'Parens', base: $ref: 3
  ]

  # The condition portion of a while loop.
  WhileLineSource: [
    o 'WHILE ExpressionLine'                    , $ast: 'While', base: $ref: 2
    o 'WHILE ExpressionLine WHEN ExpressionLine', $ast: 'While', arg1: {$ref: 2}, arg2: 'guard: $4'
    o 'UNTIL ExpressionLine'                    , $ast: 'While', arg1: {$ref: 2}, arg2: 'invert: true'
    o 'UNTIL ExpressionLine WHEN ExpressionLine', $ast: 'While', arg1: {$ref: 2}, arg2: 'invert: true', arg3: 'guard: $4'
  ]

  WhileSource: [
    o 'WHILE Expression'                    , $ast: 'While', base: $ref: 2
    o 'WHILE Expression WHEN Expression'    , $ast: 'While', arg1: {$ref: 2}, arg2: 'guard: $4'
    o 'WHILE ExpressionLine WHEN Expression', $ast: 'While', arg1: {$ref: 2}, arg2: 'guard: $4'
    o 'UNTIL Expression'                    , $ast: 'While', arg1: {$ref: 2}, arg2: 'invert: true'
    o 'UNTIL Expression WHEN Expression'    , $ast: 'While', arg1: {$ref: 2}, arg2: 'invert: true', arg3: 'guard: $4'
    o 'UNTIL ExpressionLine WHEN Expression', $ast: 'While', arg1: {$ref: 2}, arg2: 'invert: true', arg3: 'guard: $4'
  ]

  # The while loop can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression. There is no do..while.
  While: [
    o 'WhileSource Block'     , $ops: 'add', target: {$ref: 1}, args: ['Body $2']
    o 'WhileLineSource Block' , $ops: 'add', target: {$ref: 1}, args: ['Body $2']
    o 'Statement  WhileSource', # TODO: Transform manually: (Object.assign $2, postfix: yes).addBody LOC(1) Block.wrap([$1])
    o 'Expression WhileSource', # TODO: Transform manually: (Object.assign $2, postfix: yes).addBody LOC(1) Block.wrap([$1])
    o 'Loop'                  , $ref: 1
  ]

  Loop: [
    o 'LOOP Block'     , $ast: 'While', arg1: '(new BooleanLiteral 'true')', arg2: 'isLoop: yes).addBody $2'
    o 'LOOP Expression', $ast: 'While', arg1: '(new BooleanLiteral 'true')', arg2: 'isLoop: yes).addBody LOC(2) Block.wrap [$2]'
  ]

  # Array, object, and range comprehensions, at the most generic level.
  # Comprehensions can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression.
  For: [
    o 'Statement    ForBody', $ops: 'set', target: {$ref: 2}, prop: 'postfix', value: 'yes; $2.addBody $1'
    o 'Expression   ForBody', $ops: 'set', target: {$ref: 2}, prop: 'postfix', value: 'yes; $2.addBody $1'
    o 'ForBody      Block'  , $ops: 'add', target: {$ref: 1}, args: ['Body $2']
    o 'ForLineBody  Block'  , $ops: 'add', target: {$ref: 1}, args: ['Body $2']
  ]

  ForBody: [
    o 'FOR Range'              , $ast: 'For', arg1: {$ary: [{}]}, arg2: 'source: (LOC(2) new Value($2)'
    o 'FOR Range BY Expression', $ast: 'For', arg1: {$ary: [{}]}, arg2: 'source: (LOC(2) new Value($2))', arg3: 'step: $4'
    o 'ForStart ForSource'     , $ops: 'add', target: {$ref: 1}, args: ['Source $2']
  ]

  ForLineBody: [
    o 'FOR Range BY ExpressionLine', $ast: 'For', arg1: {$ary: [{}]}, arg2: 'source: (LOC(2) new Value($2))', arg3: 'step: $4'
    o 'ForStart ForLineSource'     , $ops: 'add', target: {$ref: 1}, args: ['Source $2']
  ]

  ForStart: [
    o 'FOR ForVariables'       , $ast: 'For', arg1: {$ary: [{}]}, arg2: 'name: $2[0]', arg3: 'index: $2[1]'
    o 'FOR AWAIT ForVariables', ->
        [name, index] = $3
        new For [], {name, index, await: yes, awaitTag: (LOC(2) new Literal($2))}
    o 'FOR OWN ForVariables', ->
        [name, index] = $3
        new For [], {name, index, own: yes, ownTag: (LOC(2) new Literal($2))}
  ]

  # An array of all accepted values for a variable inside the loop.
  # This enables support for pattern matching.
  ForValue: [
    o 'Identifier'
    o 'ThisProperty'
    o 'Array'     , $ast: 'Value', base: $ref: 1
    o 'Object'    , $ast: 'Value', base: $ref: 1
  ]

  # An array or range comprehension has variables for the current element
  # and (optional) reference to the current index. Or, *key, value*, in the case
  # of object comprehensions.
  ForVariables: [
    o 'ForValue'           , $ary: [$ref: 1]
    o 'ForValue , ForValue', $ary: [$ref: 1, $ref: 3]
  ]

  # The source of a comprehension is an array or object with an optional guard
  # clause. If it’s an array comprehension, you can also choose to step through
  # in fixed-size increments.
  ForSource: [
    o 'FORIN Expression'                                      , # TODO: Transform manually: source: $2
    o 'FOROF Expression'                                      , # TODO: Transform manually: source: $2, object: yes
    o 'FORIN Expression WHEN Expression'                      , # TODO: Transform manually: source: $2, guard: $4
    o 'FORIN ExpressionLine WHEN Expression'                  , # TODO: Transform manually: source: $2, guard: $4
    o 'FOROF Expression WHEN Expression'                      , # TODO: Transform manually: source: $2, guard: $4, object: yes
    o 'FOROF ExpressionLine WHEN Expression'                  , # TODO: Transform manually: source: $2, guard: $4, object: yes
    o 'FORIN Expression BY Expression'                        , # TODO: Transform manually: source: $2, step:  $4
    o 'FORIN ExpressionLine BY Expression'                    , # TODO: Transform manually: source: $2, step:  $4
    o 'FORIN Expression WHEN Expression BY Expression'        , # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN ExpressionLine WHEN Expression BY Expression'    , # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN Expression WHEN ExpressionLine BY Expression'    , # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN ExpressionLine WHEN ExpressionLine BY Expression', # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN Expression BY Expression WHEN Expression'        , # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORIN ExpressionLine BY Expression WHEN Expression'    , # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORIN Expression BY ExpressionLine WHEN Expression'    , # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORIN ExpressionLine BY ExpressionLine WHEN Expression', # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORFROM Expression'                                    , # TODO: Transform manually: source: $2, from: yes
    o 'FORFROM Expression WHEN Expression'                    , # TODO: Transform manually: source: $2, guard: $4, from: yes
    o 'FORFROM ExpressionLine WHEN Expression'                , # TODO: Transform manually: source: $2, guard: $4, from: yes
  ]

  ForLineSource: [
    o 'FORIN ExpressionLine'                                      , # TODO: Transform manually: source: $2
    o 'FOROF ExpressionLine'                                      , # TODO: Transform manually: source: $2, object: yes
    o 'FORIN Expression WHEN ExpressionLine'                      , # TODO: Transform manually: source: $2, guard: $4
    o 'FORIN ExpressionLine WHEN ExpressionLine'                  , # TODO: Transform manually: source: $2, guard: $4
    o 'FOROF Expression WHEN ExpressionLine'                      , # TODO: Transform manually: source: $2, guard: $4, object: yes
    o 'FOROF ExpressionLine WHEN ExpressionLine'                  , # TODO: Transform manually: source: $2, guard: $4, object: yes
    o 'FORIN Expression BY ExpressionLine'                        , # TODO: Transform manually: source: $2, step:  $4
    o 'FORIN ExpressionLine BY ExpressionLine'                    , # TODO: Transform manually: source: $2, step:  $4
    o 'FORIN Expression WHEN Expression BY ExpressionLine'        , # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN ExpressionLine WHEN Expression BY ExpressionLine'    , # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN Expression WHEN ExpressionLine BY ExpressionLine'    , # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN ExpressionLine WHEN ExpressionLine BY ExpressionLine', # TODO: Transform manually: source: $2, guard: $4, step: $6
    o 'FORIN Expression BY Expression WHEN ExpressionLine'        , # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORIN ExpressionLine BY Expression WHEN ExpressionLine'    , # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORIN Expression BY ExpressionLine WHEN ExpressionLine'    , # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORIN ExpressionLine BY ExpressionLine WHEN ExpressionLine', # TODO: Transform manually: source: $2, step:  $4, guard: $6
    o 'FORFROM ExpressionLine'                                    , # TODO: Transform manually: source: $2, from: yes
    o 'FORFROM Expression WHEN ExpressionLine'                    , # TODO: Transform manually: source: $2, guard: $4, from: yes
    o 'FORFROM ExpressionLine WHEN ExpressionLine'                , # TODO: Transform manually: source: $2, guard: $4, from: yes
  ]

  Switch: [
    o 'SWITCH Expression INDENT Whens OUTDENT'               , $ast: '@', first: $ref: 2, second: $ref: 4
    o 'SWITCH ExpressionLine INDENT Whens OUTDENT'           , $ast: '@', first: $ref: 2, second: $ref: 4
    o 'SWITCH Expression INDENT Whens ELSE Block OUTDENT'    , $ast: '@', arg1: {$ref: 2}, arg2: {$ref: 4}, arg3: 'LOC(5', arg4: '6) $6'
    o 'SWITCH ExpressionLine INDENT Whens ELSE Block OUTDENT', $ast: '@', arg1: {$ref: 2}, arg2: {$ref: 4}, arg3: 'LOC(5', arg4: '6) $6'
    o 'SWITCH INDENT Whens OUTDENT'                          , $ast: '@', arg1: null, arg2: {$ref: 3}
    o 'SWITCH INDENT Whens ELSE Block OUTDENT'               , $ast: '@', arg1: null, arg2: {$ref: 3}, arg3: 'LOC(4', arg4: '5) $5'
  ]

  Whens: [
    o 'When'      , $ary: [$ref: 1]
    o 'Whens When', $ops: 'concat', target: {$ref: 1}, args: [{$ref: 2}]
  ]

  # An individual **When** clause, with action.
  When: [
    o 'LEADING_WHEN SimpleArgs Block'           , $ast: 'SwitchWhen', first: $ref: 2, second: $ref: 3
    o 'LEADING_WHEN SimpleArgs Block TERMINATOR', # TODO: Transform manually: LOC(1, 3) new SwitchWhen $2, $3
  ]

  # The most basic form of *if* is a condition and an action. The following
  # if-related rules are broken up along these lines in order to avoid
  # ambiguity.
  IfBlock: [
    o 'IF Expression Block'             , $ast: 'If', arg1: {$ref: 2}, arg2: {$ref: 3}, arg3: 'type: $1'
    o 'IfBlock ELSE IF Expression Block', $ops: 'add', target: {$ref: 1}, args: ['Else LOC(3', '5) new If $4', {$ref: 5}, 'type: $3']
  ]

  # The full complement of *if* expressions, including postfix one-liner
  # *if* and *unless*.
  If: [
    o 'IfBlock'
    o 'IfBlock ELSE Block'           , $ops: 'add', target: {$ref: 1}, args: ['Else $3']
    o 'Statement  POST_IF Expression', $ast: '@', arg1: {$ref: 3}, arg2: '(Block.wrap [$1])', arg3: 'type: $2', arg4: 'postfix: true'
    o 'Expression POST_IF Expression', $ast: '@', arg1: {$ref: 3}, arg2: '(Block.wrap [$1])', arg3: 'type: $2', arg4: 'postfix: true'
  ]

  IfBlockLine: [
    o 'IF ExpressionLine Block'                 , $ast: 'If', arg1: {$ref: 2}, arg2: {$ref: 3}, arg3: 'type: $1'
    o 'IfBlockLine ELSE IF ExpressionLine Block', $ops: 'add', target: {$ref: 1}, args: ['Else LOC(3', '5) new If $4', {$ref: 5}, 'type: $3']
  ]

  IfLine: [
    o 'IfBlockLine'
    o 'IfBlockLine ELSE Block'           , $ops: 'add', target: {$ref: 1}, args: ['Else $3']
    o 'Statement  POST_IF ExpressionLine', $ast: 'If', arg1: {$ref: 3}, arg2: '(Block.wrap [$1])', arg3: 'type: $2', arg4: 'postfix: true'
    o 'Expression POST_IF ExpressionLine', $ast: 'If', arg1: {$ref: 3}, arg2: '(Block.wrap [$1])', arg3: 'type: $2', arg4: 'postfix: true'
  ]

  # Arithmetic and logical operators, working on one or more operands.
  # Here they are grouped by order of precedence. The actual precedence rules
  # are defined at the bottom of the page. It would be shorter if we could
  # combine most of these rules into a single generic *Operand OpSymbol Operand*
  # -type rule, but in order to make the precedence binding possible, separate
  # rules are necessary.
  OperationLine: [
    o 'UNARY ExpressionLine', $ast: 'Op', first: $ref: 1, second: $ref: 2
    o 'DO ExpressionLine'   , $ast: 'Op', first: $ref: 1, second: $ref: 2
    o 'DO_IIFE CodeLine'    , $ast: 'Op', first: $ref: 1, second: $ref: 2
  ]

  Operation: [
    o 'UNARY Expression'                     , $ast: 'Op', arg1: '$1.toString()', arg2: {$ref: 2}, arg3: undefined, arg4: undefined, arg5: 'originalOperator: $1.original'
    o 'DO Expression'                        , $ast: 'Op', first: $ref: 1, second: $ref: 2
    o 'UNARY_MATH Expression'                , $ast: 'Op', first: $ref: 1, second: $ref: 2
    o '-     Expression', (-> new Op '-', $2), prec: 'UNARY_MATH'
    o '+     Expression', (-> new Op '+', $2), prec: 'UNARY_MATH'

    o 'AWAIT Expression'                     , $ast: 'Op', first: $ref: 1, second: $ref: 2
    o 'AWAIT INDENT Object OUTDENT'          , $ast: 'Op', first: $ref: 1, second: $ref: 3

    o '-- SimpleAssignable'                  , $ast: 'Op', operator: '--', operand: {$ref: 2}
    o '++ SimpleAssignable'                  , $ast: 'Op', operator: '++', operand: {$ref: 2}
    o 'SimpleAssignable --'                  , $ast: 'Op', operator: '--', operand: '$1, null, true'
    o 'SimpleAssignable ++'                  , $ast: 'Op', operator: '++', operand: '$1, null, true'

    # [The existential operator](https://coffeescript.org/#existential-operator).
    o 'Expression ?'                         , $ast: 'Existence', base: $ref: 1

    o 'Expression +  Expression'             , $ast: 'Op', operator: '+', operand: '$1, $3'
    o 'Expression -  Expression'             , $ast: 'Op', operator: '-', operand: '$1, $3'

    o 'Expression MATH     Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression **       Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression SHIFT    Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression COMPARE  Expression'       , $ast: 'Op', arg1: '$2.toString()', arg2: {$ref: 1}, arg3: {$ref: 3}, arg4: undefined, arg5: 'originalOperator: $2.original'
    o 'Expression &        Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression ^        Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression |        Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression &&       Expression'       , $ast: 'Op', arg1: '$2.toString()', arg2: {$ref: 1}, arg3: {$ref: 3}, arg4: undefined, arg5: 'originalOperator: $2.original'
    o 'Expression ||       Expression'       , $ast: 'Op', arg1: '$2.toString()', arg2: {$ref: 1}, arg3: {$ref: 3}, arg4: undefined, arg5: 'originalOperator: $2.original'
    o 'Expression BIN?     Expression'       , $ast: 'Op', first: $ref: 2, second: $ref: 1, third: $ref: 3
    o 'Expression RELATION Expression'       , $ast: 'Op', arg1: '$2.toString()', arg2: {$ref: 1}, arg3: {$ref: 3}, arg4: undefined, arg5: 'invertOperator: $2.invert?.original ? $2.invert'

    o 'SimpleAssignable COMPOUND_ASSIGN
       Expression',                             -> new Assign $1, $3, $2.toString(), originalContext: $2.original
    o 'SimpleAssignable COMPOUND_ASSIGN
       INDENT Expression OUTDENT',              -> new Assign $1, $4, $2.toString(), originalContext: $2.original
    o 'SimpleAssignable COMPOUND_ASSIGN TERMINATOR
       Expression',                             -> new Assign $1, $4, $2.toString(), originalContext: $2.original
  ]

  DoIife: [
    o 'DO_IIFE Code', $ast: 'Op', arg1: {$ref: 1}, arg2: {$ref: 2}
  ]

# Precedence
# ----------

# Operators at the top of this list have higher precedence than the ones lower
# down. Following these rules is what makes `2 + 3 * 4` parse as:
#
#     2 + (3 * 4)
#
# And not:
#
#     (2 + 3) * 4
operators = [
  ['right',     'DO_IIFE']
  ['left',      '.', '?.', '::', '?::']
  ['left',      'CALL_START', 'CALL_END']
  ['nonassoc',  '++', '--']
  ['left',      '?']
  ['right',     'UNARY', 'DO']
  ['right',     'AWAIT']
  ['right',     '**']
  ['right',     'UNARY_MATH']
  ['left',      'MATH']
  ['left',      '+', '-']
  ['left',      'SHIFT']
  ['left',      'RELATION']
  ['left',      'COMPARE']
  ['left',      '&']
  ['left',      '^']
  ['left',      '|']
  ['left',      '&&']
  ['left',      '||']
  ['left',      'BIN?']
  ['nonassoc',  'INDENT', 'OUTDENT']
  ['right',     'YIELD']
  ['right',     '=', ':', 'COMPOUND_ASSIGN', 'RETURN', 'THROW', 'EXTENDS']
  ['right',     'FORIN', 'FOROF', 'FORFROM', 'BY', 'WHEN']
  ['right',     'IF', 'ELSE', 'FOR', 'WHILE', 'UNTIL', 'LOOP', 'SUPER', 'CLASS', 'IMPORT', 'EXPORT', 'DYNAMIC_IMPORT']
  ['left',      'POST_IF']
]

# Wrapping Up
# -----------

# Process the grammar rules and prepare them for the parser generator.
# We perform language-specific preprocessing to add return statements
# to Root rules, which is required for proper parser operation.
# The operators are reversed because the parser generator orders
# precedence from low to high, and we have it high to low
# (as in [Yacc](http://dinosaur.compilertools.net/yacc/index.html)).

# Add return statements to Root rule actions for proper parser behavior
for own name, alternatives of grammar
  grammar[name] = for alt in alternatives
    alt[1] = "return #{alt[1]}" if name is 'Root'
    alt

# Export the processed grammar and operators for the parser generator. Unlike
# the original implementation, we no longer extract and pass tokens separately,
# the parser generator can derive them automatically from the BNF grammar.
# CS3: Export with 'grammar' key to signal data-oriented format
module.exports =
  grammar: grammar      # Changed from 'bnf' to 'grammar' for CS3
  operators: operators.reverse() if operators?
  start: 'Root'