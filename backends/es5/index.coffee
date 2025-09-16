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

  # Main entry point - convert Solar directive or CoffeeScript node to JavaScript
  generate: (node) ->
    # If already a CoffeeScript class node (from ReductionFrame), compile directly
    if node?.compile
      result = node.compile @compileOptions
      return result or ''

    # Otherwise, convert via legacy dataToClass method
    classNode = @dataToClass node
    return '' unless classNode?

    result = classNode.compile @compileOptions
    return result or ''

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

  # ReductionFrame-based Solar directive evaluation
  reduce: (ruleName, directive, frame) ->
    # Evaluate Solar directive against ReductionFrame
    @evaluateDirective directive, frame, ruleName

  # Core directive evaluator - evaluates Solar directives against RHS frame
  evaluateDirective: (directive, frame, ruleName = null) ->
    # Handle position references (1, 2, 3, ...) FIRST
    if typeof directive is 'number'
      return frame.rhs[directive - 1]?.value  # 1-based → 0-based

    # Handle primitives (except numbers, handled above)
    return directive if typeof directive in ['string', 'boolean']

    # Handle arrays
    if Array.isArray directive
      return directive.map (item) => @evaluateDirective item, frame, ruleName

    # Handle Solar directives
    if directive? and typeof directive is 'object'

      # $use directive (with optional method/prop)
      if directive.$use?
        ref = directive.$use
        value = if typeof ref is 'number'
          frame.rhs[ref - 1]?.value  # Position reference
        else
          ref  # Direct value or temp variable

        # Apply method calls
        if directive.method?
          args = directive.args?.map((arg) => @evaluateDirective arg, frame) or []
          value?[directive.method]?.apply(value, args) or String(value)
        # Apply property access
        else if directive.prop?
          value?[directive.prop] or String(value)
        else
          value

      # $ast directive (AST node creation)
      else if directive.$ast?
        nodeType = if directive.$ast is '@' then ruleName else directive.$ast

        # Directly create CoffeeScript node with evaluated properties
        switch nodeType
          when 'IdentifierLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            new nodes.IdentifierLiteral value

          when 'Literal'
            value = @evaluateDirective directive.value, frame, ruleName
            new nodes.Literal value

          when 'NumberLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            parsedValue = @evaluateDirective directive.parsedValue, frame, ruleName
            new nodes.NumberLiteral value, parsedValue

          when 'Assign'
            variable = @evaluateDirective directive.variable, frame, ruleName
            value = @evaluateDirective directive.value, frame, ruleName
            context = @evaluateDirective directive.context, frame, ruleName
            new nodes.Assign variable, value, context

          else
            # For unimplemented types, create placeholder
            new nodes.Literal "/* TODO: Solar #{nodeType} */"

      # $ary directive (array creation)
      else if directive.$ary?
        directive.$ary.map (item) => @evaluateDirective item, frame, ruleName

      # $ops directive (operations)
      else if directive.$ops?
        @applyOperation directive, frame, ruleName

      # $seq directive (sequences)
      else if directive.$seq?
        result = null
        for step in directive.$seq
          result = @evaluateDirective step, frame, ruleName
        result

      # $ite directive (conditionals)
      else if directive.$ite?
        test = @evaluateDirective directive.$ite.test, frame, ruleName
        if test
          @evaluateDirective directive.$ite.then, frame, ruleName
        else
          @evaluateDirective directive.$ite.else, frame, ruleName

      # Plain object (evaluate properties)
      else
        result = {}
        for key, value of directive when not key.startsWith '$'
          result[key] = @evaluateDirective value, frame, ruleName
        result
    else
      directive

  # Convert evaluated Solar node to CoffeeScript class (Phase A: Legacy adapter)
  solarNodeToClass: (solarNode) ->
    return null unless solarNode?.type

    switch solarNode.type
      when 'IdentifierLiteral'
        new nodes.IdentifierLiteral solarNode.value

      when 'Literal'
        new nodes.Literal solarNode.value

      when 'NumberLiteral'
        new nodes.NumberLiteral solarNode.value, solarNode.parsedValue

      when 'Op'
        first = @solarNodeToClass solarNode.left if solarNode.left
        second = @solarNodeToClass solarNode.right if solarNode.right
        new nodes.Op solarNode.operator, first, second, solarNode.flip

      when 'Assign'
        variable = @solarNodeToClass solarNode.variable if solarNode.variable
        value = @solarNodeToClass solarNode.value if solarNode.value
        new nodes.Assign variable, value, solarNode.context

      else
        # Placeholder for unimplemented node types
        new nodes.Literal "/* TODO: Solar node #{solarNode.type} */"

  # Resolve $pos directive to locationData
  resolvePosition: (posDirective, frame) ->
    if typeof posDirective is 'number'
      # $pos: 1 → copy slot 1's position
      frame.rhs[posDirective - 1]?.pos or @defaultLocationData()
    else if Array.isArray posDirective
      if posDirective.length is 2
        # $pos: [1, 3] → span from slot 1 to slot 3
        start = frame.rhs[posDirective[0] - 1]?.pos
        end = frame.rhs[posDirective[1] - 1]?.pos
        @mergeLocationData(start, end) if start and end
      else if posDirective.length is 4
        # $pos: [sl, sc, el, ec] → explicit position
        [startLine, startCol, endLine, endCol] = posDirective
        first_line: startLine, first_column: startCol
        last_line: endLine, last_column: endCol
        range: [0, 0]
    else
      @defaultLocationData()

  # Apply $ops operations
  applyOperation: (directive, frame, ruleName) ->
    switch directive.$ops
      when 'array'
        if directive.append?
          target = @evaluateDirective directive.append[0], frame, ruleName
          for item in directive.append[1..]
            value = @evaluateDirective item, frame, ruleName
            target.push value if value?
          target
        else if directive.gather?
          result = []
          for item in directive.gather
            evaluated = @evaluateDirective item, frame, ruleName
            if Array.isArray evaluated
              result = result.concat evaluated
            else
              result.push evaluated if evaluated?
          result

      when 'value'
        # TODO: Implement value operations (add accessor)
        @evaluateDirective directive.add?[0], frame, ruleName

      when 'if'
        # TODO: Implement if operations (addElse)
        @evaluateDirective directive.addElse?[0], frame, ruleName

      when 'loop'
        # TODO: Implement loop operations (addBody, addSource)
        @evaluateDirective directive.addBody?[0], frame, ruleName

      when 'prop'
        # TODO: Implement property operations (set)
        @evaluateDirective directive.set?.target, frame, ruleName

      else
        new nodes.Literal "/* TODO: $ops #{directive.$ops} */"

  # Legacy dataToClass method (backward compatibility for non-frame calls)
  dataToClass: (node) ->
    return null unless node?
    return node if typeof node in ['string', 'number', 'boolean']

    if Array.isArray node
      return node.map (item) => @dataToClass item

    # For legacy calls without frame, create minimal frame
    if node? and typeof node is 'object'
      if node.type?
        # Already a normalized node - convert directly
        return @solarNodeToClass node
      else
        # Solar directive without frame - limited support
        mockFrame = rhs: [{value: node}]
        return @evaluateDirective node, mockFrame

module.exports = ES5Backend
