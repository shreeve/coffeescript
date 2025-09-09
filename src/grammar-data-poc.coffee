#!/usr/bin/env coffee

# ==============================================================================
# Proof of Concept: Data-oriented Grammar for CoffeeScript
#
# This demonstrates how the grammar would look using data nodes instead of
# class instantiation. This is a subset to prove the concept works.
# ==============================================================================

# Helper function for creating grammar rules with data nodes
o = (patternString, action, options) ->
  patternString = patternString.replace /\s{2,}/g, ' '
  patternCount = patternString.split(' ').length

  if action
    # Convert the action function to return data nodes
    actionStr = if typeof action is 'function'
      action.toString().replace(/^[^{]*{|}$/g, '').trim()
    else
      action

    # The action will have access to position variables $1, $2, etc
    # and helper functions like n() for creating nodes
    performActionFunctionString = actionStr
  else
    performActionFunctionString = '$$ = $1;'

  [patternString, performActionFunctionString, options]

# Node creation helper - creates plain objects with type field
n = (type, props = {}) ->
  { type, ...props }

# Block wrapping helper
wrapBlock = (statements) ->
  n 'Block', statements: statements, implicit: true

# ==============================================================================
# Grammar Rules (Subset for POC)
# ==============================================================================

grammar =

  # Top level
  Root: [
    o '', -> n 'Root', body: n('Block', statements: [])
    o 'Body', -> n 'Root', body: $1
  ]

  Body: [
    o 'Line', -> wrapBlock [$1]
    o 'Body TERMINATOR Line', ->
      $1.statements.push $3
      $1
    o 'Body TERMINATOR', -> $1
  ]

  Line: [
    o 'Expression'
    o 'Statement'
  ]

  Statement: [
    o 'Return'
    o 'STATEMENT', -> n 'StatementLiteral', value: $1
  ]

  Expression: [
    o 'Value'
    o 'Operation'
    o 'Assign'
    o 'If'
  ]

  # Values and literals
  Value: [
    o 'Assignable', -> n 'Value', base: $1, properties: []
    o 'Literal', -> n 'Value', base: $1, properties: []
    o 'Value Accessor', ->
      $1.properties.push $2
      $1
  ]

  Literal: [
    o 'AlphaNumeric'
    o 'UNDEFINED', -> n 'UndefinedLiteral', raw: $1
    o 'NULL', -> n 'NullLiteral', raw: $1
    o 'BOOL', -> n 'BooleanLiteral', value: $1 is 'true', raw: $1
  ]

  AlphaNumeric: [
    o 'NUMBER', -> n 'NumberLiteral', value: $1, parsedValue: parseFloat($1)
    o 'String'
  ]

  String: [
    o 'STRING', -> n 'StringLiteral',
      value: $1[1...-1]  # Remove quotes
      quote: $1[0]
      raw: $1
  ]

  # Identifiers and properties
  Identifier: [
    o 'IDENTIFIER', -> n 'IdentifierLiteral', name: $1
  ]

  Property: [
    o 'PROPERTY', -> n 'PropertyName', value: $1
  ]

  Accessor: [
    o '. Property', -> n 'Access', name: $2, soak: false
    o '?. Property', -> n 'Access', name: $2, soak: true
  ]

  # Assignment
  Assign: [
    o 'Assignable = Expression', -> n 'Assignment',
      left: $1
      right: $3
      operator: '='
    o 'Assignable = INDENT Expression OUTDENT', -> n 'Assignment',
      left: $1
      right: $4
      operator: '='
  ]

  SimpleAssignable: [
    o 'Identifier', -> n 'Value', base: $1, properties: []
    o 'Value Accessor', ->
      $1.properties.push $2
      $1
  ]

  Assignable: [
    o 'SimpleAssignable'
    o 'Array', -> n 'Value', base: $1, properties: []
    o 'Object', -> n 'Value', base: $1, properties: []
  ]

  # Arrays and Objects
  Array: [
    o '[ ]', -> n 'ArrayExpression', elements: []
    o '[ ArgList ]', -> n 'ArrayExpression', elements: $2
  ]

  Object: [
    o '{ }', -> n 'ObjectExpression', properties: []
    o '{ AssignList }', -> n 'ObjectExpression', properties: $2
  ]

  ArgList: [
    o 'Expression', -> [$1]
    o 'ArgList , Expression', -> $1.concat [$3]
  ]

  AssignList: [
    o 'Property : Expression', -> [n 'Property', key: $1, value: $3]
    o 'AssignList , Property : Expression', ->
      $1.concat [n 'Property', key: $3, value: $5]
  ]

  # Operations
  Operation: [
    o 'UNARY Expression', -> n 'UnaryOperation',
      operator: $1
      argument: $2
      prefix: true

    o 'Expression + Expression', -> n 'BinaryOperation',
      operator: '+'
      left: $1
      right: $3

    o 'Expression - Expression', -> n 'BinaryOperation',
      operator: '-'
      left: $1
      right: $3

    o 'Expression COMPARE Expression', -> n 'BinaryOperation',
      operator: $2
      left: $1
      right: $3

    o 'Expression ?', -> n 'ExistenceCheck', argument: $1
  ]

  # Control flow
  If: [
    o 'IF Expression Block', -> n 'IfStatement',
      test: $2
      consequent: $3
      alternate: null
      postfix: false

    o 'IF Expression Block ELSE Block', -> n 'IfStatement',
      test: $2
      consequent: $3
      alternate: $5
      postfix: false

    o 'Expression POST_IF Expression', -> n 'IfStatement',
      test: $3
      consequent: wrapBlock [$1]
      alternate: null
      postfix: true
  ]

  Block: [
    o 'INDENT OUTDENT', -> n 'Block', statements: []
    o 'INDENT Body OUTDENT', -> $2
  ]

  Return: [
    o 'RETURN Expression', -> n 'ReturnStatement', argument: $2
    o 'RETURN', -> n 'ReturnStatement', argument: null
  ]

# ==============================================================================
# Operator Precedence (same as original)
# ==============================================================================

operators = [
  ['left',      '.', '?.']
  ['right',     'UNARY']
  ['left',      '+', '-']
  ['left',      'COMPARE']
  ['left',      '?']
  ['right',     '=']
  ['right',     'IF', 'ELSE', 'POST_IF']
]

# ==============================================================================
# Export for parser generator
# ==============================================================================

# Transform grammar to parser generator format
for own name, alternatives of grammar
  grammar[name] = for alt in alternatives
    # Add return statement for Root rule
    alt[1] = "return #{alt[1]}" if name is 'Root'
    alt

module.exports =
  bnf: grammar
  operators: operators.reverse()

  # Module include for runtime support
  moduleInclude: """
    // Node creation helper
    function n(type, props) {
      return Object.assign({type: type}, props || {});
    }

    // Block wrapper helper
    function wrapBlock(statements) {
      return n('Block', {statements: statements, implicit: true});
    }
  """

  # Action include for semantic actions
  actionInclude: ->
    # Any shared functions needed by actions
    parseFloat = global.parseFloat
