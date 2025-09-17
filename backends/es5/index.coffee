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
      node = new nodes.Literal String(value)
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
            new nodes.NumberLiteral value, parsedValue

          when 'Value'
            inner = @evaluateDirective (if directive.val? then directive.val else directive.value), frame, ruleName
            # Handle properties (accessors)
            properties = @evaluateDirective directive.properties, frame, ruleName
            if inner?.compileToFragments or inner instanceof nodes.Base
              valueNode = if inner instanceof nodes.Value then inner else new nodes.Value inner
              if properties and Array.isArray(properties) and properties.length > 0
                for prop in properties
                  # Handle nested arrays of properties (e.g., from :: operator)
                  if Array.isArray(prop)
                    for subProp in prop
                      continue unless subProp?  # Skip null/undefined
                      if subProp instanceof nodes.Base
                        valueNode.add subProp
                      else if subProp?.type
                        converted = @solarNodeToClass(subProp)
                        if converted instanceof nodes.Base
                          valueNode.add converted
                  else if prop?  # Skip null/undefined
                    if prop instanceof nodes.Base
                      valueNode.add prop
                    else if prop?.type
                      converted = @solarNodeToClass(prop)
                      if converted instanceof nodes.Base
                        valueNode.add converted
              return valueNode
            @ensureNode(inner) or new nodes.Literal "/* TODO: Solar Value */"

          when 'Access'
            nameNode = @evaluateDirective directive.name, frame, ruleName
            # Ensure nameNode is not null
            if not nameNode?
              # For shorthand (::), use "prototype" as the name
              if directive.shorthand
                nameNode = new nodes.PropertyName 'prototype'
              else
                nameNode = new nodes.PropertyName ''
            else if nameNode?.type
              nameNode = @solarNodeToClass(nameNode)
            else if not (nameNode instanceof nodes.Base)
              nameNode = @ensureNode(nameNode)
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
            new nodes.Op op, left, right, flip, {originalOperator, invertOperator}

          when 'Arguments'
            args = @evaluateDirective (if directive.args? then directive.args else if directive.$ary? then directive.$ary else directive), frame, ruleName
            args = @filterNodes (if Array.isArray(args) then args else [])
            args.implicit = !!directive.implicit
            args

          when 'Call'
            variableNode = @evaluateDirective directive.variable, frame, ruleName
            argsNode = @evaluateDirective directive.args, frame, ruleName

            # Ensure args are proper nodes
            if Array.isArray argsNode
              argsNode = argsNode.map (arg) =>
                if arg instanceof nodes.Base
                  arg
                else if arg?.type
                  @solarNodeToClass(arg)
                else if arg?
                  @ensureNode(arg)
                else
                  null
              argsNode = @filterNodes argsNode
            else
              argsNode = []

            new nodes.Call (if variableNode instanceof nodes.Value then variableNode else new nodes.Value variableNode), argsNode, @evaluateDirective(directive.soak, frame, ruleName), @evaluateDirective(directive.token, frame, ruleName)

          when 'TaggedTemplateCall'
            vNode = @evaluateDirective directive.variable, frame, ruleName
            templateArg = @ensureNode @evaluateDirective directive.template, frame, ruleName
            new nodes.Call (if vNode instanceof nodes.Value then vNode else new nodes.Value vNode), [templateArg]

          when 'Assign'
            # Handle object property assignments differently
            if directive.context is 'object' and directive.expression?
              # In object context, 'value' is the property name, 'expression' is the value
              variable = @evaluateDirective directive.value, frame, ruleName
              value = @evaluateDirective directive.expression, frame, ruleName
              context = directive.context
              new nodes.Assign variable, value, context
            else
              # Regular assignment
              variable = @evaluateDirective directive.variable, frame, ruleName
              value = @evaluateDirective directive.value, frame, ruleName
              context = @evaluateDirective directive.context, frame, ruleName
              new nodes.Assign variable, value, context

          when 'StringLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            quote = @evaluateDirective directive.quote, frame, ruleName
            # Strip the surrounding quotes from the value if present
            if value and typeof value is 'string' and value.length >= 2
              if (value[0] is '"' and value[value.length - 1] is '"') or
                 (value[0] is "'" and value[value.length - 1] is "'")
                value = value.slice(1, -1)
            new nodes.StringLiteral value, {quote}

          when 'BooleanLiteral'
            value = @evaluateDirective directive.value, frame, ruleName
            new nodes.BooleanLiteral value

          when 'NullLiteral'
            new nodes.NullLiteral()

          when 'UndefinedLiteral'
            new nodes.UndefinedLiteral()

          when 'Arr'
            objects = @evaluateDirective directive.objects, frame, ruleName
            objects = @filterNodes (if Array.isArray(objects) then objects else [])
            new nodes.Arr objects

          when 'Obj'
            properties = @evaluateDirective directive.properties, frame, ruleName
            properties = @filterNodes (if Array.isArray(properties) then properties else [])
            generated = @evaluateDirective directive.generated, frame, ruleName
            new nodes.Obj properties, generated

          when 'Range'
            from = @evaluateDirective directive.from, frame, ruleName
            to = @evaluateDirective directive.to, frame, ruleName
            exclusive = if directive.exclusive? then directive.exclusive else directive.equals is 'exclusive'
            new nodes.Range from, to, exclusive

          when 'If', 'if'
            condition = @evaluateDirective directive.condition, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            elseBody = @evaluateDirective directive.elseBody, frame, ruleName
            bodyNode = if Array.isArray(body) then new nodes.Block @filterNodes(body) else body
            elseNode = if elseBody
              if Array.isArray(elseBody) then new nodes.Block @filterNodes(elseBody) else elseBody
            else
              null
            new nodes.If condition, bodyNode, {elseBody: elseNode}

          when 'While'
            condition = @evaluateDirective directive.condition, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            guard = @evaluateDirective directive.guard, frame, ruleName
            isLoop = @evaluateDirective directive.isLoop, frame, ruleName

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

            # Handle body
            if body?.expressions
              # Body node with expressions
              expressions = @filterNodes(if Array.isArray(body.expressions[0]) then body.expressions[0] else body.expressions)
              bodyNode = new nodes.Block expressions
            else if Array.isArray(body)
              bodyNode = new nodes.Block @filterNodes(body)
            else if body
              bodyNode = body
            else
              bodyNode = new nodes.Block []

            # Handle name/index - they often come as arrays
            if Array.isArray(name) then name = name[0]
            if Array.isArray(index) then index = index[0]

            # Convert to proper nodes if needed
            if name?.type then name = @solarNodeToClass name
            if index?.type then index = @solarNodeToClass index
            if source?.type then source = @solarNodeToClass source

            # Build source object for For constructor
            sourceObj = {}
            sourceObj.source = source if source
            sourceObj.name = name if name
            sourceObj.index = index if index
            sourceObj.guard = guard if guard
            sourceObj.step = step if step
            sourceObj.own = own if own
            sourceObj.object = object if object
            sourceObj.from = from if from

            # Create For node - constructor expects (body, source)
            forNode = new nodes.For bodyNode, sourceObj
            forNode

          when 'Try'
            attempt = @evaluateDirective directive.attempt, frame, ruleName
            recovery = @evaluateDirective directive.recovery, frame, ruleName
            ensure = @evaluateDirective directive.ensure, frame, ruleName
            attemptNode = if Array.isArray(attempt) then new nodes.Block @filterNodes(attempt) else attempt
            new nodes.Try attemptNode, recovery, ensure

          when 'Code'
            params = @evaluateDirective directive.params, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            bound = @evaluateDirective directive.bound, frame, ruleName

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
                if b?.type
                  @solarNodeToClass(b)
                else if b instanceof nodes.Base
                  b
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

            new nodes.Code paramsNode, bodyNode, bound or 'func'

          when 'Param'
            name = @evaluateDirective directive.name, frame, ruleName
            value = @evaluateDirective directive.value, frame, ruleName
            splat = @evaluateDirective directive.splat, frame, ruleName
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

          when 'Super'
            args = @evaluateDirective directive.args, frame, ruleName
            argsNode = @filterNodes (if Array.isArray(args) then args else [])
            new nodes.SuperCall argsNode

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
            new nodes.Throw expression

          when 'Splat'
            name = @evaluateDirective directive.name, frame, ruleName
            new nodes.Splat name

          when 'Expansion'
            expression = @evaluateDirective directive.expression, frame, ruleName
            new nodes.Expansion expression

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
            new nodes.Switch subject, casesNode, otherwise

          when 'When'
            conditions = @evaluateDirective directive.conditions, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            conditionsNode = @filterNodes (if Array.isArray(conditions) then conditions else [])
            bodyNode = if Array.isArray(body) then new nodes.Block @filterNodes(body) else body
            new nodes.When conditionsNode, bodyNode

          when 'Case'
            conditions = @evaluateDirective directive.conditions, frame, ruleName
            body = @evaluateDirective directive.body, frame, ruleName
            conditionsNode = @filterNodes (if Array.isArray(conditions) then conditions else [])
            bodyNode = if Array.isArray(body) then new nodes.Block @filterNodes(body) else body
            new nodes.Case conditionsNode, bodyNode

          when 'Catch'
            body = @evaluateDirective directive.body, frame, ruleName
            error = @evaluateDirective directive.error, frame, ruleName
            bodyNode = if Array.isArray(body) then new nodes.Block @filterNodes(body) else body
            new nodes.Catch error, bodyNode

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

          else
            # For unimplemented types, create placeholder
            new nodes.Literal "/* TODO: Solar #{nodeType} */"

      # $ary directive (array creation)
      else if directive.$ary?
        result = []
        for item in directive.$ary
          # Each item might have a $pos directive - evaluate without it
          itemCopy = Object.assign {}, item
          delete itemCopy.$pos if itemCopy.$pos?
          evaluated = @evaluateDirective itemCopy, frame, ruleName
          # Skip null/undefined items
          result.push evaluated if evaluated?
        result

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

      when 'StringLiteral'
        value = solarNode.value
        # Strip the surrounding quotes from the value if present
        if value and typeof value is 'string' and value.length >= 2
          if (value[0] is '"' and value[value.length - 1] is '"') or
             (value[0] is "'" and value[value.length - 1] is "'")
            value = value.slice(1, -1)
        new nodes.StringLiteral value, {quote: solarNode.quote}

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
        else
          # Regular assignment
          variable = @solarNodeToClass solarNode.variable if solarNode.variable
          value = @solarNodeToClass solarNode.value if solarNode.value
        new nodes.Assign variable, value, solarNode.context

      when 'Arr'
        objects = (if solarNode.objects then solarNode.objects.map((o) => @solarNodeToClass o) else [])
        new nodes.Arr @filterNodes objects

      when 'Obj'
        properties = (if solarNode.properties then solarNode.properties.map((p) => @solarNodeToClass p) else [])
        new nodes.Obj @filterNodes properties, solarNode.generated

      when 'Range'
        from = @solarNodeToClass solarNode.from if solarNode.from
        to = @solarNodeToClass solarNode.to if solarNode.to
        new nodes.Range from, to, solarNode.exclusive

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
        new nodes.Throw @solarNodeToClass solarNode.expression if solarNode.expression

      when 'Splat'
        new nodes.Splat @solarNodeToClass solarNode.name if solarNode.name

      when 'Expansion'
        new nodes.Expansion @solarNodeToClass solarNode.expression if solarNode.expression

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
          propNode = if propRaw?.compileToFragments or propRaw instanceof nodes.Base then propRaw else @ensureNode propRaw
          if targetNode instanceof nodes.Value
            targetNode.add [propNode]
            return targetNode
          else
            return new nodes.Value targetNode, [propNode]
        @evaluateDirective directive.add?[0], frame, ruleName

      when 'if'
        # TODO: Implement if operations (addElse)
        @evaluateDirective directive.addElse?[0], frame, ruleName

      when 'loop'
        # Loop operations for For/While loops
        if directive.addSource?
          # addSource: [loop, source] - add source to loop
          loopNode = @evaluateDirective directive.addSource[0], frame, ruleName
          sourceInfo = @evaluateDirective directive.addSource[1], frame, ruleName

          # Convert sourceInfo to proper node if needed
          if sourceInfo?.type
            sourceInfo = @solarNodeToClass sourceInfo

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

          # Ensure body has locationData
          if bodyNode?.constructor?.name and not bodyNode.locationData
            bodyNode.locationData = @defaultLocationData()

          if loopNode and bodyNode
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
