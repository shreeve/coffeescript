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
  constructor: (@options = {}, @nodes = nodes) ->
    @variableContext = {}  # Store for $var/$use variables
    # Allow nodes to be passed in or use the require
    nodes = @nodes
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
    # Generate unique variable names for loop iterators
    # We'll use a pattern that won't conflict with common user variables
    # Start with less common letters: k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    # Skip i and j as they're commonly used by users
    letters = ['k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']

    letterIndex = @loopVarCounter % letters.length
    num = Math.floor(@loopVarCounter / letters.length)
    varName = "#{letters[letterIndex]}#{num or ''}"

    @loopVarCounter++
    @usedLoopVars.add varName
    varName

  # Helper to ensure value is a proper node
  ensureNode: (value) ->
    return null unless value?
    return value if value.compileToFragments or value instanceof nodes.Base
    # Only wrap primitives; drop unknown objects to avoid emitting debug strings.
    if typeof value in ['string', 'number', 'boolean']
      node = new nodes.Literal String(value)
      node.locationData ?= @defaultLocationData()
      return node
    # Try to convert objects that might be PropertyName-like
    if value?.value?
      node = new nodes.PropertyName value.value
      node.locationData ?= @defaultLocationData()
      return node
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
      # Skip null/undefined
      continue unless item?

      # Already a proper node
      if item instanceof nodes.Base
        result.push item
        continue

      # Solar node that needs conversion
      if item?.type
        node = @solarNodeToClass item
        result.push node if node?
        continue

      # Primitive that needs wrapping
      node = @ensureNode item
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

      # $use directive (with optional method/prop/index)
      if directive.$use?
        ref = directive.$use
        value = if typeof ref is 'number'
          frame.rhs[ref - 1]?.value  # Position reference
        else if typeof ref is 'string' and @variableContext[ref]?
          @variableContext[ref]  # Lookup stored variable
        else
          ref  # Direct value

        # Apply method calls
        if directive.method?
          args = directive.args?.map((arg) => @evaluateDirective arg, frame) or []
          value?[directive.method]?.apply(value, args) or String(value)
        # Apply property access
        else if directive.prop?
          # Special handling for boolean properties to avoid the falsy trap
          result = value?[directive.prop]
          if result? or (value? and typeof value is 'object' and directive.prop of value)
            result
          else
            String(value)
        # Apply array index access
        else if directive.index?
          if Array.isArray(value) or value?.length?
            value?[directive.index] or undefined
          else
            undefined
        else
          value

      # $ast directive (AST node creation)
      else if directive.$ast?
        nodeType = if directive.$ast is '@' then ruleName else directive.$ast

        # Directly create CoffeeScript node with evaluated properties
        switch nodeType
          when 'Root'
            body = @evaluateDirective directive.body, frame, ruleName
            body = if Array.isArray(body) then body else (if body? then [body] else [])
            filteredBody = @filterNodes body
            new nodes.Root new nodes.Block filteredBody

          when 'IdentifierLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            node = new nodes.IdentifierLiteral value
            node.locationData ?= @defaultLocationData()
            node

          when 'Literal'
            value = @evaluateDirective directive.value, frame, ruleName
            new nodes.Literal value

          when 'NumberLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            parsedValue = @evaluateDirective directive.parsedValue, frame, ruleName
            # Strip underscores from numeric literals for compatibility
            # Modern JS supports them but older runtimes and some contexts don't
            cleanValue = if typeof value is 'string' then value.replace(/_/g, '') else value
            node = new nodes.NumberLiteral cleanValue, parsedValue
            node.locationData ?= @defaultLocationData()
            node

          when 'Value'
            # directive.val or directive.value can be a position reference (number) or actual value
            innerDirective = if directive.val? then directive.val else directive.value
            inner = @evaluateDirective innerDirective, frame, ruleName
            # Handle properties (accessors)
            properties = @evaluateDirective directive.properties, frame, ruleName
            # Special case: SuperCall should not be wrapped in Value unless it has properties
            if inner instanceof nodes.SuperCall and (not properties or properties.length is 0)
              return inner
            if inner?.compileToFragments or inner instanceof nodes.Base
              valueNode = if inner instanceof nodes.Value then inner else new nodes.Value inner
              if properties and Array.isArray(properties) and properties.length > 0
                validProps = []
                for prop in properties
                  # Handle nested arrays of properties (e.g., from :: operator)
                  if Array.isArray(prop)
                    for subProp in prop
                      continue unless subProp?  # Skip null/undefined
                      if subProp instanceof nodes.Base
                        validProps.push subProp
                      else if subProp?.type
                        converted = @solarNodeToClass(subProp)
                        if converted instanceof nodes.Base
                          validProps.push converted
                  else if prop?  # Skip null/undefined
                    if prop instanceof nodes.Base
                      validProps.push prop
                    else if prop?.type
                      converted = @solarNodeToClass(prop)
                      if converted instanceof nodes.Base
                        validProps.push converted
                      else
                        # Try to convert plain objects
                        ensured = @ensureNode(prop)
                        if ensured instanceof nodes.Base
                          validProps.push ensured
                # Only add non-null properties
                if validProps.length > 0
                  valueNode.add validProps
              return valueNode
            @ensureNode(inner) or new nodes.Literal "/* TODO: Solar Value */"

          when 'Access'
            nameNode = @evaluateDirective directive.name, frame, ruleName

            # Handle various forms of nameNode
            if not nameNode?
              # For shorthand (::), use "prototype" as the name
              if directive.shorthand
                nameNode = new nodes.PropertyName 'prototype'
              else
                nameNode = new nodes.PropertyName ''
            else if nameNode instanceof nodes.Base
              # Already a proper node, use as-is
              nameNode = nameNode
            else if nameNode?.type
              # Has a type property, convert from solar node
              nameNode = @solarNodeToClass(nameNode)
            else if typeof nameNode is 'string'
              # Plain string, convert to PropertyName
              nameNode = new nodes.PropertyName nameNode
            else if nameNode?.value?
              # Has a value property, convert to PropertyName
              nameNode = new nodes.PropertyName String(nameNode.value)
            else
              # Last resort, convert to empty PropertyName
              nameNode = new nodes.PropertyName ''

            # Final safety check - ensure nameNode is never null
            if not nameNode?
              nameNode = new nodes.PropertyName ''

            new nodes.Access nameNode, soak: directive.soak, shorthand: directive.shorthand

          when 'Index'
            idx = @evaluateDirective (if directive.index? then directive.index else if directive.name? then directive.name else directive.object), frame, ruleName
            new nodes.Index @ensureNode idx

          when 'PropertyName'
            value = @evaluateDirective directive.value, frame, ruleName
            # Ensure value is not null
            value = '' unless value?
            new nodes.PropertyName value

          when 'Op'
            op = @evaluateDirective (if directive.operator? then directive.operator else directive.args?[0]), frame, ruleName
            left  = @ensureNode @evaluateDirective (if directive.left? then directive.left else directive.args?[1]), frame, ruleName
            right = @ensureNode @evaluateDirective (if directive.right? then directive.right else directive.args?[2]), frame, ruleName
            flip  = @evaluateDirective (if directive.flip? then directive.flip else directive.args?[3]), frame, ruleName
            originalOperator = @evaluateDirective directive.originalOperator, frame, ruleName
            invertOperator   = @evaluateDirective directive.invertOperator, frame, ruleName

            # Handle CoffeeScript's in/of/instanceof operators
            # IMPORTANT: These work opposite to JavaScript!
            # CoffeeScript 'of' checks properties/keys (like JS 'in')
            # CoffeeScript 'in' checks values/elements (uses indexOf)

            # Check if this is a negated operator (not in, not of)
            negated = invertOperator is 'not' or invertOperator is true

            if op is 'of'
              # 'x of obj' checks if x is a property/key/index
              # Compiles to JavaScript's native 'in' operator
              # MUST set originalOperator to null to prevent it defaulting to 'in'
              # which would trigger the isInOperator() check and create an In node
              opNode = new nodes.Op 'in', left, right, false, {originalOperator: null}
              # If negated (not of), wrap in a Parens to ensure proper precedence
              if negated
                new nodes.Op '!', new nodes.Parens(opNode)
              else
                opNode
            else if op is 'in'
              # 'x in array' checks if x is in the values
              # Op with originalOperator='in' will create an In node internally
              # If negated, set invertOperator to trigger inversion
              new nodes.Op 'in', left, right, false, {
                originalOperator: 'in',
                invertOperator: if negated then '!' else null
              }
            else if op is 'instanceof'
              # instanceof checks type
              opNode = new nodes.Op 'instanceof', left, right
              if negated
                new nodes.Op '!', opNode
              else
                opNode
            else
              # All other operators
              new nodes.Op op, left, right, flip, {originalOperator, invertOperator}

          when 'Arguments'
            args = @evaluateDirective (if directive.args? then directive.args else if directive.$ary? then directive.$ary else directive), frame, ruleName
            args = @filterNodes (if Array.isArray(args) then args else [])
            deepFlatten = (arr) ->
              result = []
              for item in arr
                if Array.isArray(item)
                  flattened = deepFlatten(item)
                  for sub in flattened
                    result.push sub
                else
                  result.push item
              result
            args = deepFlatten(args)
            args.implicit = !!directive.implicit
            args

          when 'Call'
            variableNode = @evaluateDirective directive.variable, frame, ruleName
            argsNode = @evaluateDirective directive.args, frame, ruleName

            # Ensure args are proper nodes
            if Array.isArray argsNode
              # Deep-flatten and convert to nodes, removing null/undefined
              deepFlattenToNodes = (arr) =>
                out = []
                for item in arr
                  if Array.isArray(item)
                    out = out.concat deepFlattenToNodes(item)
                  else if item instanceof nodes.Base
                    out.push item
                  else if item?.type
                    converted = @solarNodeToClass(item)
                    out.push converted if converted?
                  else if item?
                    ensured = @ensureNode(item)
                    out.push ensured if ensured?
                out
              argsNode = deepFlattenToNodes argsNode
            else
              argsNode = []

            # Check if this is a bare super() call (not a delegated super.method(...))
            if variableNode instanceof nodes.Super
              new nodes.SuperCall(variableNode, argsNode)
            else if variableNode instanceof nodes.Value and variableNode.base instanceof nodes.Super
              # Has a property access: this is super.method(...), NOT a constructor super()
              new nodes.Call variableNode, argsNode, @evaluateDirective(directive.soak, frame, ruleName), @evaluateDirective(directive.token, frame, ruleName)
            else
              new nodes.Call (if variableNode instanceof nodes.Value then variableNode else new nodes.Value variableNode), argsNode, @evaluateDirective(directive.soak, frame, ruleName), @evaluateDirective(directive.token, frame, ruleName)

          when 'TaggedTemplateCall'
            vNode = @evaluateDirective directive.variable, frame, ruleName
            templateArg = @ensureNode @evaluateDirective directive.template, frame, ruleName
            # Convert StringLiteral to StringWithInterpolations for tagged templates
            if templateArg instanceof nodes.StringLiteral
              templateArg = nodes.StringWithInterpolations.fromStringLiteral templateArg
            # Tagged templates should never have soak (no typeof check)
            new nodes.TaggedTemplateCall (if vNode instanceof nodes.Value then vNode else new nodes.Value vNode), templateArg, false

          when 'Assign'
            # Handle object property assignments differently
            if directive.context is 'object' and directive.expression?
              # In object context, 'value' is the property name, 'expression' is the value
              variable = @evaluateDirective directive.value, frame, ruleName
              value = @evaluateDirective directive.expression, frame, ruleName
              context = directive.context
              # Mark Value nodes with ThisLiteral base as this=true for static properties
              if variable instanceof nodes.Value and variable.base instanceof nodes.ThisLiteral
                variable.this = true
              new nodes.Assign variable, value, context
            else if directive.expression? and not directive.variable?
              # Default value assignment (e.g., in destructuring {x = 10})
              # Here 'value' is the variable name and 'expression' is the default value
              variable = @evaluateDirective directive.value, frame, ruleName
              value = @evaluateDirective directive.expression, frame, ruleName
              # Use null context for destructuring defaults so Param.eachName handles it correctly
              new nodes.Assign variable, value, null
            else
              # Regular assignment
              variable = @evaluateDirective directive.variable, frame, ruleName
              value = @evaluateDirective directive.value, frame, ruleName
              # For compound assignments, use the operator as the context
              context = if directive.operator?
                operator = @evaluateDirective directive.operator, frame, ruleName
                operator
              else
                @evaluateDirective directive.context, frame, ruleName
              options = {}
              if directive.originalContext?
                options.originalContext = @evaluateDirective directive.originalContext, frame, ruleName
              # Create the Assign node with the correct context for compound assignments
              new nodes.Assign variable, value, context, options

          when 'StringLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            quote = @evaluateDirective directive.quote, frame, ruleName
            # Strip the surrounding quotes from the value if present
            if value and typeof value is 'string' and value.length >= 2
              if (value[0] is '"' and value[value.length - 1] is '"') or
                 (value[0] is "'" and value[value.length - 1] is "'")
                value = value.slice(1, -1)

            # Handle triple-quoted strings (heredocs) - strip common leading whitespace
            if quote is '"""' or quote is "'''"
              lines = value.split('\n')
              if lines.length > 1
                # Find minimum indentation (excluding empty lines)
                minIndent = Infinity
                for line in lines[1..]  # Skip first line
                  if line.trim().length > 0
                    leadingSpaces = line.match(/^[ \t]*/)[0].length
                    minIndent = Math.min(minIndent, leadingSpaces)

                # Strip common indentation from all lines except the first
                if minIndent > 0 and minIndent < Infinity
                  for i in [1...lines.length]
                    lines[i] = lines[i].slice(minIndent)
                  value = lines.join('\n')

            node = new nodes.StringLiteral value, {quote}
            node.locationData ?= @defaultLocationData()
            node

          when 'BooleanLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            new nodes.BooleanLiteral value

          when 'StatementLiteral'
            # Handle break, continue, debugger statements
            value = @evaluateDirective directive.value, frame, ruleName
            switch value
              when 'break'
                new nodes.StatementLiteral value
              when 'continue'
                new nodes.StatementLiteral value
              when 'debugger'
                new nodes.StatementLiteral value
              else
                # For other statements, create a basic literal
                new nodes.Literal value

          when 'NullLiteral'
            new nodes.NullLiteral()

          when 'UndefinedLiteral'
            new nodes.UndefinedLiteral()

          when 'Arr'
            objects = @evaluateDirective directive.objects, frame, ruleName
            objects = @filterNodes (if Array.isArray(objects) then objects else [])
            arr = new nodes.Arr objects
            arr.locationData ?= @defaultLocationData()
            arr

          when 'Obj'
            properties = @evaluateDirective directive.properties, frame, ruleName
            properties = @filterNodes (if Array.isArray(properties) then properties else [])
            generated = @evaluateDirective directive.generated, frame, ruleName

            # If object is generated (from braces) and has shorthand properties,
            # convert them to proper key-value pairs
            if generated
              fixedProps = []
              for prop in properties
                if prop instanceof nodes.Value and prop.base instanceof nodes.IdentifierLiteral and not prop.properties?.length
                  # This is a shorthand property like 'x' in {x}
                  # Convert to x: x
                  key = new nodes.Value prop.base
                  value = new nodes.Value prop.base
                  fixedProps.push new nodes.Assign key, value, 'object'
                else if prop instanceof nodes.Value and prop.base instanceof nodes.ThisLiteral
                  # This is an @ property like {@x} - extract the property name
                  # and mark the Value node with this=true for Param.eachName to handle correctly
                  if prop.properties?[0] instanceof nodes.Access
                    # Get the property name from the Access node
                    propName = prop.properties[0].name
                    if propName instanceof nodes.PropertyName
                      # PropertyName has a 'value' property with the actual name
                      propNameStr = propName.value
                      propName = new nodes.IdentifierLiteral propNameStr
                    else if typeof propName is 'string'
                      propName = new nodes.IdentifierLiteral propName
                    else if not (propName instanceof nodes.Base)
                      propName = @ensureNode propName

                    # Create the property assignment for object pattern
                    # The value should be a Value node marked with this=true
                    key = new nodes.Value propName
                    value = new nodes.Value propName
                    value.this = true  # Mark as @ parameter
                    fixedProps.push new nodes.Assign key, value, 'object'
                  else
                    fixedProps.push prop
                else
                  fixedProps.push prop
              properties = fixedProps

            obj = new nodes.Obj properties, generated
            obj.locationData ?= @defaultLocationData()
            obj

          when 'Range'
            from = @evaluateDirective directive.from, frame, ruleName
            to = @evaluateDirective directive.to, frame, ruleName
            # Evaluate the exclusive flag - it can be a directive or a boolean
            exclusiveVal = @evaluateDirective directive.exclusive, frame, ruleName
            # The evaluateDirective should return the boolean value from {$use: 3, prop: 'exclusive'}
            exclusive = if typeof exclusiveVal is 'boolean'
              exclusiveVal
            else if directive.equals?
              @evaluateDirective(directive.equals, frame, ruleName) is 'exclusive'
            else
              false
            # Ensure from and to are proper nodes
            fromNode = if from instanceof nodes.Base then from else @ensureNode(from)
            toNode = if to instanceof nodes.Base then to else @ensureNode(to)
            # Pass 'exclusive' as the tag for exclusive ranges
            tag = if exclusive then 'exclusive' else null
            new nodes.Range fromNode, toNode, tag

          when 'If', 'if'
            condition = @evaluateDirective directive.condition, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            elseBody = @evaluateDirective directive.elseBody, frame, ruleName
            type = @evaluateDirective directive.type, frame, ruleName
            postfix = @evaluateDirective directive.postfix, frame, ruleName

            # The type will be the string 'unless' from the IF/POST_IF token for unless statements

            bodyNode = if Array.isArray(body)
              block = new nodes.Block @filterNodes(body)
              block.locationData ?= @defaultLocationData()
              block
            else
              body
            elseNode = if elseBody
              if Array.isArray(elseBody)
                block = new nodes.Block @filterNodes(elseBody)
                block.locationData ?= @defaultLocationData()
                block
              else
                elseBody
            else
              null

            # Pass the type to the If constructor - it handles 'unless' internally
            opts = {}
            opts.type = type if type  # Will be 'unless' for unless statements
            opts.postfix = postfix if postfix
            ifNode = new nodes.If condition, bodyNode, opts
            ifNode.locationData ?= @defaultLocationData()
            # Use addElse for proper else-if chaining
            if elseNode
              elseNode.locationData ?= @defaultLocationData()
              ifNode.addElse elseNode
            ifNode

          when 'Unless', 'unless'
            # Unless is an inverted If
            condition = @evaluateDirective directive.condition, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            elseBody = @evaluateDirective directive.elseBody, frame, ruleName
            postfix = @evaluateDirective directive.postfix, frame, ruleName

            bodyNode = if Array.isArray(body)
              block = new nodes.Block @filterNodes(body)
              block.locationData ?= @defaultLocationData()
              block
            else
              body
            elseNode = if elseBody
              if Array.isArray(elseBody)
                block = new nodes.Block @filterNodes(elseBody)
                block.locationData ?= @defaultLocationData()
                block
              else
                elseBody
            else
              null

            # Create an If node with type: 'unless' for unless
            opts = {type: 'unless'}
            opts.postfix = postfix if postfix
            ifNode = new nodes.If condition, bodyNode, opts
            ifNode.locationData ?= @defaultLocationData()
            # Use addElse for proper else-if chaining
            if elseNode
              elseNode.locationData ?= @defaultLocationData()
              ifNode.addElse elseNode
            ifNode

          when 'While'
            condition = @evaluateDirective directive.condition, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            guard = @evaluateDirective directive.guard, frame, ruleName
            isLoop = @evaluateDirective directive.isLoop, frame, ruleName
            invert = @evaluateDirective directive.invert, frame, ruleName

            # Handle body - convert from Solar node if needed
            if body?.type is 'Body' or body?.type is 'Block'
              # Convert the Solar Body/Block node to CoffeeScript Block
              bodyNode = @solarNodeToClass body
            else if Array.isArray(body)
              bodyNode = new nodes.Block @filterNodes(body)
            else if body instanceof nodes.Block
              bodyNode = body
            else if body
              bodyNode = new nodes.Block [@ensureNode(body)]
            else
              bodyNode = new nodes.Block []

            # While constructor expects (condition, opts)
            opts = {}
            opts.guard = guard if guard
            opts.isLoop = isLoop if isLoop
            opts.invert = invert if invert  # Handle 'until' loops
            whileNode = new nodes.While condition, opts
            # Set the body - ensure it's never null
            finalBody = bodyNode or new nodes.Block []
            # Debug: console.error "[While] body type:", finalBody?.constructor?.name, "has isEmpty:", typeof finalBody?.isEmpty
            whileNode.body = finalBody
            whileNode

          when 'For'
            # For loops are complex - they're built incrementally via $ops
            body = @evaluateDirective directive.body, frame, ruleName
            source = @evaluateDirective directive.source, frame, ruleName
            guard = @evaluateDirective directive.guard, frame, ruleName
            name = @evaluateDirective directive.name, frame, ruleName
            index = @evaluateDirective directive.index, frame, ruleName
            step = @evaluateDirective directive.step, frame, ruleName
            own = @evaluateDirective directive.own, frame, ruleName
            object = @evaluateDirective directive.object, frame, ruleName
            from = @evaluateDirective directive.from, frame, ruleName
            isAwait = @evaluateDirective directive.await, frame, ruleName

            # Handle body
            if body?.expressions
              # Body node with expressions - preserve full list and order
              bodyNode = new nodes.Block @filterNodes(body.expressions)
            else if Array.isArray(body)
              bodyNode = new nodes.Block @filterNodes(body)
            else if body
              bodyNode = body
            else
              bodyNode = new nodes.Block []

            # Handle name/index - they often come as arrays
            # Special case: for own k, v of obj - name comes as [k, v]
            # But nodes.For swaps name and index when object is true, so we need to account for that
            if own and object and Array.isArray(name) and name.length is 2 and not index?
              # nodes.For will swap these, so set them opposite to what we want
              # We want: name=v, index=k (after the swap)
              # So we set: name=k, index=v (before the swap)
              nameArray = name
              name = nameArray[0]   # k (will become index after swap)
              index = nameArray[1]  # v (will become name after swap)
            else if Array.isArray(name)
              name = name[0]

            if Array.isArray(index) then index = index[0]

            # Convert to proper nodes if needed
            if name?.type then name = @solarNodeToClass name
            if index?.type then index = @solarNodeToClass index
            if source?.type then source = @solarNodeToClass source

            # Build source object for For constructor
            sourceObj = {}
            # Ensure source is a proper node
            if source
              sourceObj.source = if source instanceof nodes.Base then source else @ensureNode(source)
            if name
              sourceObj.name = if name instanceof nodes.Base then name else @ensureNode(name)
            # Only add index if it's actually defined (not undefined/null)
            # This is important for for-await loops which may not have an index
            # Also check if index is the string "index" which means the variable wasn't found
            # console.error "[For] index value:", index, "typeof:", typeof index, "is null?:", index is null
            if index? and index isnt undefined and index isnt 'index'
              sourceObj.index = if index instanceof nodes.Base then index else @ensureNode(index)
            sourceObj.guard = guard if guard
            sourceObj.step = step if step
            sourceObj.own = own if own
            sourceObj.object = object if object
            sourceObj.from = from if from
            sourceObj.await = isAwait if isAwait

            # Create For node - constructor expects (body, source)
            forNode = new nodes.For bodyNode, sourceObj
            forNode.locationData ?= @defaultLocationData()

            # CRITICAL FIX for nested loop var conflicts (#4889):
            # Pre-allocate unique loop variables and override scope.freeVariable
            loopVar = @getUniqueLoopVar()
            incrementVar = @getUniqueLoopVar()

            originalCompileNode = forNode.compileNode
            forNode.compileNode = (o) =>
              originalFreeVariable = null
              if o?.scope?.freeVariable
                originalFreeVariable = o.scope.freeVariable
                varCounter = 0
                preAllocatedVars = [loopVar, incrementVar]

                # Determine user-declared value variable name to avoid collisions
                userName = null
                try
                  if forNode.name? and forNode.name instanceof nodes.IdentifierLiteral
                    userName = forNode.name.value
                  else if forNode.name? and forNode.name instanceof nodes.Value and forNode.name.base instanceof nodes.IdentifierLiteral
                    userName = forNode.name.base.value
                catch e then userName = null

                o.scope.freeVariable = (name, options = {}) =>
                  # When nodes.For requests 'i' with single:true, it's asking for an iterator temp
                  # ALWAYS return our pre-allocated var for these iterator requests
                  if options.single and name is 'i'
                    if varCounter < preAllocatedVars.length
                      result = preAllocatedVars[varCounter++]
                      return result
                    else
                      return @getUniqueLoopVar()
                  else
                    return originalFreeVariable.call(o.scope, name, options)

              result = originalCompileNode.call(forNode, o)

              if originalFreeVariable?
                o.scope.freeVariable = originalFreeVariable

              result

            forNode

          when 'Try'
            attempt = @evaluateDirective directive.attempt, frame, ruleName
            # CS3 uses 'catch' not 'recovery' for the catch clause
            catchDirective = @evaluateDirective directive.catch, frame, ruleName
            ensure = @evaluateDirective directive.ensure, frame, ruleName

            # Ensure attempt is a proper block
            attemptNode = if Array.isArray(attempt)
              new nodes.Block @filterNodes(attempt)
            else if attempt instanceof nodes.Block
              attempt
            else if attempt
              new nodes.Block [@ensureNode(attempt)]
            else
              new nodes.Block []

            # Process the catch clause - it should be a Catch node
            # If catchDirective is not a Catch node, we may need to evaluate it
            recovery = if catchDirective instanceof nodes.Catch
              catchDirective
            else if catchDirective
              # It might be a directive that needs to be evaluated into a Catch node
              catchDirective
            else
              null

            # Ensure ensure is a proper block if present
            ensureNode = if ensure
              if Array.isArray(ensure)
                new nodes.Block @filterNodes(ensure)
              else if ensure instanceof nodes.Block
                ensure
              else
                new nodes.Block [@ensureNode(ensure)]
            else
              null

            # Try expects (attempt, recovery, ensure) where recovery and ensure are optional
            new nodes.Try attemptNode, recovery, ensureNode

          when 'Code'
            params = @evaluateDirective directive.params, frame, ruleName

            # For body, check if it's a position reference to an already-processed array or Block
            # This preserves modifications made by operations like addElse
            if typeof directive.body is 'number' and frame?.rhs?[directive.body - 1]
              frameValue = frame.rhs[directive.body - 1].value
              # If it's already a Block or an array of nodes, use it directly
              # This preserves any modifications made by operations
              if frameValue instanceof nodes.Block or (Array.isArray(frameValue) and frameValue.some((v) -> v instanceof nodes.Base))
                body = frameValue
              else
                body = @evaluateDirective directive.body, frame, ruleName
            else
              body = @evaluateDirective directive.body, frame, ruleName

            # Check if this is a bound function (fat arrow =>)
            funcGlyph = @evaluateDirective directive.funcGlyph, frame, ruleName
            bound = funcGlyph?.glyph is '=>' or @evaluateDirective directive.bound, frame, ruleName

            # Ensure params are proper nodes
            if Array.isArray(params)
              paramsNode = params.map (p) =>
                if p?.type
                  @solarNodeToClass(p)
                else if p instanceof nodes.Base
                  p
                else
                  @ensureNode(p)
              paramsNode = @filterNodes paramsNode
            else
              paramsNode = []

            # Ensure body is a proper Block with converted nodes
            if Array.isArray(body)
              bodyNodes = body.map (b) =>
                # Check for nodes.Base FIRST to avoid re-processing existing nodes
                if b instanceof nodes.Base
                  b
                else if b?.type
                  @solarNodeToClass(b)
                else
                  @ensureNode(b)
              bodyNode = new nodes.Block @filterNodes(bodyNodes)
            else if body?.type
              bodyNode = new nodes.Block [@solarNodeToClass(body)]
            else if body instanceof nodes.Block
              bodyNode = body
            else if body
              bodyNode = new nodes.Block [@ensureNode(body)]
            else
              bodyNode = new nodes.Block []

            # Create proper FuncGlyph for bound/unbound functions
            funcGlyph = if bound then new nodes.FuncGlyph('=>') else new nodes.FuncGlyph('->')
            codeNode = new nodes.Code paramsNode, bodyNode, funcGlyph

            # For CS3, pre-scan for super calls to avoid false positives
            # in derived constructor validation
            hasSuper = false
            if bodyNode?.expressions
              bodyNode.traverseChildren false, (node) ->
                if node instanceof nodes.SuperCall or (node instanceof nodes.Call and node.variable instanceof nodes.Super)
                  hasSuper = true
                  return false  # Stop traversing
                return true  # Continue traversing

            # Monkey-patch only for constructors; avoid affecting arrow methods and regular methods
            isCtor = !!(@evaluateDirective(directive.isConstructor, frame, ruleName))
            if hasSuper and isCtor
              # Skip validation for @params in derived constructors
              origFlag = codeNode.flagThisParamInDerivedClassConstructorWithoutCallingSuper
              codeNode.flagThisParamInDerivedClassConstructorWithoutCallingSuper = (param) ->
                # Skip the validation for CS3-generated code with super
                return

              # Also patch eachSuperCall to make it always find the super call
              origEachSuper = codeNode.eachSuperCall
              codeNode.eachSuperCall = (context, iterator, opts) ->
                # If checking params (not the body), use original so validations still run
                if context isnt @body and origEachSuper?
                  return origEachSuper.call this, context, iterator, opts
                # Otherwise, search body for the real SuperCall and report it
                if iterator
                  for expr in bodyNode.expressions
                    if expr instanceof nodes.SuperCall or (expr instanceof nodes.Call and expr.variable instanceof nodes.Super)
                      iterator(expr)
                      break
                true

            codeNode

          when 'Param'
            name = @evaluateDirective directive.name, frame, ruleName
            value = @evaluateDirective directive.value, frame, ruleName
            splat = @evaluateDirective directive.splat, frame, ruleName
            # Param requires at least a name
            if not name
              name = new nodes.IdentifierLiteral 'param'

            # Check if this is an @ parameter (like @x)
            # Name will be a Value with base=ThisLiteral and properties containing the actual name
            if name instanceof nodes.Value and name.base instanceof nodes.ThisLiteral
              # This is an @param - mark it with this=true so Param recognizes it
              name.this = true
              name.locationData ?= @defaultLocationData()
            else if name and not name.locationData
              # Ensure name has locationData (needed for destructuring)
              name.locationData = @defaultLocationData()

            # For destructured params with Obj, ensure it's not marked as generated
            # TODO: Handle {@x, @y} destructuring - this is complex and needs more work
            if name instanceof nodes.Obj
              name.generated = false
            else if name instanceof nodes.Value and name.base instanceof nodes.Obj
              name.base.generated = false

            new nodes.Param name, value, splat

          when 'Return'
            expression = @evaluateDirective directive.expression, frame, ruleName
            new nodes.Return expression

          when 'Yield'
            expression = @evaluateDirective directive.expression, frame, ruleName
            from = @evaluateDirective directive.from, frame, ruleName
            new nodes.Yield expression, from

          when 'Class'
            variable = @evaluateDirective directive.variable, frame, ruleName
            parent = @evaluateDirective directive.parent, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            bodyNode = if Array.isArray(body) then new nodes.Block @filterNodes(body) else body
            new nodes.Class variable, parent, bodyNode

          when 'Slice'
            # Handle array/string slicing operations
            range = @evaluateDirective directive.range, frame, ruleName
            new nodes.Slice range

          when 'Super'
            # Create a Super node (this keyword for accessing parent methods)
            new nodes.Super()

          when 'SuperCall'
            # Handle super() calls in constructors and methods
            args = @evaluateDirective directive.args, frame, ruleName
            argsNode = if Array.isArray(args)
              # Filter out nulls that ensureNode might return
              args.map((arg) => @ensureNode(arg)).filter((arg) => arg?)
            else if args
              arg = @ensureNode(args)
              if arg? then [arg] else []
            else
              []

            # Create a SuperCall node with the Super variable and arguments
            variableNode = new nodes.Super()
            new nodes.SuperCall variableNode, argsNode

          when 'StringWithInterpolations'
            body = @evaluateDirective directive.body, frame, ruleName
            quote = @evaluateDirective directive.quote, frame, ruleName

            # Convert body to proper nodes
            if Array.isArray(body)
              bodyNodes = body.map (b) =>
                if b instanceof nodes.Base
                  b
                else if b?.type
                  @solarNodeToClass(b)
                else if b?
                  @ensureNode(b)
                else
                  null
              bodyNode = new nodes.Block @filterNodes(bodyNodes)
            else if body instanceof nodes.Block
              bodyNode = body
            else
              bodyNode = new nodes.Block []

            new nodes.StringWithInterpolations bodyNode, {quote}

          when 'Interpolation'
            expression = @evaluateDirective directive.expression, frame, ruleName
            # Create Interpolation node with the evaluated expression
            # Expression might be an array, so extract the first element
            actualExpression = if Array.isArray(expression) and expression.length > 0
              expression[0]
            else
              expression

            expressionNode = if actualExpression instanceof nodes.Base
              actualExpression
            else if actualExpression
              @ensureNode(actualExpression)
            else
              new nodes.Literal 'undefined'
            new nodes.Interpolation expressionNode

          when 'TemplateElement'
            value = @evaluateDirective directive.value, frame, ruleName
            tail = @evaluateDirective directive.tail, frame, ruleName
            new nodes.TemplateElement value, tail

          when 'Block'
            expressions = @evaluateDirective directive.expressions, frame, ruleName
            new nodes.Block @filterNodes (if Array.isArray(expressions) then expressions else [])

          when 'Body'
            expressions = @evaluateDirective directive.expressions, frame, ruleName
            # Flatten nested arrays - expressions often come as [[expr1], [expr2]]
            flatExpressions = []
            if Array.isArray(expressions)
              for expr in expressions
                if Array.isArray(expr)
                  flatExpressions.push item for item in expr
                else
                  flatExpressions.push expr
            else if expressions?
              flatExpressions.push expressions
            new nodes.Block @filterNodes flatExpressions

          when 'RegexLiteral', 'Regex'
            value = @evaluateDirective directive.value, frame, ruleName
            delimiter = @evaluateDirective directive.delimiter, frame, ruleName
            # RegexLiteral expects the full regex string including delimiters
            # If we have a value like "/test/gi", pass it directly
            if value and typeof value is 'string' and value[0] is '/'
              new nodes.RegexLiteral value, {delimiter: delimiter or '/'}
            else
              # Otherwise try to construct from pattern and flags
              pattern = @evaluateDirective directive.pattern, frame, ruleName
              flags = @evaluateDirective directive.flags, frame, ruleName
              fullRegex = "/#{pattern or ''}/#{flags or ''}"
              new nodes.RegexLiteral fullRegex, {delimiter: delimiter or '/'}

          when 'Parens'
            body = @evaluateDirective directive.body, frame, ruleName

            # Handle array body (Parens can contain an array with a single expression)
            if Array.isArray(body) and body.length > 0
              # Take the first element if it's an array
              bodyItem = body[0]
              if bodyItem instanceof nodes.Base
                bodyNode = bodyItem
              else if bodyItem?.type
                bodyNode = @solarNodeToClass(bodyItem)
              else if bodyItem?
                bodyNode = @ensureNode(bodyItem)
              else
                bodyNode = new nodes.Literal ''
            else if body instanceof nodes.Base
              bodyNode = body
            else if body?.type
              bodyNode = @solarNodeToClass(body)
            else if body?
              bodyNode = @ensureNode(body)
            else
              bodyNode = new nodes.Literal ''

            new nodes.Parens bodyNode

          when 'PassthroughLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            new nodes.PassthroughLiteral value, {here: directive.here, generated: directive.generated}

          when 'Throw'
            expression = @evaluateDirective directive.expression, frame, ruleName
            # Throw needs a valid expression
            new nodes.Throw (expression or new nodes.Literal 'undefined')

          when 'Splat'
            # Check for 'name' or 'body' field (@ directive uses 'body')
            nameDirective = directive.name ? directive.body
            name = @evaluateDirective nameDirective, frame, ruleName
            # Splat requires a valid expression, not undefined
            if name
              new nodes.Splat name
            else
              # Create a placeholder if name is missing
              new nodes.Splat new nodes.Literal 'undefined'

          when 'Expansion'
            # Check for 'expression' or 'body' field (@ directive uses 'body')
            exprDirective = directive.expression ? directive.body
            expression = @evaluateDirective exprDirective, frame, ruleName
            # Expansion needs a valid expression
            if expression
              new nodes.Expansion expression
            else
              new nodes.Expansion new nodes.Literal 'undefined'

          when 'In'
            object = @evaluateDirective directive.object, frame, ruleName
            array = @evaluateDirective directive.array, frame, ruleName
            new nodes.In object, array

          when 'ImportDeclaration'
            clause = @evaluateDirective directive.clause, frame, ruleName
            source = @evaluateDirective directive.source, frame, ruleName
            new nodes.ImportDeclaration clause, source

          when 'ExportNamedDeclaration', 'ExportDeclaration'
            clause = @evaluateDirective directive.clause, frame, ruleName
            source = @evaluateDirective directive.source, frame, ruleName
            new nodes.ExportNamedDeclaration clause, source

          when 'Existence'
            expression = @evaluateDirective directive.expression, frame, ruleName
            new nodes.Existence expression

          when 'Loop'
            body = @evaluateDirective directive.body, frame, ruleName
            # Ensure body is a proper Block
            if Array.isArray(body)
              bodyNode = new nodes.Block @filterNodes(body)
            else if body instanceof nodes.Block
              bodyNode = body
            else if body
              bodyNode = new nodes.Block [body]
            else
              bodyNode = new nodes.Block []
            # Loop is a While with true condition
            loopNode = new nodes.While new nodes.BooleanLiteral('true'), {isLoop: true}
            loopNode.body = bodyNode
            loopNode

          when 'Switch'
            subject = @evaluateDirective directive.subject, frame, ruleName
            cases = @evaluateDirective directive.cases, frame, ruleName
            otherwise = @evaluateDirective directive.otherwise, frame, ruleName
            casesNode = @filterNodes (if Array.isArray(cases) then cases else [])
            # Ensure otherwise is a proper block or null
            if otherwise
              if Array.isArray(otherwise)
                otherwise = new nodes.Block @filterNodes(otherwise)
              else if not (otherwise instanceof nodes.Base)
                otherwise = new nodes.Block [@ensureNode(otherwise)]
            new nodes.Switch subject, casesNode, otherwise

          when 'When', 'SwitchWhen'
            conditions = @evaluateDirective directive.conditions, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName

            # Process conditions - make sure they are proper nodes
            conditionsNode = if Array.isArray(conditions)
              processedConditions = []
              for cond in conditions
                if cond instanceof nodes.Base
                  processedConditions.push cond
                else if cond?
                  converted = @ensureNode(cond)
                  processedConditions.push converted if converted instanceof nodes.Base
              processedConditions
            else if conditions instanceof nodes.Base
              [conditions]
            else if conditions?
              converted = @ensureNode(conditions)
              if converted instanceof nodes.Base then [converted] else []
            else
              []

            # SwitchWhen expects 'block' not 'body'
            blockNode = if Array.isArray(body)
              new nodes.Block @filterNodes(body)
            else if body
              if body instanceof nodes.Block
                body
              else
                new nodes.Block [body]
            else
              new nodes.Block []
            new nodes.SwitchWhen conditionsNode, blockNode

          when 'Case', 'SwitchCase'
            conditions = @evaluateDirective directive.conditions, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName

            # Process conditions - make sure they are proper nodes
            conditionsNode = if Array.isArray(conditions)
              processedConditions = []
              for cond in conditions
                if cond instanceof nodes.Base
                  processedConditions.push cond
                else if cond?
                  converted = @ensureNode(cond)
                  processedConditions.push converted if converted instanceof nodes.Base
              processedConditions
            else if conditions instanceof nodes.Base
              [conditions]
            else if conditions?
              converted = @ensureNode(conditions)
              if converted instanceof nodes.Base then [converted] else []
            else
              []

            # SwitchCase expects 'block' not 'body'
            blockNode = if Array.isArray(body)
              new nodes.Block @filterNodes(body)
            else if body
              if body instanceof nodes.Block
                body
              else
                new nodes.Block [body]
            else
              new nodes.Block []
            # Use SwitchWhen for both - SwitchCase has a different signature
            new nodes.SwitchWhen conditionsNode, blockNode

          when 'Catch'
            # CS3 uses either 'recovery' or 'body' for the catch block
            body = @evaluateDirective(directive.recovery, frame, ruleName) or @evaluateDirective(directive.body, frame, ruleName)
            # CS3 uses 'variable' or 'errorVariable' for the error parameter
            error = @evaluateDirective(directive.variable, frame, ruleName) or @evaluateDirective(directive.errorVariable, frame, ruleName)

            # Ensure body is a proper Block
            bodyNode = if Array.isArray(body)
              new nodes.Block @filterNodes(body)
            else if body instanceof nodes.Block
              body
            else if body
              new nodes.Block [@ensureNode(body)]
            else
              new nodes.Block []

            # Ensure error parameter is properly converted if present
            errorNode = if error then @ensureNode(error) else null

            # Catch constructor expects (recovery, errorVariable) not (errorVariable, recovery)!
            new nodes.Catch bodyNode, errorNode

          when 'Finally'
            body = @evaluateDirective directive.body, frame, ruleName
            bodyNode = if Array.isArray(body) then new nodes.Block @filterNodes(body) else body
            new nodes.Finally bodyNode

          when 'Await'
            expression = @evaluateDirective directive.expression, frame, ruleName
            new nodes.Await expression

          when 'YieldFrom'
            expression = @evaluateDirective directive.expression, frame, ruleName
            new nodes.YieldFrom expression

          when 'ThisLiteral', 'This'
            # Create a This node
            thisNode = new nodes.ThisLiteral()
            thisNode.locationData ?= @defaultLocationData()
            thisNode

          when 'Elision'
            # Elisions in array destructuring are placeholders for skipped elements
            # CS2 has a special Elision class for this
            new nodes.Elision()

          when 'InfinityLiteral'
            # Infinity is a special numeric value
            new nodes.Literal 'Infinity'

          when 'NaNLiteral'
            # NaN is a special numeric value
            new nodes.Literal 'NaN'

          when 'ComputedPropertyName'
            # Computed property names like ["dynamic" + key]: value
            expression = @evaluateDirective directive.expression, frame, ruleName
            # Return a bracket notation access node
            if expression instanceof nodes.Base
              expression
            else
              @ensureNode(expression)

          when 'DynamicImport'
            # Dynamic import is just the 'import' keyword itself
            new nodes.IdentifierLiteral 'import'

          when 'DynamicImportCall'
            # Dynamic import: import('./module')
            variable = @evaluateDirective directive.variable, frame, ruleName
            args = @evaluateDirective directive.args, frame, ruleName

            # Ensure variable is the import identifier
            variableNode = if variable instanceof nodes.Base
              variable
            else
              new nodes.IdentifierLiteral 'import'

            # Process arguments
            argsNode = if Array.isArray(args)
              # Filter out nulls that ensureNode might return
              args.map((arg) => @ensureNode(arg)).filter((arg) => arg?)
            else if args
              arg = @ensureNode(args)
              if arg? then [arg] else []
            else
              []

            new nodes.Call variableNode, argsNode, false

          when 'FuncGlyph'
            # FuncGlyph for -> or => functions
            glyph = @evaluateDirective directive.glyph, frame, ruleName
            new nodes.FuncGlyph(glyph)

          else
            # For unimplemented types, create placeholder
            new nodes.Literal "/* TODO: Solar #{nodeType} */"

      # $ary directive (array creation)
      else if directive.$ary?
        result = []
        for item in directive.$ary
          # If item is a number, it's a position reference
          if typeof item is 'number'
            evaluated = @evaluateDirective item, frame, ruleName
          else
            # Item is an object, might have a $pos directive - evaluate without it
            itemCopy = Object.assign {}, item
            delete itemCopy.$pos if itemCopy.$pos?
            evaluated = @evaluateDirective itemCopy, frame, ruleName
          # Skip null/undefined items
          result.push evaluated if evaluated?
        result

      # $ops directive (operations)
      else if directive.$ops?
        result = @applyOperation directive, frame, ruleName
        # If the operation returned a value, use it; otherwise evaluate the rest of the directive
        if result?
          result
        else
          # Try evaluating the directive without $ops (for combined directives)
          directiveCopy = Object.assign {}, directive
          delete directiveCopy.$ops
          @evaluateDirective directiveCopy, frame, ruleName

      # $seq directive (sequences)
      else if directive.$seq?
        result = null
        for step in directive.$seq
          # Handle $var directives to store variables
          if step?.$var?
            varName = step.$var
            varValue = @evaluateDirective step.value, frame, ruleName
            @variableContext[varName] = varValue
          else
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
        # Strip underscores from numeric literals for compatibility
        value = solarNode.value
        cleanValue = if typeof value is 'string' then value.replace(/_/g, '') else value
        node = new nodes.NumberLiteral cleanValue, solarNode.parsedValue
        node.locationData = solarNode.locationData or @defaultLocationData()
        node

      when 'StringLiteral'
        value = solarNode.value
        quote = solarNode.quote
        # Strip the surrounding quotes from the value if present
        if value and typeof value is 'string' and value.length >= 2
          if (value[0] is '"' and value[value.length - 1] is '"') or
             (value[0] is "'" and value[value.length - 1] is "'")
            value = value.slice(1, -1)

        # Handle triple-quoted strings (heredocs) - strip common leading whitespace
        if quote is '"""' or quote is "'''"
          lines = value.split('\n')
          if lines.length > 1
            # Find minimum indentation (excluding empty lines)
            minIndent = Infinity
            for line in lines[1..]  # Skip first line
              if line.trim().length > 0
                leadingSpaces = line.match(/^[ \t]*/)[0].length
                minIndent = Math.min(minIndent, leadingSpaces)

            # Strip common indentation from all lines except the first
            if minIndent > 0 and minIndent < Infinity
              for i in [1...lines.length]
                lines[i] = lines[i].slice(minIndent)
              value = lines.join('\n')

        node = new nodes.StringLiteral value, {quote}
        node.locationData = solarNode.locationData or @defaultLocationData()
        node

      when 'BooleanLiteral'
        new nodes.BooleanLiteral solarNode.value

      when 'NullLiteral'
        new nodes.NullLiteral()

      when 'UndefinedLiteral'
        new nodes.UndefinedLiteral()

      when 'Op'
        first = @solarNodeToClass solarNode.left if solarNode.left
        second = @solarNodeToClass solarNode.right if solarNode.right
        new nodes.Op solarNode.operator, first, second, solarNode.flip

      when 'Assign'
        # Handle object property assignments differently
        if solarNode.context is 'object' and solarNode.expression?
          # In object context, 'value' is the property name, 'expression' is the value
          variable = @solarNodeToClass solarNode.value if solarNode.value
          value = @solarNodeToClass solarNode.expression if solarNode.expression
          # Mark Value nodes with ThisLiteral base as this=true for static properties
          if variable instanceof nodes.Value and variable.base instanceof nodes.ThisLiteral
            variable.this = true
        else if solarNode.expression? and not solarNode.variable?
          # Default value assignment (e.g., in destructuring {x = 10})
          # Here 'value' is the variable name and 'expression' is the default value
          variable = @solarNodeToClass solarNode.value if solarNode.value
          value = @solarNodeToClass solarNode.expression if solarNode.expression
          # Use null context for destructuring defaults so Param.eachName handles it correctly
        else
          # Regular assignment
          variable = @solarNodeToClass solarNode.variable if solarNode.variable
          value = @solarNodeToClass solarNode.value if solarNode.value
        # For compound assignments, use the operator as the context
        # For destructuring defaults (expression but no variable), use null context
        context = if solarNode.expression? and not solarNode.variable? and not (solarNode.context is 'object')
          null
        else if solarNode.operator
          operator = if typeof solarNode.operator is 'string'
            solarNode.operator
          else if solarNode.operator?.toString?()
            solarNode.operator.toString()
          operator
        else
          solarNode.context
        options = {}
        if solarNode.originalContext
          options.originalContext = solarNode.originalContext
        new nodes.Assign variable, value, context, options

      when 'Arr'
        objects = (if solarNode.objects then solarNode.objects.map((o) => @solarNodeToClass o) else [])
        new nodes.Arr @filterNodes objects

      when 'Obj'
        properties = (if solarNode.properties then solarNode.properties.map((p) => @solarNodeToClass p) else [])
        new nodes.Obj @filterNodes properties, solarNode.generated

      when 'Range'
        from = @solarNodeToClass solarNode.from if solarNode.from
        to = @solarNodeToClass solarNode.to if solarNode.to
        # Fix for exclusive range - the 'equals' field determines exclusivity
        exclusive = solarNode.exclusive or solarNode.equals is 'exclusive'
        new nodes.Range from, to, exclusive

      when 'RegexLiteral', 'Regex'
        # RegexLiteral expects the full regex string including delimiters
        if solarNode.value and typeof solarNode.value is 'string' and solarNode.value[0] is '/'
          new nodes.RegexLiteral solarNode.value, {delimiter: solarNode.delimiter or '/'}
        else
          # Otherwise try to construct from pattern and flags
          pattern = solarNode.pattern or ''
          flags = solarNode.flags or ''
          fullRegex = "/#{pattern}/#{flags}"
          new nodes.RegexLiteral fullRegex, {delimiter: solarNode.delimiter or '/'}

      when 'Parens'
        new nodes.Parens @solarNodeToClass solarNode.body

      when 'PassthroughLiteral'
        new nodes.PassthroughLiteral solarNode.value, {here: solarNode.here, generated: solarNode.generated}

      when 'Throw'
        expr = if solarNode.expression then @solarNodeToClass solarNode.expression else null
        new nodes.Throw (expr or new nodes.Literal 'undefined')

      when 'Splat'
        name = if solarNode.name then @solarNodeToClass solarNode.name else null
        new nodes.Splat (name or new nodes.Literal 'undefined')

      when 'Expansion'
        expr = if solarNode.expression then @solarNodeToClass solarNode.expression else null
        new nodes.Expansion (expr or new nodes.Literal 'undefined')

      when 'Slice'
        range = @solarNodeToClass solarNode.range if solarNode.range
        new nodes.Slice range

      when 'In'
        object = @solarNodeToClass solarNode.object if solarNode.object
        array = @solarNodeToClass solarNode.array if solarNode.array
        new nodes.In object, array

      when 'ImportDeclaration'
        clause = @solarNodeToClass solarNode.clause if solarNode.clause
        source = @solarNodeToClass solarNode.source if solarNode.source
        new nodes.ImportDeclaration clause, source

      when 'ExportNamedDeclaration', 'ExportDeclaration'
        clause = @solarNodeToClass solarNode.clause if solarNode.clause
        source = @solarNodeToClass solarNode.source if solarNode.source
        new nodes.ExportNamedDeclaration clause, source

      when 'Existence'
        new nodes.Existence @solarNodeToClass solarNode.expression if solarNode.expression

      when 'Loop'
        body = @solarNodeToClass solarNode.body if solarNode.body
        new nodes.Loop body

      when 'Access'
        nameNode = if solarNode.name?.type
          @solarNodeToClass solarNode.name
        else if solarNode.name?.value?
          new nodes.PropertyName solarNode.name.value
        else if typeof solarNode.name is 'string'
          new nodes.PropertyName solarNode.name
        else
          # For shorthand (::), default to "prototype"
          new nodes.PropertyName (if solarNode.shorthand then 'prototype' else '')
        new nodes.Access nameNode, {soak: solarNode.soak, shorthand: solarNode.shorthand}

      when 'PropertyName'
        new nodes.PropertyName solarNode.value or ''

      when 'Block'
        expressions = if solarNode.expressions
          @filterNodes (if Array.isArray(solarNode.expressions) then solarNode.expressions else [])
        else
          []
        new nodes.Block expressions

      when 'Body'
        # Body nodes have expressions that are often nested arrays
        expressions = solarNode.expressions or []
        flatExpressions = []
        if Array.isArray(expressions)
          for expr in expressions
            if Array.isArray(expr)
              for item in expr
                converted = if item?.type then @solarNodeToClass(item) else item
                flatExpressions.push converted if converted?
            else
              converted = if expr?.type then @solarNodeToClass(expr) else expr
              flatExpressions.push converted if converted?
        new nodes.Block @filterNodes flatExpressions

      when 'if'
        # if statement
        bodyNode = if solarNode.body?.expressions
          block = new nodes.Block solarNode.body.expressions
          block.locationData ?= @defaultLocationData()
          block
        else
          @ensureNode(solarNode.body)
        elseNode = if solarNode.elseBody
          if solarNode.elseBody.expressions
            block = new nodes.Block solarNode.elseBody.expressions
            block.locationData ?= @defaultLocationData()
            block
          else
            @ensureNode(solarNode.elseBody)
        else
          null
        # Include postfix and type if they exist
        opts = {}
        opts.postfix = solarNode.postfix if solarNode.postfix?
        opts.type = solarNode.type if solarNode.type?
        ifNode = new nodes.If @ensureNode(solarNode.condition), bodyNode, opts
        # Use addElse for proper else-if chaining
        ifNode.addElse elseNode if elseNode
        ifNode

      when 'unless'
        # unless is an inverted if statement
        bodyNode = if solarNode.body?.expressions
          block = new nodes.Block solarNode.body.expressions
          block.locationData ?= @defaultLocationData()
          block
        else
          @ensureNode(solarNode.body)
        elseNode = if solarNode.elseBody
          if solarNode.elseBody.expressions
            block = new nodes.Block solarNode.elseBody.expressions
            block.locationData ?= @defaultLocationData()
            block
          else
            @ensureNode(solarNode.elseBody)
        else
          null
        # Pass type: 'unless' for unless statements
        opts = {type: 'unless'}
        opts.postfix = solarNode.postfix if solarNode.postfix?
        ifNode = new nodes.If @ensureNode(solarNode.condition), bodyNode, opts
        # Use addElse for proper else-if chaining
        ifNode.addElse elseNode if elseNode
        ifNode

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
          # First element is the target array, rest are items to append
          target = @evaluateDirective directive.append[0], frame, ruleName
          # Ensure target is an array
          target = if Array.isArray(target) then target else []

          for item in directive.append[1..]
            value = @evaluateDirective item, frame, ruleName
            # If value is already an array (from $ary), unwrap it
            if Array.isArray(value) and value.length == 1
              target.push value[0] if value[0]?
            else
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
        # Add an accessor (Access/Index) to a Value
        if directive.add?
          targetRaw = @evaluateDirective directive.add[0], frame, ruleName
          propRaw = @evaluateDirective directive.add[1], frame, ruleName

          targetNode = if targetRaw?.compileToFragments or targetRaw instanceof nodes.Base then targetRaw else @ensureNode targetRaw

          # Handle array of properties
          propNodes = if Array.isArray(propRaw)
            propRaw.map (p) => if p?.compileToFragments or p instanceof nodes.Base then p else @ensureNode p
          else
            propNode = if propRaw?.compileToFragments or propRaw instanceof nodes.Base then propRaw else @ensureNode propRaw
            [propNode] if propNode?

          # Ensure we have valid nodes before proceeding
          return null unless targetNode? and propNodes?.length > 0

          if targetNode instanceof nodes.Value
            # Clone the Value node to avoid mutation issues
            clonedValue = Object.assign Object.create(Object.getPrototypeOf(targetNode)), targetNode
            clonedValue.properties = (targetNode.properties or []).slice()
            clonedValue.add propNodes
            return clonedValue
          else
            return new nodes.Value targetNode, propNodes
        @evaluateDirective directive.add?[0], frame, ruleName

      when 'if'
        # If operations for adding else clauses
        if directive.addElse?
          # addElse: [ifNode, elseBody] - add else clause to if statement
          ifNode = @evaluateDirective directive.addElse[0], frame, ruleName
          elseBody = @evaluateDirective directive.addElse[1], frame, ruleName

          if ifNode instanceof nodes.If
            # Convert elseBody to proper node if needed
            if elseBody?.type
              elseBody = @solarNodeToClass elseBody

            # Set the else body (alternate property)
            elseBodyNode = if Array.isArray(elseBody)
              block = new nodes.Block @filterNodes(elseBody)
              block.locationData ?= @defaultLocationData()
              block
            else if elseBody instanceof nodes.Block
              elseBody.locationData ?= @defaultLocationData()
              elseBody
            else if elseBody
              if elseBody instanceof nodes.Base
                elseBody.locationData ?= @defaultLocationData()
                elseBody
              else
                block = new nodes.Block [@ensureNode(elseBody)]
                block.locationData ?= @defaultLocationData()
                block
            else
              null

            # Use addElse to properly handle else-if chains
            if elseBodyNode?
              ifNode.addElse elseBodyNode
          ifNode
        else
          null

      when 'loop'
        # Loop operations for For/While loops
        if directive.addSource?
          # addSource: [loop, source] - add source to loop
          loopNode = @evaluateDirective directive.addSource[0], frame, ruleName
          sourceInfo = @evaluateDirective directive.addSource[1], frame, ruleName

          # Convert sourceInfo to proper node if needed
          if sourceInfo?.type
            sourceInfo = @solarNodeToClass sourceInfo

          # Ensure source has proper structure
          if sourceInfo
            # For addSource, we might get an object with source, name, index, etc.
            if sourceInfo instanceof nodes.Base
              # Already a node, ensure it has locationData
              sourceInfo.locationData ?= @defaultLocationData()
            else if typeof sourceInfo is 'object' and not Array.isArray(sourceInfo)
              # It's a source object with properties
              if sourceInfo.source and not (sourceInfo.source instanceof nodes.Base)
                sourceInfo.source = @ensureNode sourceInfo.source
              if sourceInfo.name and not (sourceInfo.name instanceof nodes.Base)
                sourceInfo.name = @ensureNode sourceInfo.name
              if sourceInfo.index and not (sourceInfo.index instanceof nodes.Base)
                sourceInfo.index = @ensureNode sourceInfo.index
            else
              # Convert to node
              sourceInfo = @ensureNode sourceInfo

          if loopNode and sourceInfo
            loopNode.addSource sourceInfo
          loopNode
        else if directive.addBody?
          # addBody: [loop, body] - add body to loop
          loopNode = @evaluateDirective directive.addBody[0], frame, ruleName
          bodyArg = directive.addBody[1]

          # Handle "Body $N" placeholder
          if typeof bodyArg is 'string' and bodyArg.startsWith('Body $')
            position = parseInt(bodyArg.slice(6))
            bodyNode = @evaluateDirective position, frame, ruleName
          else
            bodyNode = @evaluateDirective bodyArg, frame, ruleName

          # Convert body to proper node if needed
          if bodyNode?.type
            bodyNode = @solarNodeToClass bodyNode

          # Ensure body is a proper Block node with locationData
          if bodyNode
            # Handle different body types
            if Array.isArray(bodyNode)
              # If it's an array, create a Block with the array's contents
              bodyNode = new nodes.Block @filterNodes(bodyNode)
            else if bodyNode instanceof nodes.Block
              # Already a Block, use as-is
              bodyNode = bodyNode
            else if bodyNode instanceof nodes.Base
              # Single node, wrap in Block
              bodyNode = new nodes.Block [bodyNode]
            else
              # Not a node yet, ensure it becomes one
              bodyNode = new nodes.Block [@ensureNode(bodyNode)]
            # Ensure locationData exists
            bodyNode.locationData ?= @defaultLocationData()
          else
            # Create empty block if no body
            bodyNode = new nodes.Block []
            bodyNode.locationData = @defaultLocationData()

          if loopNode
            loopNode.addBody bodyNode
          loopNode
        else
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
