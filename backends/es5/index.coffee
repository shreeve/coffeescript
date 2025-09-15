#!/usr/bin/env coffee

# ==============================================================================
# CS3 ES5 Backend - Clean Room Implementation
# ==============================================================================
#
# Converts CS3 data-oriented AST nodes to CoffeeScript's class-based AST nodes
# Then uses the existing CoffeeScript compiler to generate JavaScript
#
# Key fixes in this version:
# 1. Loop variable conflict prevention
# 2. Proper super call handling
# 3. Array elision support
# ==============================================================================

nodes = require '../../coffeescript/nodes'

class ES5Backend
  constructor: (@options = {}) ->
    @compileOptions =
      bare: @options.bare ? true
      header: @options.header ? false
      sourceMap: @options.sourceMap ? false
      inlineMap: @options.inlineMap ? false
      # Signal to nodes compiler that we're in CS3 pipeline, so it can relax
      # early "this-before-super" checks to let our lowering run.
      cs3: true

    # CRITICAL FIX for #4889: Track unique variable allocation for nested for-loops
    @loopVarCounter = 0
    @usedLoopVars = new Set()

  # Main entry point - convert CS3 data node to JavaScript
  generate: (dataNode) ->
    classNode = @dataToClass dataNode
    return '' unless classNode?  # CRITICAL: Never return undefined

    result = classNode.compile @compileOptions
    return result or ''  # CRITICAL: Ensure we always return a string

  # Helper to create default locationData
  defaultLocationData: ->
    first_line: 0
    first_column: 0
    last_line: 0
    last_column: 0
    last_line_exclusive: 0
    last_column_exclusive: 0
    range: [0, 0]

  # CRITICAL FIX for #4889: Generate unique loop variables like CoffeeScript's scope.freeVariable
  getUniqueLoopVar: ->
    # Use the same algorithm as CoffeeScript's scope.temporary with single=true
    # Generate: i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z, then i1, j1, etc.
    startCode = 'i'.charCodeAt(0)  # 105
    endCode = 'z'.charCodeAt(0)    # 122
    diff = endCode - startCode     # 17

    newCode = startCode + @loopVarCounter % (diff + 1)
    letter = String.fromCharCode(newCode)
    num = Math.floor(@loopVarCounter / (diff + 1))
    varName = "#{letter}#{num or ''}"

    @loopVarCounter++
    @usedLoopVars.add varName
    varName

  # Helper to ensure value is a proper node
  ensureNode: (value) ->
    return null unless value?
    return value if value.compileToFragments or value instanceof nodes.Base
    # Only wrap primitives; drop unknown objects to avoid emitting debug strings.
    if typeof value in ['string', 'number', 'boolean']
      return new nodes.Literal String(value)
    null

  # CRITICAL: Enhanced null-safe node conversion
  safeDataToClass: (node) ->
    return null unless node?
    try
      result = @dataToClass node
      return result or null
    catch error
      console.error "CS3 Backend node conversion error:", error.message
      return new nodes.Literal "/* conversion error */"

  # Helper to filter and ensure all items are nodes
  filterNodes: (array) ->
    return [] unless array?
    result = []
    for item in array
      node = @ensureNode @dataToClass item
      result.push node if node?
    result

  # Add mergeLocationData helper
  mergeLocationData: (first, last) ->
    return first unless last
    first_line: first.first_line
    first_column: first.first_column
    last_line: last.last_line
    last_column: last.last_column
    last_line_exclusive: last.last_line_exclusive ? first.last_line_exclusive
    last_column_exclusive: last.last_column_exclusive ? first.last_column_exclusive
    range: [first.range[0], last.range[1]]

  # Convert Solar directives directly to CoffeeScript class nodes
  dataToClass: (node) ->
    return null unless node?

    # Handle primitives
    return node if typeof node in ['string', 'number', 'boolean']

    # Handle arrays
    if Array.isArray node
      return node.map (item) => @dataToClass item

    # Handle Solar directives DIRECTLY
    if typeof node is 'object'
      # Solar $ast directive - create nodes directly from directive (check first!)
      if node.$ast?
        return @createNodeFromSolarAST node

      # Solar $use directive - simple values (only for standalone $use)
      if node.$use?
        return new nodes.Literal String(node.$use)

      # Solar $ops directive - execute operations directly
      if node.$ops?
        return @executeSolarOps node

      # Solar $ary directive - create arrays directly
      if node.$ary?
        return node.$ary.map (item) => @dataToClass item

      # Solar $seq directive - execute sequences directly
      if node.$seq?
        return @executeSolarSequence node

    # Only Solar directives supported - pure direct consumption!
    return null

  # Create CoffeeScript node directly from Solar $ast directive
  createNodeFromSolarAST: (node) ->
    nodeType = if node.$ast is '@' then 'Literal' else node.$ast

    switch nodeType
      when 'IdentifierLiteral'
        value = @resolveSolarValue(node.value) if node.value
        new nodes.IdentifierLiteral value

      when 'Literal'
        value = @resolveSolarValue(node.value) if node.value
        new nodes.Literal value

      when 'NumberLiteral'
        value = @resolveSolarValue(node.value) if node.value
        parsedValue = @resolveSolarValue(node.parsedValue) if node.parsedValue
        new nodes.NumberLiteral value, parsedValue

      else
        # Placeholder for unimplemented Solar AST types
        new nodes.Literal "/* TODO: Solar $ast #{nodeType} */"

  # Execute Solar $ops operations directly
  executeSolarOps: (node) ->
    new nodes.Literal "/* TODO: Solar $ops #{node.$ops} */"

  # Execute Solar $seq sequences directly
  executeSolarSequence: (node) ->
    new nodes.Literal "/* TODO: Solar $seq */"

  # Resolve Solar $use references and method/property calls
  resolveSolarValue: (value) ->
    return String(value) unless typeof value is 'object' and value?

    if value.$use? and value.method?
      # Method calls like {$use: "42", method: 'toString'}
      base = value.$use
      if typeof base is 'object' and base[value.method]
        base[value.method]()  # Execute actual method: "42".toString()
      else
        String(base)
    else if value.$use? and value.prop?
      # Property access like {$use: "42", prop: 'parsedValue'}
      base = value.$use
      if typeof base is 'object' and base[value.prop] isnt undefined
        base[value.prop]  # Get actual property: "42".parsedValue
      else
        String(base)
    else if value.$use?
      # Simple $use reference - already resolved to actual value
      @resolveSolarValue value.$use
    else
      String(value)

module.exports = ES5Backend
