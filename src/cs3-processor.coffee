#!/usr/bin/env coffee

# ==============================================================================
# CS3 Data Node Processor - Process data nodes and generate output
# ==============================================================================

class CS3Processor
  constructor: ->
    @indent = 0
    @indentStr = '  '

  # Main entry point
  process: (node, params = []) ->
    return '' unless node

    # If it's a string, return as is
    return node if typeof node is 'string'

    # If it's an array, process each element
    if Array.isArray(node)
      return (@process(item, params) for item in node).join('')

    # Process based on node directives
    if node.$ref?
      return @processReference(node, params)

    if node.$type?
      return @processType(node, params)

    if node.$array?
      return @processArray(node, params)

    if node.$op?
      return @processOperation(node, params)

    if node.$cond?
      return @processConditional(node, params)

    if node.$seq?
      return @processSequence(node, params)

    # Plain object
    return @processPlainObject(node, params)

  # Process reference node
  processReference: (node, params) ->
    # Get the referenced parameter
    value = params[node.$ref - 1] if node.$ref <= params.length

    # Handle property access
    if node.prop and value?
      value = value[node.prop]

    # Handle method calls
    if node.call and value?
      if typeof value[node.call] is 'function'
        args = node.args or []
        value = value[node.call].apply(value, args)
      else
        value = value[node.call]

    value or ''

  # Process type node (AST node creation)
  processType: (node, params) ->
    # For now, we'll create a simple object representation
    # In the real implementation, this would create actual AST nodes
    result =
      type: node.$type

    # Process all properties
    for key, value of node when key isnt '$type' and key isnt '$pos'
      result[key] = @process(value, params)

    result

  # Process array node
  processArray: (node, params) ->
    if Array.isArray(node.$array)
      # Simple array
      return (@process(item, params) for item in node.$array)
    else if node.$array.$concat?
      # Array concatenation
      result = []
      for arr in node.$array.$concat
        processed = @process(arr, params)
        if Array.isArray(processed)
          result = result.concat(processed)
        else
          result.push(processed)
      return result
    else
      return []

  # Process operation node
  processOperation: (node, params) ->
    target = @process(node.target, params) if node.target
    args = (@process(arg, params) for arg in node.args) if node.args

    # Handle different operations
    switch node.$op
      when 'addBody'
        target.body = args[0] if target and args?[0]
        return target
      when 'push'
        target.push(args[0]) if target?.push and args?[0]
        return target
      when 'concat'
        return if target?.concat then target.concat(args...) else target
      when 'Block.wrap'
        # Create a wrapped block
        return {type: 'Block', statements: args[0] or [], implicit: true}
      when 'extend'
        # Extend object
        Object.assign(args[0], args[1]) if args?[0] and args?[1]
        return args[0]
      else
        # Generic operation - try to call method on target
        if target?[node.$op]
          return target[node.$op].apply(target, args)
        else
          return target

  # Process conditional node
  processConditional: (node, params) ->
    test = @process(node.$cond.test, params)

    if test
      return @process(node.$cond.then, params)
    else
      return @process(node.$cond.else, params)

  # Process sequence node
  processSequence: (node, params) ->
    results = []
    context = {}

    for step in node.$seq
      # Handle temporary variable assignment
      if step.$as
        result = @process(step, params)
        context[step.$as] = result
        results.push(result)
      # Handle temporary variable usage
      else if step.$use
        results.push(context[step.$use])
      else
        results.push(@process(step, params))

    # Return last result
    results[results.length - 1]

  # Process plain object
  processPlainObject: (node, params) ->
    result = {}
    for key, value of node when not key.startsWith('$')
      result[key] = @process(value, params)
    result

# Export the processor
module.exports = CS3Processor

# Test if run directly
if require.main is module
  processor = new CS3Processor()

  # Test with some sample nodes
  tests = [
    {$ref: 1}
    {$ref: 2, prop: 'value'}
    {$type: 'Value', base: {$ref: 1}, properties: []}
    {$array: [{$ref: 1}, {$ref: 2}]}
    {$op: 'push', target: {$ref: 1}, args: [{$ref: 2}]}
  ]

  params = [{name: 'x', value: 42}, {name: 'y', value: 17}]

  console.log "CS3 Processor Tests:"
  console.log "-" .repeat 40

  for test in tests
    result = processor.process(test, params)
    console.log "Node:", JSON.stringify(test)
    console.log "Result:", result
    console.log()
