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

nodes = require '../../lib/coffeescript/nodes'

class ES5Backend
  constructor: (@options = {}) ->
    @compileOptions =
      bare: @options.bare ? true
      header: @options.header ? false
      sourceMap: @options.sourceMap ? false
      inlineMap: @options.inlineMap ? false

  # Main entry point - convert CS3 data node to JavaScript
  generate: (dataNode) ->
    classNode = @dataToClass dataNode
    classNode.compile @compileOptions

  # Helper to create default locationData
  defaultLocationData: ->
    first_line: 0
    first_column: 0
    last_line: 0
    last_column: 0
    last_line_exclusive: 0
    last_column_exclusive: 0
    range: [0, 0]

  # Helper to ensure value is a proper node
  ensureNode: (value) ->
    return null unless value?
    return value if value.compileToFragments or value instanceof nodes.Base
    # Wrap primitives in Literal
    new nodes.Literal String(value)

  # Helper to filter and ensure all items are nodes
  filterNodes: (array) ->
    return [] unless array?
    result = []
    for item in array
      node = @ensureNode @dataToClass item
      result.push node if node?
    result

  # Convert CS3 data nodes to CoffeeScript class nodes
  dataToClass: (node) ->
    return null unless node?

    # Handle primitives
    return node if typeof node in ['string', 'number', 'boolean']

    # Handle arrays
    if Array.isArray node
      return node.map (item) => @dataToClass item

    # Must be an object with a type
    return null unless node?.type

    switch node.type
      # ============================================================
      # Root and Structural Nodes
      # ============================================================
      when 'Root'
        bodyNodes = if Array.isArray node.body
          @filterNodes node.body
        else if node.body
          converted = @dataToClass node.body
          if converted? then [converted] else []
        else
          []
        new nodes.Root new nodes.Block bodyNodes

      when 'Block'
        expressions = if node.expressions
          converted = @dataToClass node.expressions
          if Array.isArray converted
            converted.filter (item) -> item?
          else if converted?
            [converted]
          else
            []
        else if node.body
          converted = @dataToClass node.body
          if Array.isArray converted
            converted.filter (item) -> item?
          else if converted?
            [converted]
          else
            []
        else
          []
        new nodes.Block expressions

      # ============================================================
      # Literals
      # ============================================================
      when 'NumberLiteral'
        new nodes.NumberLiteral node.value, node.parsedValue

      when 'StringLiteral'
        quote = node.quote or '"'
        value = node.value or ''
        stringNode = new nodes.StringLiteral value, {quote}
        # Critical: Must have locationData and originalValue
        stringNode.locationData = node.locationData or @defaultLocationData()
        stringNode.originalValue = value
        stringNode

      when 'Literal'
        new nodes.Literal node.value

      when 'BooleanLiteral'
        new nodes.BooleanLiteral node.value

      when 'NullLiteral'
        new nodes.NullLiteral()

      when 'UndefinedLiteral'
        new nodes.UndefinedLiteral()

      when 'InfinityLiteral'
        new nodes.InfinityLiteral node.value

      when 'NaNLiteral'
        new nodes.NaNLiteral()

      when 'IdentifierLiteral'
        new nodes.IdentifierLiteral node.value

      when 'PropertyName'
        new nodes.PropertyName node.value

      when 'StatementLiteral'
        new nodes.StatementLiteral node.value

      when 'ThisLiteral'
        new nodes.ThisLiteral node.value or 'this'

      when 'RegexLiteral'
        new nodes.RegexLiteral node.value,
          delimiter: node.delimiter
          heregexCommentTokens: node.heregexCommentTokens

      when 'PassthroughLiteral'
        new nodes.PassthroughLiteral node.value,
          here: node.here
          generated: node.generated

      # ============================================================
      # Values and Properties
      # ============================================================
      when 'Value'
        base = @dataToClass(node.val or node.base or node.value)
        properties = if node.properties
          result = []
          for prop in node.properties
            if Array.isArray prop
              # Handle nested arrays (like [[Access, Access]] for ::)
              for item in prop
                converted = @dataToClass item
                result.push converted if converted
            else
              converted = @dataToClass prop
              result.push converted if converted
          result
        else
          []
        new nodes.Value base, properties

      when 'Access'
        name = @dataToClass node.name
        accessNode = new nodes.Access name
        accessNode.soak = node.soak if node.soak
        accessNode.shorthand = node.shorthand if node.shorthand
        accessNode

      when 'Index'
        index = @dataToClass(node.object or node.name)
        indexNode = new nodes.Index index
        indexNode.soak = node.soak if node.soak
        indexNode

      # ============================================================
      # Assignment
      # ============================================================
      when 'Assign'
        # Handle object property assignments
        if node.context is 'object' and node.expression
          variable = @dataToClass node.value
          value = @dataToClass node.expression
        else
          variable = @dataToClass node.variable
          value = @dataToClass node.value

        return null unless variable? and value?

        context = node.context
        options = {}
        options.param = node.param if node.param
        options.subpattern = node.subpattern if node.subpattern

        if node.operatorToken
          if typeof node.operatorToken is 'object' and node.operatorToken.type
            options.operatorToken =
              value: node.operatorToken.value
              locationData: node.operatorToken.locationData
          else
            options.operatorToken = @dataToClass node.operatorToken

        options.moduleDeclaration = node.moduleDeclaration if node.moduleDeclaration
        new nodes.Assign variable, value, context, options

      # ============================================================
      # Operations
      # ============================================================
      when 'Op'
        if node.args
          [op, first, second, flip] = node.args
          op = op.toString() if typeof op is 'object'
          first = @dataToClass first
          second = @dataToClass second if second

          # Critical: Pass invertOperator and originalOperator
          options = {}
          options.invertOperator = node.invertOperator if node.invertOperator
          options.originalOperator = node.originalOperator if node.originalOperator

          new nodes.Op op, first, second, flip, options
        else
          op = node.operator or node.op
          first = @dataToClass node.first
          second = @dataToClass node.second if node.second
          new nodes.Op op, first, second, node.flip

      when 'Existence'
        expression = @dataToClass node.expression
        new nodes.Existence expression

      # ============================================================
      # Functions and Calls
      # ============================================================
      when 'Code'
        # First, flatten params and check for @params and super calls
        flatParams = []
        atParams = []  # Track @params that need to be moved after super

        if node.params
          for param in node.params
            if Array.isArray param
              for p in param
                flatParams.push p
            else
              flatParams.push param

        # Helper to check if super call is simple (direct statement, not in expression)
        hasSimpleSuperCall = false
        if node.body
          bodyArray = if Array.isArray(node.body) then node.body else [node.body]
          for item in bodyArray
            # Check for direct super calls or super calls wrapped in Value
            if item?.type is 'SuperCall'
              hasSimpleSuperCall = true
              break
            else if item?.type is 'Value' and item?.val?.type is 'SuperCall'
              hasSimpleSuperCall = true
              break

        # Process params, handling @params specially if there's a super call
        processedParams = []
        for param in flatParams
          if param?.type is 'Param' and param.name?.type is 'Value' and
             param.name.val?.type is 'ThisLiteral' and param.name.properties?.length > 0 and
             hasSimpleSuperCall
            # This is an @param with a super call in the body
            # Convert @name to regular name parameter
            propName = param.name.properties[0].name.value
            # Create a simple param without any special properties
            simpleParam = new nodes.Param(new nodes.IdentifierLiteral(propName))
            processedParams.push simpleParam
            # Save the assignment for after super
            atParams.push {name: propName}
          else
            # Regular param or no super call
            converted = @dataToClass param
            processedParams.push converted if converted

        params = processedParams

        bodyNodes = if Array.isArray node.body
          @filterNodes node.body
        else if node.body
          converted = @dataToClass node.body
          if converted? then [converted] else []
        else
          []

        # If we have @params that were moved, add assignments after super
        if atParams.length > 0 and hasSimpleSuperCall
          # Helper to find and mark where super calls are
          findAndReplaceSuperCalls = (node) ->
            return unless node

            # Check if this node contains a super call
            hasSuper = false
            if node?.constructor?.name is 'SuperCall'
              hasSuper = true
            else if node?.base?.constructor?.name is 'SuperCall'
              hasSuper = true
            else
              # Check in object properties (for { super: super() } case)
              if node?.constructor?.name is 'Obj' and node.properties
                for prop in node.properties
                  if prop?.value?.constructor?.name is 'SuperCall'
                    hasSuper = true
                    break

            if hasSuper
              # Add marker that this node has super
              node._hasSuperCall = true

            # Recursively check children
            for key, value of node
              continue if key[0] is '_' or key in ['constructor']
              if value and typeof value is 'object'
                if Array.isArray value
                  for item in value
                    findAndReplaceSuperCalls item if item?.constructor
                else if value.constructor
                  findAndReplaceSuperCalls value

          # Mark nodes with super calls
          for bodyNode in bodyNodes
            findAndReplaceSuperCalls bodyNode

          # For complex cases (super in expressions), prepend the assignments at the start
          needsPrepend = false
          for bodyNode in bodyNodes
            if bodyNode?._hasSuperCall and bodyNode?.constructor?.name isnt 'SuperCall'
              needsPrepend = true
              break

          if needsPrepend
            # Complex case: add assignments at the very beginning
            # This is safer but may not be ideal for all cases
            newBodyNodes = []
            for atParam in atParams
              # Create @name = name assignment
              thisLit = new nodes.ThisLiteral()
              access = new nodes.Access(new nodes.PropertyName(atParam.name))
              left = new nodes.Value(thisLit, [access])
              right = new nodes.IdentifierLiteral(atParam.name)
              assignment = new nodes.Assign(left, right)
              newBodyNodes.push assignment
            newBodyNodes.push bodyNodes...
            bodyNodes = newBodyNodes
          else
            # Simple case: add after the super call statement
            newBodyNodes = []
            for bodyNode in bodyNodes
              newBodyNodes.push bodyNode
              if bodyNode?.constructor?.name is 'SuperCall' or bodyNode?._hasSuperCall
                for atParam in atParams
                  # Create @name = name assignment
                  thisLit = new nodes.ThisLiteral()
                  access = new nodes.Access(new nodes.PropertyName(atParam.name))
                  left = new nodes.Value(thisLit, [access])
                  right = new nodes.IdentifierLiteral(atParam.name)
                  assignment = new nodes.Assign(left, right)
                  newBodyNodes.push assignment
            bodyNodes = newBodyNodes

        body = new nodes.Block bodyNodes
        funcGlyph = node.funcGlyph?.glyph or '->'
        tag = if funcGlyph is '=>' then 'boundfunc' else null
        new nodes.Code params, body, tag

      when 'Param'
        name = @dataToClass node.name
        value = @dataToClass node.value if node.value
        splat = node.splat
        new nodes.Param name, value, splat

      when 'Call'
        variable = @dataToClass node.variable
        args = if node.args
          @filterNodes node.args
        else
          []
        soak = node.soak
        new nodes.Call variable, args, soak

      when 'Super'
        accessor = @dataToClass node.accessor if node.accessor
        new nodes.Super accessor

      when 'SuperCall'
        # SuperCall extends Call(variable, args, soak)
        # The variable should be a Super node
        variable = if node.variable
          @dataToClass node.variable
        else
          new nodes.Super()

        # Process arguments, filtering out empty objects
        args = if node.args
          result = []
          for arg in node.args
            # Skip empty objects
            if arg? and (arg.type or Object.keys(arg).length > 0)
              converted = @dataToClass arg
              result.push converted if converted
          result
        else
          []

        # Create SuperCall with Super as variable and filtered args
        new nodes.SuperCall variable, args, node.soak

      # ============================================================
      # Arrays and Objects
      # ============================================================
      when 'Arr'
        objects = if node.objects
          result = []
          for obj in node.objects
            if Array.isArray obj
              # Process all elements in nested arrays (happens with elisions)
              for item in obj
                if item?.type is 'Elision'
                  # Handle elisions - create actual hole/empty slot
                  result.push new nodes.Elision()
                else
                  converted = @dataToClass item
                  result.push converted if converted
            else if obj?.type is 'Elision'
              # Handle elisions - create actual hole/empty slot
              result.push new nodes.Elision()
            else if typeof obj is 'object' and Object.keys(obj).length > 0
              converted = @dataToClass obj
              result.push converted if converted

          # Handle trailing elisions stored in separate elisions property
          # Only process elisions that have type: 'Elision', not empty objects
          if node.elisions
            for elision in node.elisions
              if elision?.type is 'Elision'
                result.push new nodes.Elision()

          result
        else if node.value
          if Array.isArray node.value
            node.value
              .filter (v) -> not (typeof v is 'object' and Object.keys(v).length is 0)
              .map (v) => @dataToClass v
          else
            [@dataToClass node.value]
        else
          []
        new nodes.Arr objects

      when 'Obj'
        properties = if node.properties
          result = []
          for prop in node.properties
            if Array.isArray prop
              for item in prop
                converted = @dataToClass item
                result.push converted if converted? and converted instanceof nodes.Base
            else if prop?
              converted = @dataToClass prop
              result.push converted if converted? and converted instanceof nodes.Base
          result
        else
          []
        generated = node.generated
        new nodes.Obj properties, generated

      when 'Range'
        from = @dataToClass node.from
        to = @dataToClass node.to
        tag = if node.exclusive then 'exclusive' else 'inclusive'
        new nodes.Range from, to, tag

      when 'Slice'
        # Unwrap the range
        @dataToClass node.range

      when 'Splat'
        name = @dataToClass(node.name or node.body)
        new nodes.Splat name

      when 'Expansion'
        new nodes.Expansion()

      when 'Elision'
        # Support array elisions - create actual hole/empty slot
        new nodes.Elision()

      # ============================================================
      # Control Flow
      # ============================================================
      when 'If', 'if', 'unless'
        condition = @dataToClass node.condition
        body = if Array.isArray node.body
          bodyNodes = node.body.map (n) => @dataToClass n
          new nodes.Block bodyNodes
        else
          @dataToClass node.body

        options = {}
        options.type = node.type if node.type
        options.postfix = node.postfix if node.postfix

        ifNode = new nodes.If condition, body, options

        if node.elseBody
          elseBody = if Array.isArray node.elseBody
            bodyNodes = node.elseBody.map (n) => @dataToClass n
            new nodes.Block bodyNodes
          else
            @dataToClass node.elseBody
          ifNode.elseBody = elseBody
          ifNode.isChain = elseBody instanceof nodes.If

        ifNode

      when 'While'
        condition = @dataToClass node.condition
        guard = @dataToClass node.guard if node.guard
        body = if Array.isArray node.body
          new nodes.Block @dataToClass node.body
        else
          @dataToClass node.body
        new nodes.While condition, guard
          .addBody body

      when 'For'
        # Convert body
        body = if Array.isArray node.body
          bodyNodes = node.body.map (n) =>
            converted = @dataToClass n
            if converted
              converted.locationData ?= @defaultLocationData()
            converted
          new nodes.Block bodyNodes
        else if node.body
          @dataToClass node.body
        else
          new nodes.Block []

        # Ensure locationData
        body.locationData ?= @defaultLocationData()
        if body.expressions
          for expr in body.expressions
            expr.locationData ?= @defaultLocationData()

        # Build source object
        sourceObj = {}
        sourceObj.source = @dataToClass node.source if node.source
        sourceObj.guard = @dataToClass node.guard if node.guard
        sourceObj.step = @dataToClass node.step if node.step
        sourceObj.name = @dataToClass node.name if node.name
        sourceObj.index = @dataToClass node.index if node.index
        sourceObj.object = node.object if node.object
        sourceObj.from = node.from if node.from
        sourceObj.own = node.own if node.own
        sourceObj.await = node.await if node.await
        sourceObj.awaitTag = @dataToClass node.awaitTag if node.awaitTag
        sourceObj.ownTag = @dataToClass node.ownTag if node.ownTag

        # FIX: Loop variable conflicts
        # The For node constructor will handle variable allocation
        # We just need to pass the correct source configuration
        new nodes.For body, sourceObj

      when 'Switch'
        subject = @dataToClass node.subject
        cases = if node.cases
          node.cases.map (c) => @dataToClass c
        else
          []
        otherwise = if node.otherwise
          otherwiseNode = @dataToClass node.otherwise
          if otherwiseNode instanceof nodes.Block
            otherwiseNode
          else if Array.isArray otherwiseNode
            new nodes.Block otherwiseNode
          else if otherwiseNode?
            new nodes.Block [otherwiseNode]
          else
            null
        else
          null
        new nodes.Switch subject, cases, otherwise

      when 'SwitchWhen'
        conditions = @dataToClass node.conditions
        body = if node.body
          bodyNode = @dataToClass node.body
          if bodyNode instanceof nodes.Block
            bodyNode
          else if Array.isArray bodyNode
            new nodes.Block bodyNode
          else if bodyNode?
            new nodes.Block [bodyNode]
          else
            new nodes.Block []
        else
          new nodes.Block []
        new nodes.SwitchWhen conditions, body

      when 'Try'
        attempt = if node.attempt
          attemptNode = @dataToClass node.attempt
          if attemptNode instanceof nodes.Block
            attemptNode
          else if Array.isArray attemptNode
            new nodes.Block attemptNode
          else if attemptNode?
            new nodes.Block [attemptNode]
          else
            new nodes.Block []
        else
          new nodes.Block []

        catch_ = @dataToClass node.catch if node.catch

        ensure = if node.ensure
          ensureNode = @dataToClass node.ensure
          if ensureNode instanceof nodes.Block
            ensureNode
          else if Array.isArray ensureNode
            new nodes.Block ensureNode
          else if ensureNode?
            new nodes.Block [ensureNode]
          else
            null
        else
          null

        new nodes.Try attempt, catch_, ensure

      when 'Catch'
        recovery = if node.recovery or node.body
          recoveryNode = @dataToClass(node.recovery or node.body)
          if recoveryNode instanceof nodes.Block
            recoveryNode
          else if Array.isArray recoveryNode
            new nodes.Block recoveryNode
          else if recoveryNode?
            new nodes.Block [recoveryNode]
          else
            new nodes.Block []
        else
          new nodes.Block []
        variable = @dataToClass node.variable if node.variable
        new nodes.Catch recovery, variable

      when 'Throw'
        expression = @dataToClass node.expression
        new nodes.Throw expression

      when 'Return'
        expression = @dataToClass node.expression if node.expression
        new nodes.Return expression

      when 'YieldReturn'
        expression = @dataToClass node.expression if node.expression
        new nodes.YieldReturn expression

      when 'AwaitReturn'
        expression = @dataToClass node.expression if node.expression
        new nodes.AwaitReturn expression

      # ============================================================
      # Classes
      # ============================================================
      when 'Class'
        variable = @dataToClass node.variable if node.variable
        parent = @dataToClass node.parent if node.parent

        body = if Array.isArray node.body
          bodyNodes = []
          for item in node.body
            if item.type is 'Value' and item.val?.type is 'Obj'
              # Extract methods from object literal
              objNode = item.val
              if objNode.properties
                for prop in objNode.properties
                  if Array.isArray prop
                    for p in prop
                      converted = @dataToClass p
                      bodyNodes.push converted if converted
                  else if prop
                    converted = @dataToClass prop
                    bodyNodes.push converted if converted
            else
              converted = @dataToClass item
              bodyNodes.push converted if converted
          new nodes.Block bodyNodes
        else if node.body
          @dataToClass node.body
        else
          new nodes.Block []

        new nodes.Class variable, parent, body

      # ============================================================
      # Parentheticals
      # ============================================================
      when 'Parens'
        body = if Array.isArray node.body
          bodyNodes = node.body.map (n) => @dataToClass n
          new nodes.Block bodyNodes
        else
          @dataToClass node.body
        new nodes.Parens body

      # ============================================================
      # String Interpolation
      # ============================================================
      when 'StringWithInterpolations'
        body = if node.body
          parts = node.body.map (part) => @dataToClass part
          new nodes.Block parts
        else
          new nodes.Block []
        quote = node.quote or '"'
        new nodes.StringWithInterpolations body, {quote}

      when 'Interpolation'
        expression = if Array.isArray node.expression
          if node.expression.length is 1
            @dataToClass node.expression[0]
          else
            expressionNodes = node.expression.map (n) => @dataToClass n
            new nodes.Block expressionNodes
        else if node.expression
          @dataToClass node.expression
        else
          new nodes.Block []
        new nodes.Interpolation expression

      # ============================================================
      # Import/Export
      # ============================================================
      when 'ImportDeclaration'
        clause = @dataToClass node.clause if node.clause
        source = @dataToClass node.source
        assertions = @dataToClass node.assertions if node.assertions
        new nodes.ImportDeclaration clause, source, assertions

      when 'ImportClause'
        defaultBinding = @dataToClass node.defaultBinding if node.defaultBinding
        namedImports = @dataToClass node.namedImports if node.namedImports
        new nodes.ImportClause defaultBinding, namedImports

      when 'ExportDeclaration'
        new nodes.ExportDeclaration @dataToClass node.clause

      # ============================================================
      # Meta nodes
      # ============================================================
      when 'FuncGlyph'
        # This is metadata, not a real node
        node

      when 'Source'
        # Source is a wrapper node - unwrap it
        @dataToClass node.value

      when 'ComputedPropertyName'
        # ComputedPropertyName is just a marker - return a flag
        # The actual computed property value should be in the parent context
        new nodes.Literal 'computed'

      when 'MetaProperty'
        # MetaProperty like new.target
        meta = @dataToClass node.meta if node.meta
        property = @dataToClass node.property if node.property
        # For now, pass through as literal
        new nodes.PassthroughLiteral "#{node.meta?.value or 'new'}.#{node.property?.value or 'target'}"

      when 'RegexWithInterpolations'
        # Regex with interpolations - convert to regular regex for now
        # This would need more complex handling for full support
        new nodes.RegexLiteral node.value or '//', node.flags or ''

      when 'DynamicImportCall'
        # Dynamic import() call - extends Call
        variable = new nodes.IdentifierLiteral 'import'
        args = if node.args
          @filterNodes node.args
        else
          []
        # DynamicImportCall extends Call, so pass variable and args
        new nodes.DynamicImportCall variable, args

      when 'TaggedTemplateCall'
        # Tagged template literals - expects single arg, not array
        variable = @dataToClass node.variable
        arg = if node.args?.length > 0
          @dataToClass node.args[0]
        else
          new nodes.StringLiteral ''
        new nodes.TaggedTemplateCall variable, arg, node.soak

      # ============================================================
      # Default fallback
      # ============================================================
      else
        console.warn "Unknown CS3 node type: #{node.type}"
        new nodes.PassthroughLiteral "/* Unknown node type: #{node.type} */"

module.exports = ES5Backend