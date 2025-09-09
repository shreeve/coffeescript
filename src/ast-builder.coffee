#!/usr/bin/env coffee

# ==============================================================================
# AST Builder - Data-oriented AST node creation for CoffeeScript
#
# This module provides factory functions that create plain JavaScript objects
# representing AST nodes, similar to Babel/ESTree format, replacing the
# class-based approach.
# ==============================================================================

# Helper to add location data to nodes
addLocationData = (node, first, last) ->
  node.loc =
    first: first
    last: last
  node

# Helper to create a node with common properties
createNode = (type, props = {}) ->
  node = { type, ...props }
  # Add source location if available
  if props.loc
    node.loc = props.loc
    delete props.loc
  node

# ==============================================================================
# Core Node Types
# ==============================================================================

# Program root
exports.Root = (body) ->
  createNode 'Root',
    body: body

# Block of statements
exports.Block = (statements = []) ->
  createNode 'Block',
    statements: statements

# Wraps statements in a block
exports.BlockWrap = (statements) ->
  createNode 'Block',
    statements: statements
    implicit: true

# ==============================================================================
# Literals
# ==============================================================================

exports.Literal = (value, props = {}) ->
  createNode 'Literal',
    value: value
    raw: props.raw ? value
    ...props

exports.NumberLiteral = (value, parsedValue) ->
  createNode 'NumberLiteral',
    value: value
    parsedValue: parsedValue ? parseFloat(value)

exports.StringLiteral = (value, props = {}) ->
  createNode 'StringLiteral',
    value: value
    quote: props.quote
    double: props.double
    heregex: props.heregex

exports.BooleanLiteral = (value, originalValue) ->
  createNode 'BooleanLiteral',
    value: value is 'true' or value is true
    raw: originalValue ? value

exports.NullLiteral = (token) ->
  createNode 'NullLiteral',
    value: null
    raw: token

exports.UndefinedLiteral = (token) ->
  createNode 'UndefinedLiteral',
    value: undefined
    raw: token

exports.ThisLiteral = (token) ->
  createNode 'ThisLiteral',
    raw: token

exports.IdentifierLiteral = (name) ->
  createNode 'IdentifierLiteral',
    name: name

# ==============================================================================
# Expressions
# ==============================================================================

exports.Value = (base, properties = []) ->
  createNode 'Value',
    base: base
    properties: properties

exports.Assign = (left, right, operator = '=', props = {}) ->
  createNode 'AssignmentExpression',
    left: left
    right: right
    operator: operator
    moduleDeclaration: props.moduleDeclaration

exports.Op = (operator, left, right = null, flip = false, props = {}) ->
  node = createNode 'Operation',
    operator: operator
    originalOperator: props.originalOperator ? operator

  if right?
    node.left = if flip then right else left
    node.right = if flip then left else right
    node.binary = true
  else
    node.argument = left
    node.unary = true
    node.prefix = not flip

  node

exports.Existence = (expression) ->
  createNode 'ExistenceCheck',
    argument: expression

# ==============================================================================
# Control Flow
# ==============================================================================

exports.If = (test, consequent, alternate = null, props = {}) ->
  createNode 'IfStatement',
    test: test
    consequent: consequent
    alternate: alternate
    type: props.type ? 'if'
    postfix: props.postfix ? false

exports.While = (test, body = null, props = {}) ->
  createNode 'WhileStatement',
    test: test
    body: body
    guard: props.guard
    invert: props.invert ? false
    postfix: props.postfix ? false
    isLoop: props.isLoop ? false

exports.For = (body = null, props = {}) ->
  createNode 'ForStatement',
    body: body
    name: props.name
    index: props.index
    source: props.source
    guard: props.guard
    step: props.step
    object: props.object ? false
    await: props.await ? false
    own: props.own ? false
    postfix: props.postfix ? false

exports.Switch = (discriminant, cases, alternate = null) ->
  createNode 'SwitchStatement',
    discriminant: discriminant
    cases: cases
    alternate: alternate

exports.SwitchWhen = (tests, consequent) ->
  createNode 'SwitchCase',
    tests: tests
    consequent: consequent

exports.Try = (block, handler = null, finalizer = null, finalizerToken = null) ->
  createNode 'TryStatement',
    block: block
    handler: handler
    finalizer: finalizer
    finalizerToken: finalizerToken

exports.Catch = (body, param = null) ->
  createNode 'CatchClause',
    param: param
    body: body

exports.Throw = (argument) ->
  createNode 'ThrowStatement',
    argument: argument

exports.Return = (argument = null) ->
  createNode 'ReturnStatement',
    argument: argument

# ==============================================================================
# Functions
# ==============================================================================

exports.Code = (params, body, funcGlyph, paramStart) ->
  createNode 'Function',
    params: params ? []
    body: body
    bound: funcGlyph?.glyph is '=>'
    generator: false  # Will be determined by traversal
    async: false      # Will be determined by traversal
    paramStart: paramStart

exports.FuncGlyph = (glyph) ->
  createNode 'FuncGlyph',
    glyph: glyph

exports.Param = (name, defaultValue = null, splat = false, props = {}) ->
  createNode 'Parameter',
    name: name
    default: defaultValue
    splat: splat
    postfix: props.postfix ? true

exports.Splat = (expression, props = {}) ->
  createNode 'SpreadElement',
    argument: expression
    postfix: props.postfix ? true

exports.Expansion = ->
  createNode 'Expansion'

# ==============================================================================
# Objects and Arrays
# ==============================================================================

exports.Obj = (properties, generated = false) ->
  createNode 'ObjectExpression',
    properties: properties
    generated: generated

exports.Arr = (elements) ->
  createNode 'ArrayExpression',
    elements: elements

exports.Access = (name, props = {}) ->
  createNode 'MemberAccess',
    name: name
    soak: props.soak ? false
    shorthand: props.shorthand ? false

exports.Index = (index) ->
  createNode 'ComputedMemberAccess',
    index: index

exports.Range = (from, to, exclusive) ->
  createNode 'Range',
    from: from
    to: to
    exclusive: exclusive is 'exclusive'

exports.Slice = (range) ->
  createNode 'Slice',
    range: range

# ==============================================================================
# Classes
# ==============================================================================

exports.Class = (name = null, parent = null, body = null) ->
  createNode 'ClassExpression',
    name: name
    superClass: parent
    body: body

# ==============================================================================
# Modules
# ==============================================================================

exports.ImportDeclaration = (specifiers, source, assertions = null) ->
  createNode 'ImportDeclaration',
    specifiers: specifiers
    source: source
    assertions: assertions

exports.ExportNamedDeclaration = (declaration, specifiers = null, source = null, assertions = null) ->
  createNode 'ExportNamedDeclaration',
    declaration: declaration
    specifiers: specifiers
    source: source
    assertions: assertions

exports.ExportDefaultDeclaration = (declaration) ->
  createNode 'ExportDefaultDeclaration',
    declaration: declaration

# ==============================================================================
# Other Nodes
# ==============================================================================

exports.Call = (callee, args, soak = false) ->
  createNode 'CallExpression',
    callee: callee
    arguments: args
    soak: soak

exports.Super = (accessor = null, token = null) ->
  createNode 'Super',
    accessor: accessor
    token: token

exports.Parens = (body) ->
  createNode 'ParenthesizedExpression',
    expression: body

exports.StringWithInterpolations = (body, props = {}) ->
  createNode 'TemplateLiteral',
    quasis: []
    expressions: body
    quote: props.quote
    startQuote: props.startQuote

exports.Interpolation = (expression) ->
  createNode 'TemplateElement',
    expression: expression

exports.RegexLiteral = (pattern, props = {}) ->
  createNode 'RegexLiteral',
    pattern: pattern
    delimiter: props.delimiter
    flags: props.flags

exports.Yield = (argument = null, delegate = false) ->
  createNode 'YieldExpression',
    argument: argument
    delegate: delegate

exports.YieldReturn = (argument = null, returnKeyword = null) ->
  createNode 'YieldReturn',
    argument: argument
    returnKeyword: returnKeyword

exports.AwaitReturn = (argument = null, returnKeyword = null) ->
  createNode 'AwaitReturn',
    argument: argument
    returnKeyword: returnKeyword

# ==============================================================================
# Compatibility Layer
# ==============================================================================

# This provides a bridge between the old class-based API and the new data API
# It allows gradual migration by wrapping data nodes with class-like behavior

class NodeWrapper
  constructor: (@node) ->
    # Copy node properties to wrapper for compatibility
    for own key, value of @node
      this[key] = value

  # Compile method delegates to a visitor pattern
  compileNode: (o) ->
    require('./compiler').compile @node, o

  # Traverse children
  traverseChildren: (crossScope, func) ->
    require('./compiler').traverse @node, crossScope, func

  # Check node type
  isStatement: ->
    @node.type in ['Root', 'Block', 'ReturnStatement', 'ThrowStatement',
                  'ClassExpression', 'ImportDeclaration', 'ExportNamedDeclaration']

# Export a function to wrap data nodes with class-like behavior
exports.wrap = (node) ->
  new NodeWrapper node

# ==============================================================================
# Grammar Helper with Data Nodes
# ==============================================================================

# Modified 'o' function that uses data node builders instead of classes
exports.o = (patternString, action, options) ->
  patternString = patternString.replace /\s{2,}/g, ' '

  if action
    # Transform action to use our data node builders
    actionStr = action.toString()

    # Replace new ClassName(...) with exports.ClassName(...)
    actionStr = actionStr.replace /new\s+(\w+)/g, (match, className) ->
      "ast.#{className}"

    # Replace Block.wrap with ast.BlockWrap
    actionStr = actionStr.replace /Block\.wrap/g, 'ast.BlockWrap'

    # Create new function with ast builders in scope
    action = new Function 'ast', '$1', '$2', '$3', '$4', '$5', '$6', "$$ = #{actionStr}; return $$;"

    performActionFunctionString = "
      var ast = require('./ast-builder');
      #{action.toString().replace('anonymous', 'action')}
      $$ = action(ast, $1, $2, $3, $4, $5, $6);
    "
  else
    performActionFunctionString = '$$ = $1;'

  [patternString, performActionFunctionString, options]
