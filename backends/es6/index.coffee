#!/usr/bin/env coffee

# ==============================================================================
# CS3 ES6 Backend - Generate ES6 JavaScript from Data Nodes
# ==============================================================================

class ES6Backend
  constructor: (options = {}) ->
    @indent = 0
    @indentStr = options.indent or '  '
    @useStrict = options.useStrict ? false
    @sourceMap = options.sourceMap ? false
    @output = []

  # Generate JS from data node
  generate: (node) ->
    @output = []
    @indent = 0

    # Add use strict if needed
    if @useStrict
      @output.push "'use strict';"
      @output.push ''

    # Process the root node
    result = @processNode(node)

    # Add result to output if it's a string
    if typeof result is 'string' and result
      @output.push result

    # Return generated code
    @output.join('\n')

  # Process any node
  processNode: (node, context = {}) ->
    return '' unless node

    # Handle primitive values
    return node if typeof node in ['string', 'number', 'boolean']

    # Handle arrays
    if Array.isArray(node)
      return (@processNode(item, context) for item in node)

    # Process based on node type
    if node.$type
      return @processTypeNode(node, context)

    if node.$ref
      return @processRefNode(node, context)

    if node.$array
      return @processArrayNode(node, context)

    if node.$op
      return @processOpNode(node, context)

    if node.$cond
      return @processCondNode(node, context)

    if node.$seq
      return @processSeqNode(node, context)

    # If it has a type property (processed node)
    if node.type
      return @processASTNode(node, context)

    # Plain object
    return node

  # Process type nodes (create AST nodes)
  processTypeNode: (node, context) ->
    # Create an AST node representation
    astNode =
      type: node.$type

    # Process all other properties
    for key, value of node when key isnt '$type' and key isnt '$pos'
      astNode[key] = @processNode(value, context)

    astNode

  # Process reference nodes
  processRefNode: (node, context) ->
    # In actual implementation, this would reference parser parameters
    # For now, return a placeholder
    "$#{node.$ref}"

  # Process array nodes
  processArrayNode: (node, context) ->
    items = node.$array or []
    (@processNode(item, context) for item in items)

  # Process operation nodes
  processOpNode: (node, context) ->
    # This would handle various operations
    op: node.$op
    target: @processNode(node.target, context) if node.target
    args: (@processNode(arg, context) for arg in node.args) if node.args

  # Process conditional nodes
  processCondNode: (node, context) ->
    test: @processNode(node.$cond.test, context)
    then: @processNode(node.$cond.then, context)
    else: @processNode(node.$cond.else, context)

  # Process sequence nodes
  processSeqNode: (node, context) ->
    results = []
    for step in node.$seq
      results.push @processNode(step, context)
    results

  # Process actual AST nodes (after initial processing)
  processASTNode: (node, context) ->
    switch node.type
      when 'Root'
        @generateRoot(node, context)
      when 'Block'
        @generateBlock(node, context)
      when 'Code'
        @generateFunction(node, context)
      when 'Param'
        @generateParam(node, context)
      when 'Value'
        @generateValue(node, context)
      when 'IdentifierLiteral'
        @generateIdentifier(node, context)
      when 'NumberLiteral'
        @generateNumber(node, context)
      when 'PassthroughLiteral'
        @generatePassthrough(node, context)
      when 'PropertyName'
        @generateProperty(node, context)
      when 'Assign'
        @generateAssignment(node, context)
      when 'Op'
        @generateOperation(node, context)
      when 'Call'
        @generateCall(node, context)
      when 'Access'
        @generateAccess(node, context)
      else
        "/* Unknown node type: #{node.type} */"

  # Generate Root node
  generateRoot: (node, context) ->
    if node.body
      @processNode(node.body, context)

  # Generate Block node
  generateBlock: (node, context) ->
    if node.statements
      results = []
      for stmt in node.statements
        code = @processNode(stmt, context)
        results.push code if code
      results.join(";\n")
    else
      ''

  # Generate Function node
  generateFunction: (node, context) ->
    params = if node.params
      (@processNode(param, context) for param in node.params).join(', ')
    else
      ''

    body = if node.body
      bodyCode = @processNode(node.body, context)
      if typeof bodyCode is 'string'
        bodyCode
      else
        'return ' + bodyCode
    else
      ''

    if node.bound
      "(#{params}) => {\n#{@indentCode(body)}\n}"
    else
      "function(#{params}) {\n#{@indentCode(body)}\n}"

  # Generate Parameter node
  generateParam: (node, context) ->
    name = @processNode(node.name, context)

    if node.splat
      if node.postfix is false
        "...#{name}"
      else
        "#{name}..."
    else if node.value
      "#{name} = #{@processNode(node.value, context)}"
    else
      name

  # Generate Value node
  generateValue: (node, context) ->
    base = @processNode(node.base, context)

    if node.properties and node.properties.length > 0
      for prop in node.properties
        access = @processNode(prop, context)
        if typeof access is 'string' and access.startsWith('[')
          base += access
        else
          base += ".#{access}"

    base

  # Generate Identifier node
  generateIdentifier: (node, context) ->
    node.value or ''

  # Generate Number node
  generateNumber: (node, context) ->
    node.value or '0'

  # Generate Passthrough node
  generatePassthrough: (node, context) ->
    node.value or ''

  # Generate Property node
  generateProperty: (node, context) ->
    node.value or ''

  # Generate Assignment node
  generateAssignment: (node, context) ->
    variable = @processNode(node.variable, context)
    value = @processNode(node.value, context)

    if node.context is 'object'
      "#{variable}: #{value}"
    else
      op = node.context or '='
      "#{variable} #{op} #{value}"

  # Generate Operation node
  generateOperation: (node, context) ->
    operator = node.operator
    first = @processNode(node.first, context)
    second = @processNode(node.second, context)

    # Handle unary operators
    if not second and operator in ['!', '~', 'typeof', 'delete']
      return "#{operator}#{first}"

    # Handle binary operators
    if operator in ['+', '-', '*', '/', '%', '**', '==', '!=', '===', '!==',
                     '<', '>', '<=', '>=', '&&', '||', '&', '|', '^', '<<', '>>', '>>>']
      return "#{first} #{operator} #{second}"

    # Special operators
    switch operator
      when 'in'
        "#{first} in #{second}"
      when 'of'
        "#{first} of #{second}"
      when 'instanceof'
        "#{first} instanceof #{second}"
      else
        "#{first} #{operator} #{second}"

  # Generate Call node
  generateCall: (node, context) ->
    func = @processNode(node.variable, context)

    args = if node.args
      argList = (@processNode(arg, context) for arg in node.args)
      argList.join(', ')
    else
      ''

    "#{func}(#{args})"

  # Generate Access node
  generateAccess: (node, context) ->
    name = @processNode(node.name, context)

    if node.shorthand
      "@#{name}"
    else if typeof name is 'string' and name.match(/^[a-zA-Z_$][a-zA-Z0-9_$]*$/)
      ".#{name}"
    else
      "[#{name}]"

  # Helper to indent code
  indentCode: (code) ->
    lines = code.split('\n')
    indented = for line in lines
      if line.trim()
        @indentStr + line
      else
        line
    indented.join('\n')

# Export the backend
module.exports = ES6Backend

# Test if run directly
if require.main is module
  backend = new ES6Backend(useStrict: true)

  # Test with sample nodes
  tests = [
    {
      type: 'Root'
      body:
        type: 'Block'
        statements: [
          {
            type: 'Assign'
            variable: {type: 'IdentifierLiteral', value: 'x'}
            value: {type: 'NumberLiteral', value: '42'}
          }
        ]
    }
    {
      type: 'Code'
      params: [{type: 'Param', name: {type: 'IdentifierLiteral', value: 'x'}}]
      body:
        type: 'Op'
        operator: '*'
        first: {type: 'IdentifierLiteral', value: 'x'}
        second: {type: 'IdentifierLiteral', value: 'x'}
    }
  ]

  console.log "ES6 Backend Tests:"
  console.log "=" .repeat 40

  for test in tests
    console.log "Input:"
    console.log JSON.stringify(test, null, 2)
    console.log()
    console.log "Output:"
    console.log backend.generate(test)
    console.log()
    console.log "-" .repeat 40
