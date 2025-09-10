#!/usr/bin/env coffee

# ==============================================================================
# CS3 Pattern Matcher V2 - Transform Class-based AST to Data-oriented Nodes
#
# Fixed version without infinite recursion
# ==============================================================================

class CS3PatternMatcher
  constructor: ->
    # Map node types to their expected properties
    @nodeSignatures =
      # Core Structure
      Root: ['body']
      Block: ['statements']
      Code: ['params', 'body', 'bound', 'isGenerator', 'isAsync']
      Param: ['name', 'value', 'splat']

      # Values & Literals
      Value: ['base', 'properties']
      IdentifierLiteral: ['value']
      NumberLiteral: ['value', 'parsedValue']
      PassthroughLiteral: ['value', 'here', 'generated']
      PropertyName: ['value']

      # Operations
      Assign: ['variable', 'value', 'context', 'options']
      Op: ['operator', 'first', 'second', 'flip', 'options']
      Call: ['variable', 'args', 'soak', 'token']
      Access: ['name', 'soak', 'shorthand']

  # Transform a complete action string
  transformAction: (actionStr) ->
    return null unless actionStr

    # Handle special cases
    return {$ref: 1} if actionStr is '<passthrough>'

    # Handle simple references first
    if match = actionStr.match(/^\$(\d+)$/)
      return {$ref: parseInt(match[1])}

    # Handle property access
    if match = actionStr.match(/^\$(\d+)\.(\w+)$/)
      return {$ref: parseInt(match[1]), prop: match[2]}

    # Handle method calls on references
    if match = actionStr.match(/^\$(\d+)\.(\w+)\((.*)\)$/)
      args = if match[3] then @parseArgs(match[3]) else []
      return {$ref: parseInt(match[1]), call: match[2], args: @transformArgs(args)}

    # Handle arrays
    if match = actionStr.match(/^\[(.*)\]$/)
      elements = if match[1] then @parseArgs(match[1]) else []
      return {$array: @transformArgs(elements)}

    # Handle array concat
    if match = actionStr.match(/^\[\]\.concat\s+(.+)$/)
      args = @parseArgs(match[1])
      return {$array: @transformArgs(args)}

    # Handle class instantiation (including nested)
    if match = actionStr.match(/^new\s+(\w+)(?:\s+(.+)|\s*\((.*)\))?$/)
      className = match[1]
      # Either positional arguments (new Foo arg1, arg2) or parenthesized (new Foo(arg1, arg2))
      argsStr = match[2] or match[3] or ''
      return @transformClassInstantiation(className, argsStr)

    # Handle simple values
    return true if actionStr is 'yes' or actionStr is 'true'
    return false if actionStr is 'no' or actionStr is 'false'

    # Handle string literals
    if match = actionStr.match(/^["'](.*)["']$/)
      return match[1]

    # Handle number literals
    if match = actionStr.match(/^-?\d+(\.\d+)?$/)
      return parseFloat(actionStr)

    # Handle object literals (simplified)
    if actionStr.match(/^\{.*\}$/)
      return @parseObject(actionStr)

    # Default: return as is (likely a symbol or complex expression)
    actionStr

  # Transform class instantiation to data node
  transformClassInstantiation: (className, argsStr) ->
    node = {$type: className}

    # Parse arguments if present
    if argsStr
      args = @parseArgs(argsStr)
      signature = @nodeSignatures[className]

      if signature
        # Map positional args to named properties
        for arg, i in args when i < signature.length
          propName = signature[i]
          node[propName] = @transformAction(arg)
      else
        # Unknown node type, use generic props
        node.args = @transformArgs(args)

    node

  # Transform array of arguments
  transformArgs: (args) ->
    args.map (arg) => @transformAction(arg)

  # Parse comma-separated arguments (handles nested parens, brackets, braces)
  parseArgs: (argsStr) ->
    return [] unless argsStr?.trim()

    args = []
    current = ''
    depth = 0
    inString = false
    stringChar = null

    for char, i in argsStr
      if inString
        current += char
        if char is stringChar and argsStr[i-1] isnt '\\'
          inString = false
          stringChar = null
      else
        if char in ['"', "'"]
          inString = true
          stringChar = char
          current += char
        else if char in ['(', '[', '{']
          depth++
          current += char
        else if char in [')', ']', '}']
          depth--
          current += char
        else if char is ',' and depth is 0
          args.push current.trim()
          current = ''
        else
          current += char

    args.push current.trim() if current.trim()
    args

  # Parse object literal (simplified)
  parseObject: (objStr) ->
    # Remove outer braces
    content = objStr.slice(1, -1).trim()
    return {} unless content

    obj = {}
    # Very simplified parsing - would need proper parser for complex objects
    pairs = @parseArgs(content)

    for pair in pairs
      if match = pair.match(/(\w+):\s*(.+)/)
        key = match[1]
        value = @transformAction(match[2])
        obj[key] = value

    obj

# Export for use
module.exports = CS3PatternMatcher

# Quick test if run directly
if require.main is module
  matcher = new CS3PatternMatcher()

  tests = [
    'new IdentifierLiteral $1'
    'new Root new Block'
    'new Value $1'
    'new Op $1, $2'
    'new Assign $1, $2, $3'
    'new Call $1, $3, $4'
    '$1'
    '$2.properties'
    '[]'
    '[$1]'
    '[$1, $2]'
    '[].concat $1, $2'
    'yes'
    'no'
    '"string"'
    '42'
    '<passthrough>'
  ]

  console.log "CS3 Pattern Matcher V2 Tests:"
  console.log "------------------------------"
  for test in tests
    try
      result = matcher.transformAction(test)
      console.log "✓ #{test}"
      console.log "  →", JSON.stringify(result)
    catch e
      console.log "✗ #{test}"
      console.log "  Error:", e.message
    console.log()
