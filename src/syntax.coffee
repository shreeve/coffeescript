# ==============================================================================
# CS3 Syntax - Data-Oriented Grammar for CoffeeScript 3
#
# Automatically generated from grammar.coffee
#
# KEY CHANGES:
# - Actions are pure data objects, NOT functions
# - Uses CS3 directives: $ast, $rhs, $obj, $seq, $ops, $ary, $ite
# - Export key is 'grammar' not 'bnf' to signal data-oriented format
#
# EXAMPLES:
#   Old: o 'Body', -> new Root $1
#   New: o 'Body', $ast: 'Root', body: 1
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
    o ''    , $ast: '@', body: []
    o 'Body', $ast: '@', body: 1
  ]

  # Any list of statements and expressions, separated by line breaks or semicolons.
  Body: [
    o 'Line'                , $ary: [1]
    o 'Body TERMINATOR Line', $ops: 'array', append: [1, 3]
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
    o 'STATEMENT', $ast: 'StatementLiteral', base: 1
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
    o 'YIELD'                      , $ast: 'Op', args: [1, {$ast: 'Value'}]
    o 'YIELD Expression'           , $ast: 'Op', args: [1, 2]
    o 'YIELD INDENT Object OUTDENT', $ast: 'Op', args: [1, 3]
    o 'YIELD FROM Expression'      , $ast: 'Op', args: [{$use: 1, method: 'concat', args: [2]}, 3]
  ]

  # An indented block of expressions. Note that the [Rewriter](rewriter.html)
  # will convert some postfix forms into blocks for us, by adjusting the
  # token stream.
  Block: [
    o 'INDENT OUTDENT'     , $ast: '@'
    o 'INDENT Body OUTDENT', $use: 2
  ]

  Identifier: [
    o 'IDENTIFIER', $ast: 'IdentifierLiteral', base: 1
  ]

  Property: [
    o 'PROPERTY', $ast: 'PropertyName', value: '$1.toString('
  ]

  # Alphanumerics are separated from the other **Literal** matchers because
  # they can also serve as keys in object literals.
  AlphaNumeric: [
    o 'NUMBER', $ast: 'NumberLiteral', value: {$use: 1, method: 'toString'}, parsedValue: {$use: 1, prop: 'parsedValue'}
    o 'String'
  ]

  String: [
    o 'STRING'                                , $ast: 'StringLiteral', value: {$use: 1, method: 'slice', args: [1, -1]}, quote: {$use: 1, prop: 'quote'}, initialChunk: {$use: 1, prop: 'initialChunk'}, finalChunk: {$use: 1, prop: 'finalChunk'}, indent: {$use: 1, prop: 'indent'}, double: {$use: 1, prop: 'double'}, heregex: {$use: 1, prop: 'heregex'}
    o 'STRING_START Interpolations STRING_END', $ast: 'StringWithInterpolations', body: 2, quote: {$use: 1, prop: 'quote'}, startQuote: {$ast: 'Literal', value: {$use: 1, method: 'toString'}, $pos: 1}
  ]

  Interpolations: [
    o 'InterpolationChunk'               , $ary: [1]
    o 'Interpolations InterpolationChunk', $ops: 'array', append: [1, 2]
  ]

  InterpolationChunk: [
    o 'INTERPOLATION_START Body INTERPOLATION_END'               , $ast: 'Interpolation', base: 2
    o 'INTERPOLATION_START INDENT Body OUTDENT INTERPOLATION_END', $ast: 'Interpolation', base: 3
    o 'INTERPOLATION_START INTERPOLATION_END'                    , $ast: 'Interpolation'
    o 'String'                                                   , $use: 1
  ]

  # The .toString() calls here and elsewhere are to convert `String` objects
  # back to primitive strings now that we've retrieved stowaway extra properties
  Regex: [
    o 'REGEX'                           , $ast: 'RegexLiteral', value: '1.toString()', delimiter: '1.delimiter', heregexCommentTokens: '1.heregexCommentTokens'
    o 'REGEX_START Invocation REGEX_END', $ast: 'RegexWithInterpolations', invocation: 2, heregexCommentTokens: '3.heregexCommentTokens'
  ]

  # All of our immediate values. Generally these can be passed straight
  # through and printed to JavaScript.
  Literal: [
    o 'AlphaNumeric'
    o 'JS'          , $ast: 'PassthroughLiteral', value: {$use: 1, method: 'toString'}, here: {$use: 1, prop: 'here'}, generated: {$use: 1, prop: 'generated'}
    o 'Regex'
    o 'UNDEFINED'   , $ast: 'UndefinedLiteral', base: 1
    o 'NULL'        , $ast: 'NullLiteral', base: 1
    o 'BOOL'        , $ast: 'BooleanLiteral', value: {$use: 1, method: 'toString'}, originalValue: {$use: 1, prop: 'original'}
    o 'INFINITY'    , $ast: 'InfinityLiteral', value: {$use: 1, method: 'toString'}, originalValue: {$use: 1, prop: 'original'}
    o 'NAN'         , $ast: 'NaNLiteral', base: 1
  ]

  # Assignment of a variable, property, or index to a value.
  Assign: [
    o 'Assignable = Expression'               , $ast: '@', first: 1, second: 3
    o 'Assignable = TERMINATOR Expression'    , $ast: '@', first: 1, second: 4
    o 'Assignable = INDENT Expression OUTDENT', $ast: '@', first: 1, second: 4
  ]

  # Assignment when it happens within an object literal. The difference from
  # the ordinary **Assign** is that these allow numbers and strings as keys.
  AssignObj: [
    o 'ObjAssignable'                   , $ast: 'Value', val: 1
    o 'ObjRestValue'
    o 'ObjAssignable : Expression'      , $ast: 'Assign', value: {$ast: 'Value', val: 1, $pos: 1}, expression: 3, context: 'object', operatorToken: {$ast: 'Literal', value: 2, $pos: 2}
    o 'ObjAssignable :
       INDENT Expression OUTDENT'        , $ast: 'Assign', value: {$ast: 'Value', val: 1, $pos: 1}, expression: 4, context: 'object', operatorToken: {$ast: 'Literal', value: 2, $pos: 2}
    o 'SimpleObjAssignable = Expression', $ast: 'Assign', value: {$ast: 'Value', val: 1, $pos: 1}, expression: 3, operatorToken: {$ast: 'Literal', value: 2, $pos: 2}
    o 'SimpleObjAssignable =
       INDENT Expression OUTDENT'        , $ast: 'Assign', value: {$ast: 'Value', val: 1, $pos: 1}, expression: 4, operatorToken: {$ast: 'Literal', value: 2, $pos: 2}
  ]

  SimpleObjAssignable: [
    o 'Identifier'
    o 'Property'
    o 'ThisProperty'
  ]

  ObjAssignable: [
    o 'SimpleObjAssignable'
    o '[ Expression ]'     , $ast: 'Value', value: {$ast: 'ComputedPropertyName'}
    o '@ [ Expression ]'   , $ast: 'Value', val: {$ast: 'ThisLiteral', value: 1, $pos: 1}, properties: [{$ast: 'ComputedPropertyName', name: 3, $pos: 3}], context: 'this'
    o 'AlphaNumeric'
  ]

  # Object literal spread properties.
  ObjRestValue: [
    o 'SimpleObjAssignable ...', $ast: 'Splat', value: {$ast: 'Value'}
    o '... SimpleObjAssignable', $ast: 'Splat', arg1: {$ast: 'Value'}, arg2: 'postfix: no'
    o 'ObjSpreadExpr ...'      , $ast: 'Splat', base: 1
    o '... ObjSpreadExpr'      , $ast: 'Splat', arg1: 2, arg2: 'postfix: no'
  ]

  ObjSpreadExpr: [
    o 'ObjSpreadIdentifier'
    o 'Object'
    o 'Parenthetical'
    o 'Super'
    o 'This'
    o 'SUPER OptFuncExist Arguments'              , $ast: 'SuperCall', arg1: {$ast: 'Super'}, arg2: 3, arg3: {$use: 2, prop: 'soak'}, arg4: 1
    o 'DYNAMIC_IMPORT Arguments'                  , $ast: 'DynamicImportCall', arg1: {$ast: 'DynamicImport'}, arg2: 2
    o 'SimpleObjAssignable OptFuncExist Arguments', $ast: 'Call', arg1: {$ast: 'Value'}, arg2: 3, arg3: {$use: 2, prop: 'soak'}
    o 'ObjSpreadExpr OptFuncExist Arguments'      , $ast: 'Call', arg1: 1, arg2: 3, arg3: {$use: 2, prop: 'soak'}
  ]

  ObjSpreadIdentifier: [
    o 'SimpleObjAssignable Accessor', $seq: [{$ast: 'Value', val: 1, $var: 'v'}, {$ops: 'value', add: [{$use: 'v'}, 2]}, {$use: 'v'}]
    o 'ObjSpreadExpr Accessor'      , $seq: [{$ast: 'Value', val: 1, $var: 'v'}, {$ops: 'value', add: [{$use: 'v'}, 2]}, {$use: 'v'}]
  ]

  # A return statement from a function body.
  Return: [
    o 'RETURN Expression'           , $ast: '@', base: 2
    o 'RETURN INDENT Object OUTDENT', $ast: '@', value: {$ast: 'Value'}
    o 'RETURN'                      , $ast: '@'
  ]

  YieldReturn: [
    o 'YIELD RETURN Expression', $ast: '@', expression: 3, returnKeyword: {$ast: 'Literal', value: 2, $pos: 2}
    o 'YIELD RETURN'           , $ast: '@', expression: null, returnKeyword: {$ast: 'Literal', value: 2, $pos: 2}
  ]

  AwaitReturn: [
    o 'AWAIT RETURN Expression', $ast: '@', expression: 3, returnKeyword: {$ast: 'Literal', value: 2, $pos: 2}
    o 'AWAIT RETURN'           , $ast: '@', expression: null, returnKeyword: {$ast: 'Literal', value: 2, $pos: 2}
  ]

  # The **Code** node is the function literal. It’s defined by an indented block
  # of **Block** preceded by a function arrow, with an optional parameter list.
  Code: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Block', $ast: '@', params: 2, body: 5, funcGlyph: 4, paramStart: {$ast: 'Literal', value: 1, $pos: 1}
    o 'FuncGlyph Block'                                , $ast: '@', params: [], body: 2, funcGlyph: 1
  ]

  # The Codeline is the **Code** node with **Line** instead of indented **Block**.
  CodeLine: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Line', $ast: 'Code', params: 2, body: [5], funcGlyph: 4, paramStart: {$ast: 'Literal', value: 1, $pos: 1}
    o 'FuncGlyph Line'                                , $ast: 'Code', params: [], body: [2], funcGlyph: 1
  ]

  # CoffeeScript has two different symbols for functions. `->` is for ordinary
  # functions, and `=>` is for functions bound to the current value of *this*.
  FuncGlyph: [
    o '->', $ast: '@', base: 1
    o '=>', $ast: '@', base: 1
  ]

  # An optional, trailing comma.
  OptComma: [
    o ''
    o ','
  ]

  # The list of parameters that a function accepts can be of any length.
  ParamList: [
    o ''                                                    , $ary: []
    o 'Param'                                               , $ary: [1]
    o 'ParamList , Param'                                   , $ops: 'array', append: [1, 3]
    o 'ParamList OptComma TERMINATOR Param'                 , $ops: 'array', append: [1, 4]
    o 'ParamList OptComma INDENT ParamList OptComma OUTDENT', $ops: 'array', append: [1, 4]
  ]

  # A single parameter in a function definition can be ordinary, or a splat
  # that hoovers up the remaining arguments.
  Param: [
    o 'ParamVar'             , $ast: '@', base: 1
    o 'ParamVar ...'         , $ast: '@', arg1: 1, arg2: null, arg3: on
    o '... ParamVar'         , $ast: '@', arg1: 2, arg2: null, arg3: 'postfix: no'
    o 'ParamVar = Expression', $ast: '@', first: 1, second: 3
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
    o 'Expression ...', $ast: '@', base: 1
    o '... Expression', $ast: '@', arg1: 2, arg2: '{postfix: no}'
  ]

  # Variables and properties that can be assigned to.
  SimpleAssignable: [
    o 'Identifier'    , $ast: 'Value', val: 1
    o 'Value Accessor', $ops: 'value', add: [1, 2]
    o 'Code Accessor' , $ast: 'Value', value: '$1).add $2'
    o 'ThisProperty'
  ]

  # Everything that can be assigned to.
  Assignable: [
    o 'SimpleAssignable'
    o 'Array'           , $ast: 'Value', val: 1
    o 'Object'          , $ast: 'Value', val: 1
  ]

  # The types of things that can be treated as values -- assigned to, invoked
  # as functions, indexed into, named as a class, etc.
  Value: [
    o 'Assignable'
    o 'Literal'      , $ast: '@', base: 1
    o 'Parenthetical', $ast: '@', base: 1
    o 'Range'        , $ast: '@', base: 1
    o 'Invocation'   , $ast: '@', base: 1
    o 'DoIife'       , $ast: '@', base: 1
    o 'This'
    o 'Super'        , $ast: '@', base: 1
    o 'MetaProperty' , $ast: '@', base: 1
  ]

  # A `super`-based expression that can be used as a value.
  Super: [
    o 'SUPER . Property'                                     , $ast: '@', accessor: {$ast: 'Access', name: 3, $pos: 3}, literal: {$ast: 'Literal', value: 1, $pos: 1}
    o 'SUPER INDEX_START Expression INDEX_END'               , $ast: '@', accessor: {$ast: 'Index', name: 3, $pos: 3}, literal: {$ast: 'Literal', value: 1, $pos: 1}
    o 'SUPER INDEX_START INDENT Expression OUTDENT INDEX_END', $ast: '@', accessor: {$ast: 'Index', name: 4, $pos: 4}, literal: {$ast: 'Literal', value: 1, $pos: 1}
  ]

  # A “meta-property” access e.g. `new.target` or `import.meta`, where
  # something that looks like a property is referenced on a keyword.
  MetaProperty: [
    o 'NEW_TARGET . Property' , $ast: '@', identifier: {$ast: 'IdentifierLiteral', value: 1, $pos: 1}, accessor: {$ast: 'Access', name: 3, $pos: 3}
    o 'IMPORT_META . Property', $ast: '@', identifier: {$ast: 'IdentifierLiteral', value: 1, $pos: 1}, accessor: {$ast: 'Access', name: 3, $pos: 3}
  ]

  # The general group of accessors into an object, by property, by prototype
  # or by array index or slice.
  Accessor: [
    o '.  Property' , $ast: 'Access', base: 2
    o '?. Property' , $ast: 'Access', arg1: 2, arg2: 'soak: yes'
    o ':: Property' , $ary: [{$ast: 'Access', name: {$ast: 'PropertyName', value: 'prototype'}, shorthand: true, $pos: 1}, {$ast: 'Access', name: 2, $pos: 2}]
    o '?:: Property', $ary: [{$ast: 'Access', name: {$ast: 'PropertyName', value: 'prototype'}, shorthand: true, soak: true, $pos: 1}, {$ast: 'Access', name: 2, $pos: 2}]
    o '::'          , $ast: 'Access', arg1: {$ast: 'PropertyName'}, arg2: 'shorthand: yes'
    o '?::'         , $ast: 'Access', arg1: {$ast: 'PropertyName'}, arg2: 'shorthand: yes', arg3: 'soak: yes'
    o 'Index'
  ]

  # Indexing into an object or array using bracket notation.
  Index: [
    o 'INDEX_START IndexValue INDEX_END'               , $use: 2
    o 'INDEX_START INDENT IndexValue OUTDENT INDEX_END', $use: 3
    o 'INDEX_SOAK  Index'                              , $ops: 'prop', set: {target: 2, property: 'soak', value: true}
  ]

  IndexValue: [
    o 'Expression', $ast: 'Index', base: 1
    o 'Slice'     , $ast: 'Slice', base: 1
  ]

  # In CoffeeScript, an object literal is simply a list of assignments.
  Object: [
    o '{ AssignList OptComma }', $ast: 'Obj', arg1: 2, arg2: {$use: 1, prop: 'generated'}
  ]

  # Assignment of properties within an object literal can be separated by
  # comma, as in JavaScript, or simply by newline.
  AssignList: [
    o ''                                                      , $ary: []
    o 'AssignObj'                                             , $ary: [1]
    o 'AssignList , AssignObj'                                , $ops: 'array', append: [1, 3]
    o 'AssignList OptComma TERMINATOR AssignObj'              , $ops: 'array', append: [1, 4]
    o 'AssignList OptComma INDENT AssignList OptComma OUTDENT', $ops: 'array', append: [1, 4]
  ]

  # Class definitions have optional bodies of prototype property assignments,
  # and optional references to the superclass.
  Class: [
    o 'CLASS'                                          , $ast: '@'
    o 'CLASS Block'                                    , $ast: '@', arg1: null, arg2: null, arg3: 2
    o 'CLASS EXTENDS Expression'                       , $ast: '@', arg1: null, arg2: 3
    o 'CLASS EXTENDS Expression Block'                 , $ast: '@', arg1: null, arg2: 3, arg3: 4
    o 'CLASS SimpleAssignable'                         , $ast: '@', base: 2
    o 'CLASS SimpleAssignable Block'                   , $ast: '@', arg1: 2, arg2: null, arg3: 3
    o 'CLASS SimpleAssignable EXTENDS Expression'      , $ast: '@', first: 2, second: 4
    o 'CLASS SimpleAssignable EXTENDS Expression Block', $ast: '@', first: 2, second: 4, third: 5
  ]

  Import: [
    o 'IMPORT String'                                                                             , $ast: 'ImportDeclaration', arg1: null, arg2: 2
    o 'IMPORT String ASSERT Object'                                                               , $ast: 'ImportDeclaration', arg1: null, arg2: 2, arg3: 4
    o 'IMPORT ImportDefaultSpecifier FROM String'                                                 , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: 'null)', arg3: 4
    o 'IMPORT ImportDefaultSpecifier FROM String ASSERT Object'                                   , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: 'null)', arg3: 4, arg4: 6
    o 'IMPORT ImportNamespaceSpecifier FROM String'                                               , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$2)', arg3: 4
    o 'IMPORT ImportNamespaceSpecifier FROM String ASSERT Object'                                 , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$2)', arg3: 4, arg4: 6
    o 'IMPORT { } FROM String'                                                                    , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: 5
    o 'IMPORT { } FROM String ASSERT Object'                                                      , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: 5, arg4: 7
    o 'IMPORT { ImportSpecifierList OptComma } FROM String'                                       , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: 7
    o 'IMPORT { ImportSpecifierList OptComma } FROM String ASSERT Object'                         , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: 7, arg4: 9
    o 'IMPORT ImportDefaultSpecifier , ImportNamespaceSpecifier FROM String'                      , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$4)', arg3: 6
    o 'IMPORT ImportDefaultSpecifier , ImportNamespaceSpecifier FROM String ASSERT Object'        , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: '$4)', arg3: 6, arg4: 8
    o 'IMPORT ImportDefaultSpecifier , { ImportSpecifierList OptComma } FROM String'              , $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: 9
    o 'IMPORT ImportDefaultSpecifier , { ImportSpecifierList OptComma } FROM String ASSERT Object', $ast: 'ImportDeclaration', arg1: {$ast: 'ImportClause'}, arg2: {$ast: 'ImportSpecifierList'}, arg3: 9, arg4: 11
  ]

  ImportSpecifierList: [
    o 'ImportSpecifier'                                                         , $ary: [1]
    o 'ImportSpecifierList , ImportSpecifier'                                   , $ops: 'array', append: [1, 3]
    o 'ImportSpecifierList OptComma TERMINATOR ImportSpecifier'                 , $ops: 'array', append: [1, 4]
    o 'INDENT ImportSpecifierList OptComma OUTDENT'                             , $use: 2
    o 'ImportSpecifierList OptComma INDENT ImportSpecifierList OptComma OUTDENT', $ops: 'array', append: [1, 4]
  ]

  ImportSpecifier: [
    o 'Identifier'              , $ast: '@', base: 1
    o 'Identifier AS Identifier', $ast: '@', first: 1, second: 3
    o 'DEFAULT'                 , $ast: '@', value: {$ast: 'DefaultLiteral'}
    o 'DEFAULT AS Identifier'   , $ast: '@', arg1: {$ast: 'DefaultLiteral'}, arg2: 3
  ]

  ImportDefaultSpecifier: [
    o 'Identifier', $ast: '@', base: 1
  ]

  ImportNamespaceSpecifier: [
    o 'IMPORT_ALL AS Identifier', $ast: '@', arg1: {$ast: 'Literal'}, arg2: 3
  ]

  Export: [
    o 'EXPORT { }'                                                       , $ast: 'ExportNamedDeclaration', value: {$ast: 'ExportSpecifierList'}
    o 'EXPORT { ExportSpecifierList OptComma }'                          , $ast: 'ExportNamedDeclaration', value: {$ast: 'ExportSpecifierList'}
    o 'EXPORT Class'                                                     , $ast: 'ExportNamedDeclaration', base: 2
    o 'EXPORT Identifier = Expression'                                   , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'Assign'}, arg2: 4, arg3: null, arg4: {moduleDeclaration: 'export'}
    o 'EXPORT Identifier = TERMINATOR Expression'                        , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'Assign'}, arg2: 5, arg3: null, arg4: {moduleDeclaration: 'export'}
    o 'EXPORT Identifier = INDENT Expression OUTDENT'                    , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'Assign'}, arg2: 5, arg3: null, arg4: {moduleDeclaration: 'export'}
    o 'EXPORT DEFAULT Expression'                                        , $ast: 'ExportDefaultDeclaration', base: 3
    o 'EXPORT DEFAULT INDENT Object OUTDENT'                             , $ast: 'ExportDefaultDeclaration', value: {$ast: 'Value'}
    o 'EXPORT EXPORT_ALL FROM String'                                    , $ast: 'ExportAllDeclaration', arg1: {$ast: 'Literal'}, arg2: 4
    o 'EXPORT EXPORT_ALL FROM String ASSERT Object'                      , $ast: 'ExportAllDeclaration', arg1: {$ast: 'Literal'}, arg2: 4, arg3: 6
    o 'EXPORT { } FROM String'                                           , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: 5
    o 'EXPORT { } FROM String ASSERT Object'                             , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: 5, arg3: 7
    o 'EXPORT { ExportSpecifierList OptComma } FROM String'              , $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: 7
    o 'EXPORT { ExportSpecifierList OptComma } FROM String ASSERT Object', $ast: 'ExportNamedDeclaration', arg1: {$ast: 'ExportSpecifierList'}, arg2: 7, arg3: 9
  ]

  ExportSpecifierList: [
    o 'ExportSpecifier'                                                         , $ary: [1]
    o 'ExportSpecifierList , ExportSpecifier'                                   , $ops: 'array', append: [1, 3]
    o 'ExportSpecifierList OptComma TERMINATOR ExportSpecifier'                 , $ops: 'array', append: [1, 4]
    o 'INDENT ExportSpecifierList OptComma OUTDENT'                             , $use: 2
    o 'ExportSpecifierList OptComma INDENT ExportSpecifierList OptComma OUTDENT', $ops: 'array', append: [1, 4]
  ]

  ExportSpecifier: [
    o 'Identifier'              , $ast: '@', base: 1
    o 'Identifier AS Identifier', $ast: '@', first: 1, second: 3
    o 'Identifier AS DEFAULT'   , $ast: '@', local: 1, exported: {$ast: 'DefaultLiteral', value: 3, $pos: 3}
    o 'DEFAULT'                 , $ast: '@', value: {$ast: 'DefaultLiteral'}
    o 'DEFAULT AS Identifier'   , $ast: '@', arg1: {$ast: 'DefaultLiteral'}, arg2: 3
  ]

  # Ordinary function invocation, or a chained series of calls.
  Invocation: [
    o 'Value OptFuncExist String'   , $ast: 'TaggedTemplateCall', arg1: 1, arg2: 3, arg3: {$use: 2, prop: 'soak'}
    o 'Value OptFuncExist Arguments', $ast: 'Call', arg1: 1, arg2: 3, arg3: {$use: 2, prop: 'soak'}
    o 'SUPER OptFuncExist Arguments', $ast: 'SuperCall', arg1: {$ast: 'Super'}, arg2: 3, arg3: {$use: 2, prop: 'soak'}, arg4: 1
    o 'DYNAMIC_IMPORT Arguments'    , $ast: 'DynamicImportCall', arg1: {$ast: 'DynamicImport'}, arg2: 2
  ]

  # An optional existence check on a function.
  OptFuncExist: [
    o ''          , soak: false
    o 'FUNC_EXIST', soak: true
  ]

  # The list of arguments to a function call.
  Arguments: [
    o 'CALL_START CALL_END'                 , $ary: [{}]
    o 'CALL_START ArgList OptComma CALL_END', $seq: [{$ops: 'prop', set: {target: 2, property: 'implicit', value: {$use: 1, prop: 'generated'}}}, 2]
  ]

  # A reference to the *this* current object.
  This: [
    o 'THIS', $ast: 'Value', value: {$ast: 'ThisLiteral'}
    o '@'   , $ast: 'Value', value: {$ast: 'ThisLiteral'}
  ]

  # A reference to a property on *this*.
  ThisProperty: [
    o '@ Property', $ast: 'Value', val: {$ast: 'ThisLiteral'}, properties: [{$ast: 'Access', name: 2}], bareLiteral: {$ast: 'ThisLiteral'}
  ]

  # The array literal.
  Array: [
    o '[ ]'                           , $ast: 'Arr', value: {$ary: [{}]}
    o '[ Elisions ]'                  , $ast: 'Arr', base: 2
    o '[ ArgElisionList OptElisions ]', $ast: 'Arr', arg1: '[].concat $2', arg2: 3
  ]

  # Inclusive and exclusive range dots.
  RangeDots: [
    o '..' , exclusive: false
    o '...', exclusive: true
  ]

  # The CoffeeScript range literal.
  Range: [
    o '[ Expression RangeDots Expression ]'    , $ast: '@', arg1: 2, arg2: 4, arg3: 'if $3.exclusive then \'exclusive\' else \'inclusive\''
    o '[ ExpressionLine RangeDots Expression ]', $ast: '@', arg1: 2, arg2: 4, arg3: 'if $3.exclusive then \'exclusive\' else \'inclusive\''
  ]

  # Array slice literals.
  Slice: [
    o 'Expression RangeDots Expression'    , $ast: 'Range', arg1: 1, arg2: 3, arg3: 'if $2.exclusive then \'exclusive\' else \'inclusive\''
    o 'Expression RangeDots'               , $ast: 'Range', arg1: 1, arg2: null, arg3: 'if $2.exclusive then \'exclusive\' else \'inclusive\''
    o 'ExpressionLine RangeDots Expression', $ast: 'Range', arg1: 1, arg2: 3, arg3: 'if $2.exclusive then \'exclusive\' else \'inclusive\''
    o 'ExpressionLine RangeDots'           , $ast: 'Range', arg1: 1, arg2: null, arg3: 'if $2.exclusive then \'exclusive\' else \'inclusive\''
    o 'RangeDots Expression'               , $ast: 'Range', arg1: null, arg2: 2, arg3: 'if $1.exclusive then \'exclusive\' else \'inclusive\''
    o 'RangeDots'                          , $ast: 'Range', arg1: null, arg2: null, arg3: 'if $1.exclusive then \'exclusive\' else \'inclusive\''
  ]

  # The **ArgList** is the list of objects passed into a function call
  # (i.e. comma-separated expressions). Newlines work as well.
  ArgList: [
    o 'Arg'                                             , $ary: [1]
    o 'ArgList , Arg'                                   , $ops: 'array', append: [1, 3]
    o 'ArgList OptComma TERMINATOR Arg'                 , $ops: 'array', append: [1, 4]
    o 'INDENT ArgList OptComma OUTDENT'                 , $use: 2
    o 'ArgList OptComma INDENT ArgList OptComma OUTDENT', $ops: 'array', append: [1, 4]
  ]

  # Valid arguments are Blocks or Splats.
  Arg: [
    o 'Expression'
    o 'ExpressionLine'
    o 'Splat'
    o '...'           , $ast: 'Expansion'
  ]

  # The **ArgElisionList** is the list of objects, contents of an array literal
  # (i.e. comma-separated expressions and elisions). Newlines work as well.
  ArgElisionList: [
    o 'ArgElision'
    o 'ArgElisionList , ArgElision'                                         , $ops: 'array', append: [1, 3]
    o 'ArgElisionList OptComma TERMINATOR ArgElision'                       , $ops: 'array', append: [1, 4]
    o 'INDENT ArgElisionList OptElisions OUTDENT'                           , $ops: 'array', append: [2, 3]
    o 'ArgElisionList OptElisions INDENT ArgElisionList OptElisions OUTDENT', $ops: 'array', gather: [1, 2, 4, 5]
  ]

  ArgElision: [
    o 'Arg'         , $ary: [1]
    o 'Elisions Arg', $ops: 'array', append: [1, 2]
  ]

  OptElisions: [
    o 'OptComma'  , $ary: [{}]
    o ', Elisions', $ops: 'array', gather: [[], 2]
  ]

  Elisions: [
    o 'Elision'         , $ary: [1]
    o 'Elisions Elision', $ops: 'array', append: [1, 2]
  ]

  Elision: [
    o ','                 , $ast: '@'
    o 'Elision TERMINATOR', $use: 1
  ]

  # Just simple, comma-separated, required arguments (no fancy syntax). We need
  # this to be separate from the **ArgList** for use in **Switch** blocks, where
  # having the newlines wouldn't make sense.
  SimpleArgs: [
    o 'Expression'
    o 'ExpressionLine'
    o 'SimpleArgs , Expression'    , $ops: 'array', gather: [1, 3]
    o 'SimpleArgs , ExpressionLine', $ops: 'array', gather: [1, 3]
  ]

  # The variants of *try/catch/finally* exception handling blocks.
  Try: [
    o 'TRY Block'                    , $ast: '@', base: 2
    o 'TRY Block Catch'              , $ast: '@', first: 2, second: 3
    o 'TRY Block FINALLY Block'      , $ast: '@', attempt: 2, catch: null, ensure: 4, finallyTag: {$ast: 'Literal', value: 3}
    o 'TRY Block Catch FINALLY Block', $ast: '@', attempt: 2, catch: 3, ensure: 5, finallyTag: {$ast: 'Literal', value: 4}
  ]

  # A catch clause names its error and runs a block of code.
  Catch: [
    o 'CATCH Identifier Block', $ast: '@', first: 3, second: 2
    o 'CATCH Object Block'    , $ast: '@', body: 3, errorVariable: {$ast: 'Value', val: 2}
    o 'CATCH Block'           , $ast: '@', base: 2
  ]

  # Throw an exception object.
  Throw: [
    o 'THROW Expression'           , $ast: '@', base: 2
    o 'THROW INDENT Object OUTDENT', $ast: '@', value: {$ast: 'Value'}
  ]

  # Parenthetical expressions. Note that the **Parenthetical** is a **Value**,
  # not an **Expression**, so if you need to use an expression in a place
  # where only values are accepted, wrapping it in parentheses will always do
  # the trick.
  Parenthetical: [
    o '( Body )'               , $ast: 'Parens', base: 2
    o '( INDENT Body OUTDENT )', $ast: 'Parens', base: 3
  ]

  # The condition portion of a while loop.
  WhileLineSource: [
    o 'WHILE ExpressionLine'                    , $ast: 'While', condition: 2
    o 'WHILE ExpressionLine WHEN ExpressionLine', $ast: 'While', condition: 2, guard: 4
    o 'UNTIL ExpressionLine'                    , $ast: 'While', condition: 2, invert: true
    o 'UNTIL ExpressionLine WHEN ExpressionLine', $ast: 'While', condition: 2, invert: true, guard: 4
  ]

  WhileSource: [
    o 'WHILE Expression'                    , $ast: 'While', condition: 2
    o 'WHILE Expression WHEN Expression'    , $ast: 'While', condition: 2, guard: 4
    o 'WHILE ExpressionLine WHEN Expression', $ast: 'While', condition: 2, guard: 4
    o 'UNTIL Expression'                    , $ast: 'While', condition: 2, invert: true
    o 'UNTIL Expression WHEN Expression'    , $ast: 'While', condition: 2, invert: true, guard: 4
    o 'UNTIL ExpressionLine WHEN Expression', $ast: 'While', condition: 2, invert: true, guard: 4
  ]

  # The while loop can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression. There is no do..while.
  While: [
    o 'WhileSource Block'     , $ops: 'loop', addBody: [1, 'Body $2']
    o 'WhileLineSource Block' , $ops: 'loop', addBody: [1, 'Body $2']
    o 'Statement  WhileSource', $seq: [{$ops: 'prop', set: {target: 2, property: 'postfix', value: true}}, {$ops: 'loop', addBody: [2, [1]]}, 2]
    o 'Expression WhileSource', $seq: [{$ops: 'prop', set: {target: 2, property: 'postfix', value: true}}, {$ops: 'loop', addBody: [2, [1]]}, 2]
    o 'Loop'                  , $use: 1
  ]

  Loop: [
    o 'LOOP Block'     , $ast: 'While', condition: {$ast: 'BooleanLiteral', value: 'true'}, isLoop: true, body: 2
    o 'LOOP Expression', $ast: 'While', condition: {$ast: 'BooleanLiteral', value: 'true'}, isLoop: true, body: [2]
  ]

  # Array, object, and range comprehensions, at the most generic level.
  # Comprehensions can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression.
  For: [
    o 'Statement    ForBody', $seq: [{$ops: 'prop', set: {target: 2, property: 'postfix', value: true}}, {$ops: 'loop', addBody: [2, 1]}, 2]
    o 'Expression   ForBody', $seq: [{$ops: 'prop', set: {target: 2, property: 'postfix', value: true}}, {$ops: 'loop', addBody: [2, 1]}, 2]
    o 'ForBody      Block'  , $ops: 'loop', addBody: [1, 'Body $2']
    o 'ForLineBody  Block'  , $ops: 'loop', addBody: [1, 'Body $2']
  ]

  ForBody: [
    o 'FOR Range'              , $ast: 'For', body: {$ary: []}, source: {$ast: 'Value', val: 2, $pos: 2}
    o 'FOR Range BY Expression', $ast: 'For', body: {$ary: []}, source: {$ast: 'Value', val: 2, $pos: 2}, step: 4
    o 'ForStart ForSource'     , $ops: 'loop', addSource: [1, 'Source $2']
  ]

  ForLineBody: [
    o 'FOR Range BY ExpressionLine', $ast: 'For', body: {$ary: []}, source: {$ast: 'Value', val: 2, $pos: 2}, step: 4
    o 'ForStart ForLineSource'     , $ops: 'loop', addSource: [1, 'Source $2']
  ]

  ForStart: [
    o 'FOR ForVariables'      , $ast: 'For', arg1: {$ary: [{}]}, arg2: 'name: $2[0]', arg3: 'index: $2[1]'
    o 'FOR AWAIT ForVariables', $seq: [{$var: 'name', value: {$use: 3, index: 0}}, {$var: 'index', value: {$use: 3, index: 1}}, {$ast: 'For', body: {$ary: []}, name: {$use: 'name'}, index: {$use: 'index'}, await: true, awaitTag: {$ast: 'Literal', value: 2, $pos: 2}}]
    o 'FOR OWN ForVariables'  , $seq: [{$var: 'name', value: {$use: 3, index: 0}}, {$var: 'index', value: {$use: 3, index: 1}}, {$ast: 'For', body: {$ary: []}, name: {$use: 'name'}, index: {$use: 'index'}, own: true, ownTag: {$ast: 'Literal', value: 2, $pos: 2}}]
  ]

  # An array of all accepted values for a variable inside the loop.
  # This enables support for pattern matching.
  ForValue: [
    o 'Identifier'
    o 'ThisProperty'
    o 'Array'       , $ast: 'Value', val: 1
    o 'Object'      , $ast: 'Value', val: 1
  ]

  # An array or range comprehension has variables for the current element
  # and (optional) reference to the current index. Or, *key, value*, in the case
  # of object comprehensions.
  ForVariables: [
    o 'ForValue'           , $ary: [1]
    o 'ForValue , ForValue', $ary: [1, 3]
  ]

  # The source of a comprehension is an array or object with an optional guard
  # clause. If it’s an array comprehension, you can also choose to step through
  # in fixed-size increments.
  ForSource: [
    o 'FORIN Expression'                                      , source: 2
    o 'FOROF Expression'                                      , source: 2, object: true
    o 'FORIN Expression WHEN Expression'                      , source: 2, guard: 4
    o 'FORIN ExpressionLine WHEN Expression'                  , source: 2, guard: 4
    o 'FOROF Expression WHEN Expression'                      , source: 2, guard: 4, object: true
    o 'FOROF ExpressionLine WHEN Expression'                  , source: 2, guard: 4, object: true
    o 'FORIN Expression BY Expression'                        , source: 2, step: 4
    o 'FORIN ExpressionLine BY Expression'                    , source: 2, step: 4
    o 'FORIN Expression WHEN Expression BY Expression'        , source: 2, guard: 4, step: 6
    o 'FORIN ExpressionLine WHEN Expression BY Expression'    , source: 2, guard: 4, step: 6
    o 'FORIN Expression WHEN ExpressionLine BY Expression'    , source: 2, guard: 4, step: 6
    o 'FORIN ExpressionLine WHEN ExpressionLine BY Expression', source: 2, guard: 4, step: 6
    o 'FORIN Expression BY Expression WHEN Expression'        , source: 2, step: 4, guard: 6
    o 'FORIN ExpressionLine BY Expression WHEN Expression'    , source: 2, step: 4, guard: 6
    o 'FORIN Expression BY ExpressionLine WHEN Expression'    , source: 2, step: 4, guard: 6
    o 'FORIN ExpressionLine BY ExpressionLine WHEN Expression', source: 2, step: 4, guard: 6
    o 'FORFROM Expression'                                    , source: 2, from: true
    o 'FORFROM Expression WHEN Expression'                    , source: 2, guard: 4, from: true
    o 'FORFROM ExpressionLine WHEN Expression'                , source: 2, guard: 4, from: true
  ]

  ForLineSource: [
    o 'FORIN ExpressionLine'                                      , source: 2
    o 'FOROF ExpressionLine'                                      , source: 2, object: true
    o 'FORIN Expression WHEN ExpressionLine'                      , source: 2, guard: 4
    o 'FORIN ExpressionLine WHEN ExpressionLine'                  , source: 2, guard: 4
    o 'FOROF Expression WHEN ExpressionLine'                      , source: 2, guard: 4, object: true
    o 'FOROF ExpressionLine WHEN ExpressionLine'                  , source: 2, guard: 4, object: true
    o 'FORIN Expression BY ExpressionLine'                        , source: 2, step: 4
    o 'FORIN ExpressionLine BY ExpressionLine'                    , source: 2, step: 4
    o 'FORIN Expression WHEN Expression BY ExpressionLine'        , source: 2, guard: 4, step: 6
    o 'FORIN ExpressionLine WHEN Expression BY ExpressionLine'    , source: 2, guard: 4, step: 6
    o 'FORIN Expression WHEN ExpressionLine BY ExpressionLine'    , source: 2, guard: 4, step: 6
    o 'FORIN ExpressionLine WHEN ExpressionLine BY ExpressionLine', source: 2, guard: 4, step: 6
    o 'FORIN Expression BY Expression WHEN ExpressionLine'        , source: 2, step: 4, guard: 6
    o 'FORIN ExpressionLine BY Expression WHEN ExpressionLine'    , source: 2, step: 4, guard: 6
    o 'FORIN Expression BY ExpressionLine WHEN ExpressionLine'    , source: 2, step: 4, guard: 6
    o 'FORIN ExpressionLine BY ExpressionLine WHEN ExpressionLine', source: 2, step: 4, guard: 6
    o 'FORFROM ExpressionLine'                                    , source: 2, from: true
    o 'FORFROM Expression WHEN ExpressionLine'                    , source: 2, guard: 4, from: true
    o 'FORFROM ExpressionLine WHEN ExpressionLine'                , source: 2, guard: 4, from: true
  ]

  Switch: [
    o 'SWITCH Expression INDENT Whens OUTDENT'               , $ast: '@', first: 2, second: 4
    o 'SWITCH ExpressionLine INDENT Whens OUTDENT'           , $ast: '@', first: 2, second: 4
    o 'SWITCH Expression INDENT Whens ELSE Block OUTDENT'    , $ast: '@', subject: 2, cases: 4, otherwise: 6, $pos: [5, 6]
    o 'SWITCH ExpressionLine INDENT Whens ELSE Block OUTDENT', $ast: '@', subject: 2, cases: 4, otherwise: 6, $pos: [5, 6]
    o 'SWITCH INDENT Whens OUTDENT'                          , $ast: '@', arg1: null, arg2: 3
    o 'SWITCH INDENT Whens ELSE Block OUTDENT'               , $ast: '@', subject: null, cases: 3, otherwise: 5, $pos: [4, 5]
  ]

  Whens: [
    o 'When'      , $ary: [1]
    o 'Whens When', $ops: 'array', append: [1, 2]
  ]

  # An individual **When** clause, with action.
  When: [
    o 'LEADING_WHEN SimpleArgs Block'           , $ast: 'SwitchWhen', first: 2, second: 3
    o 'LEADING_WHEN SimpleArgs Block TERMINATOR', $ast: 'SwitchWhen', conditions: 2, body: 3, $pos: [1, 3]
  ]

  # The most basic form of *if* is a condition and an action. The following
  # if-related rules are broken up along these lines in order to avoid
  # ambiguity.
  IfBlock: [
    o 'IF Expression Block'             , $ast: 'If', condition: 2, body: 3, type: 1
    o 'IfBlock ELSE IF Expression Block', $ops: 'if', addElse: [1, {$ast: 'If', condition: 4, body: 5, type: 3, $pos: [3, 5]}]
  ]

  # The full complement of *if* expressions, including postfix one-liner
  # *if* and *unless*.
  If: [
    o 'IfBlock'
    o 'IfBlock ELSE Block'           , $ops: 'if', addElse: [1, 3]
    o 'Statement  POST_IF Expression', $ast: '@', condition: 3, body: [1], type: 2, postfix: true
    o 'Expression POST_IF Expression', $ast: '@', condition: 3, body: [1], type: 2, postfix: true
  ]

  IfBlockLine: [
    o 'IF ExpressionLine Block'                 , $ast: 'If', condition: 2, body: 3, type: 1
    o 'IfBlockLine ELSE IF ExpressionLine Block', $ops: 'if', addElse: [1, {$ast: 'If', condition: 4, body: 5, type: 3, $pos: [3, 5]}]
  ]

  IfLine: [
    o 'IfBlockLine'
    o 'IfBlockLine ELSE Block'           , $ops: 'if', addElse: [1, 3]
    o 'Statement  POST_IF ExpressionLine', $ast: 'If', condition: 3, body: [1], type: 2, postfix: true
    o 'Expression POST_IF ExpressionLine', $ast: 'If', condition: 3, body: [1], type: 2, postfix: true
  ]

  # Arithmetic and logical operators, working on one or more operands.
  # Here they are grouped by order of precedence. The actual precedence rules
  # are defined at the bottom of the page. It would be shorter if we could
  # combine most of these rules into a single generic *Operand OpSymbol Operand*
  # -type rule, but in order to make the precedence binding possible, separate
  # rules are necessary.
  OperationLine: [
    o 'UNARY ExpressionLine', $ast: 'Op', args: [1, 2]
    o 'DO ExpressionLine'   , $ast: 'Op', args: [1, 2]
    o 'DO_IIFE CodeLine'    , $ast: 'Op', args: [1, 2]
  ]

  Operation: [
    o 'UNARY Expression'              , $ast: 'Op', args: [{$use: 1, method: 'toString'}, 2, undefined, undefined], originalOperator: {$use: 1, prop: 'original'}
    o 'DO Expression'                 , $ast: 'Op', args: [1, 2]
    o 'UNARY_MATH Expression'         , $ast: 'Op', args: [1, 2]
    o '-     Expression'              , {$ast: 'Op', args: ['-', 2]}, prec: 'UNARY_MATH'
    o '+     Expression'              , {$ast: 'Op', args: ['+', 2]}, prec: 'UNARY_MATH'

    o 'AWAIT Expression'              , $ast: 'Op', args: [1, 2]
    o 'AWAIT INDENT Object OUTDENT'   , $ast: 'Op', args: [1, 3]

    o '-- SimpleAssignable'           , $ast: 'Op', args: ['--', 2]
    o '++ SimpleAssignable'           , $ast: 'Op', args: ['++', 2]
    o 'SimpleAssignable --'           , $ast: 'Op', args: ['--', 1, null, true]
    o 'SimpleAssignable ++'           , $ast: 'Op', args: ['++', 1, null, true]

    # [The existential operator](https://coffeescript.org/#existential-operator).
    o 'Expression ?'                  , $ast: 'Existence', base: 1

    o 'Expression +  Expression'      , $ast: 'Op', args: ['+', 1, 3]
    o 'Expression -  Expression'      , $ast: 'Op', args: ['-', 1, 3]

    o 'Expression MATH     Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression **       Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression SHIFT    Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression COMPARE  Expression', $ast: 'Op', args: [{$use: 2, method: 'toString'}, 1, 3, undefined], originalOperator: {$use: 2, prop: 'original'}
    o 'Expression &        Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression ^        Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression |        Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression &&       Expression', $ast: 'Op', args: [{$use: 2, method: 'toString'}, 1, 3, undefined], originalOperator: {$use: 2, prop: 'original'}
    o 'Expression ||       Expression', $ast: 'Op', args: [{$use: 2, method: 'toString'}, 1, 3, undefined], originalOperator: {$use: 2, prop: 'original'}
    o 'Expression BIN?     Expression', $ast: 'Op', args: [2, 1, 3]
    o 'Expression RELATION Expression', $ast: 'Op', args: [{$use: 2, method: 'toString'}, 1, 3, undefined], invertOperator: {$ite: {test: {$use: 2, prop: 'invert', prop2: 'original'}, then: {$use: 2, prop: 'invert', prop2: 'original'}, else: {$use: 2, prop: 'invert'}}}

    o 'SimpleAssignable COMPOUND_ASSIGN
       Expression'                             , $ast: 'Assign', variable: 1, value: 3, operator: {$use: 2, method: 'toString'}, originalContext: {$use: 2, prop: 'original'}
    o 'SimpleAssignable COMPOUND_ASSIGN
       INDENT Expression OUTDENT'              , $ast: 'Assign', variable: 1, value: 4, operator: {$use: 2, method: 'toString'}, originalContext: {$use: 2, prop: 'original'}
    o 'SimpleAssignable COMPOUND_ASSIGN TERMINATOR
       Expression'                             , $ast: 'Assign', variable: 1, value: 4, operator: {$use: 2, method: 'toString'}, originalContext: {$use: 2, prop: 'original'}
  ]

  DoIife: [
    o 'DO_IIFE Code', $ast: 'Op', args: [1, 2]
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