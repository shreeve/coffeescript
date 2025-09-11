#!/usr/bin/env coffee

# ==============================================================================
# CS3 ES5 Backend - Bridge CS3 Data Nodes to CoffeeScript's Existing Compiler
# ==============================================================================
#
# This backend converts CS3 data-oriented AST nodes back into CoffeeScript's
# class-based nodes, then uses the existing CoffeeScript compiler to generate
# JavaScript. This gives us an immediate working pipeline!
#
# Once this works perfectly and passes all tests, we can evolve it into a
# true ES6 backend with modern JavaScript features.
# ==============================================================================

# Import CoffeeScript's node classes
nodes = require '../../lib/coffeescript/nodes'

class ES5Backend
  constructor: (@options = {}) ->
    # Options will be passed to CoffeeScript's compile
    @compileOptions =
      bare: @options.bare ? true
      header: @options.header ? false
      sourceMap: @options.sourceMap ? false
      inlineMap: @options.inlineMap ? false

  # Main entry point - convert CS3 data node to JavaScript
  generate: (dataNode) ->
    # Convert CS3 data node to CoffeeScript class node
    classNode = @dataToClass dataNode

    # Use CoffeeScript's existing compile method
    result = classNode.compile @compileOptions

    # Return either the code string or {js, sourceMap} object
    if @compileOptions.sourceMap
      result
    else
      result

  # Convert CS3 data nodes to CoffeeScript class nodes
  dataToClass: (node) ->
    return null unless node

    # Handle primitives
    if typeof node in ['string', 'number', 'boolean']
      return node

    # Handle arrays
    if Array.isArray node
      return node.map (item) => @dataToClass item

    # Must be an object with a type
    return null unless node.type

    # Convert based on node type
    switch node.type
      # Root and structural nodes
      when 'Root'
        # Root expects a Block, not an array
        bodyNodes = if Array.isArray node.body
          # Filter out null body nodes
          node.body.map((item) => @dataToClass item).filter (item) -> item?
        else if node.body
          converted = @dataToClass node.body
          if converted? then [converted] else []
        else
          []
        body = new nodes.Block bodyNodes
        new nodes.Root body

      when 'Block'
        expressions = if node.expressions
          converted = @dataToClass node.expressions
          # Filter out null values and ensure we have an array
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

      # Literals
      when 'NumberLiteral'
        new nodes.NumberLiteral node.value, node.parsedValue

      when 'StringLiteral'
        # StringLiteral expects the raw string content (without quotes)
        # and a quote character to be provided
        # Default to double quotes if not specified
        quote = node.quote or '"'
        # Ensure we have the actual string value
        value = node.value or ''
        # Create the StringLiteral with location data
        stringNode = new nodes.StringLiteral value, {quote}
        # Add location data if available
        if node.locationData
          stringNode.locationData = node.locationData
        else
          # Provide a default location data to prevent crashes
          stringNode.locationData = 
            first_line: 0
            first_column: 0
            last_line: 0
            last_column: 0
            last_line_exclusive: 0
            last_column_exclusive: 0
            range: [0, 0]
        # Also set originalValue which is used by withoutQuotesInLocationData
        stringNode.originalValue = value
        stringNode

      when 'Literal'
        # Generic literal node (used for tokens, operators, etc.)
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

      when 'Super'
        accessor = @dataToClass node.accessor
        new nodes.Super accessor

      when 'RegexLiteral'
        new nodes.RegexLiteral node.value,
          delimiter: node.delimiter
          heregexCommentTokens: node.heregexCommentTokens

      when 'PassthroughLiteral'
        new nodes.PassthroughLiteral node.value,
          here: node.here
          generated: node.generated

      # Values and properties
      when 'Value'
        base = @dataToClass(node.val or node.base or node.value)
        properties = if node.properties
          node.properties.map (prop) => @dataToClass prop
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
        index = @dataToClass node.object or node.name
        indexNode = new nodes.Index index
        indexNode.soak = node.soak if node.soak
        indexNode

      # Assignment
      when 'Assign'
        # Handle object property assignments differently
        if node.context is 'object' and node.expression
          # Object property: node.value is the key, node.expression is the value
          variable = @dataToClass node.value
          value = @dataToClass node.expression
        else
          # Regular assignment
          variable = @dataToClass node.variable
          value = @dataToClass node.value

        # Ensure we have valid nodes
        if not variable? or not value?
          return null

        context = node.context
        options = {}
        options.param = node.param if node.param
        options.subpattern = node.subpattern if node.subpattern

        # Handle operatorToken carefully - it might be a data node
        if node.operatorToken
          if typeof node.operatorToken is 'object' and node.operatorToken.type
            # It's a data node, just use its value
            options.operatorToken =
              value: node.operatorToken.value
              locationData: node.operatorToken.locationData
          else
            options.operatorToken = @dataToClass node.operatorToken

        options.moduleDeclaration = node.moduleDeclaration if node.moduleDeclaration
        new nodes.Assign variable, value, context, options

      # Operations
      when 'Op'
        # CS3 uses args: [operator, first, second, ...] format
        if node.args
          [op, first, second, flip] = node.args
          op = op.toString() if typeof op is 'object'
          first = @dataToClass first
          second = @dataToClass second if second
          
          # Build options for Op constructor
          options = {}
          options.invertOperator = node.invertOperator if node.invertOperator
          options.originalOperator = node.originalOperator if node.originalOperator
          
          # Op constructor signature: (op, first, second, flip, options)
          new nodes.Op op, first, second, flip, options
        else
          # Fallback to named properties
          op = node.operator or node.op
          first = @dataToClass node.first
          second = @dataToClass node.second if node.second
          new nodes.Op op, first, second, node.flip

      when 'Existence'
        expression = @dataToClass node.expression
        new nodes.Existence expression

      # Functions and calls
      when 'Code'
        params = if node.params
          # Filter out null params that might come from CS3 conversion
          node.params.map((param) => @dataToClass param).filter (param) -> param?
        else
          []
        # Code expects a Block for body
        bodyNodes = if Array.isArray node.body
          # Filter out null body nodes
          node.body.map((item) => @dataToClass item).filter (item) -> item?
        else if node.body
          converted = @dataToClass node.body
          if converted? then [converted] else []
        else
          []
        body = new nodes.Block bodyNodes
        funcGlyph = node.funcGlyph?.glyph or '->'
        tag = funcGlyph is '=>' and 'boundfunc' or null
        new nodes.Code params, body, tag

      when 'Param'
        name = @dataToClass node.name
        value = @dataToClass node.value if node.value
        splat = node.splat
        new nodes.Param name, value, splat

      when 'FuncGlyph'
        # This is metadata, not a real node
        node

      when 'Call'
        variable = @dataToClass node.variable
        args = if node.args
          # Filter out null arguments and ensure all are proper nodes
          convertedArgs = []
          for arg in node.args
            converted = @dataToClass arg
            # Only add if it's a proper node (has compileToFragments method)
            if converted? and (converted.compileToFragments or converted instanceof nodes.Base)
              convertedArgs.push converted
            else if converted? and typeof converted in ['string', 'number', 'boolean']
              # Wrap primitives in Literal nodes
              convertedArgs.push new nodes.Literal String(converted)
          convertedArgs
        else
          []
        soak = node.soak
        new nodes.Call variable, args, soak

      when 'SuperCall'
        args = if node.args
          # Filter out null arguments that might come from CS3 conversion
          node.args.map((arg) => @dataToClass arg).filter (arg) -> arg?
        else
          []
        new nodes.SuperCall args

      # Arrays and objects
      when 'Arr'
        objects = if node.objects
          # Flatten and process the objects array
          result = []
          for obj in node.objects
            # Handle nested arrays (from the parser)
            if Array.isArray(obj)
              # Unwrap single-element arrays
              if obj.length is 1
                converted = @dataToClass obj[0]
                result.push converted if converted
            else if typeof obj is 'object' and Object.keys(obj).length > 0
              # Non-empty objects
              converted = @dataToClass obj
              result.push converted if converted
          result
        else if node.value
          # Handle value array (e.g., empty array case)
          if Array.isArray(node.value)
            # Filter out empty objects
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
          # Flatten properties array in case it contains nested arrays
          result = []
          for prop in node.properties
            if Array.isArray(prop)
              # Flatten nested array
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
        # Slice wraps a Range in CS3
        @dataToClass node.range

      # Control flow
      when 'If', 'if', 'unless'
        condition = @dataToClass node.condition
        body = if Array.isArray node.body
          # Convert array of nodes to Block with converted nodes
          bodyNodes = node.body.map (n) => @dataToClass n
          new nodes.Block bodyNodes
        else
          @dataToClass node.body
        options = {}
        options.type = node.type if node.type
        options.postfix = node.postfix if node.postfix

        # Create the If node
        ifNode = new nodes.If condition, body, options

        # If there's an else clause, add it
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
        # Convert body first
        body = if Array.isArray node.body
          bodyNodes = node.body.map (n) =>
            converted = @dataToClass n
            # Ensure each node has locationData
            converted.locationData ?= {
              first_line: 0
              first_column: 0
              last_line: 0
              last_column: 0
              range: [0, 0]
            } if converted
            converted
          new nodes.Block bodyNodes
        else if node.body
          @dataToClass node.body
        else
          new nodes.Block []

        # Add dummy locationData to body to prevent errors
        defaultLocationData = {
          first_line: 0
          first_column: 0
          last_line: 0
          last_column: 0
          range: [0, 0]
        }
        body.locationData ?= defaultLocationData

        # Ensure expressions have locationData too
        if body.expressions
          for expr in body.expressions
            expr.locationData ?= defaultLocationData

        # Convert source and build ForSource object
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

        # Create For node with body and source object
        forNode = new nodes.For body, sourceObj

        forNode

      when 'Source'
        # Source is a wrapper node in CS3 - unwrap it
        @dataToClass node.value

      when 'Switch'
        subject = @dataToClass node.subject
        cases = if node.cases
          node.cases.map (c) => @dataToClass c
        else
          []
        # Otherwise clause expects a Block
        otherwise = if node.otherwise
          otherwiseNode = @dataToClass node.otherwise
          # Wrap in Block if not already
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
        # Body should be a Block
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
        # Attempt should be a Block
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
        # Ensure should be a Block too
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
        # Recovery should be a Block
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

      # Classes
      when 'Class'
        variable = @dataToClass node.variable if node.variable
        parent = @dataToClass node.parent if node.parent

        # Body is an array of nodes
        body = if Array.isArray node.body
          # Check if the body contains an Obj node (which holds the methods)
          # CS3 represents class methods as an object literal
          bodyNodes = []
          for item in node.body
            if item.type is 'Value' and item.val?.type is 'Obj'
              # Extract the properties from the Obj node as individual methods
              objNode = item.val
              if objNode.properties
                for prop in objNode.properties
                  if Array.isArray(prop)
                    # Handle nested arrays (multi-line objects)
                    for p in prop
                      converted = @dataToClass p
                      bodyNodes.push converted if converted
                  else if prop
                    converted = @dataToClass prop
                    bodyNodes.push converted if converted
            else
              # Regular body node
              converted = @dataToClass item
              bodyNodes.push converted if converted
          new nodes.Block bodyNodes
        else if node.body
          @dataToClass node.body
        else
          new nodes.Block []

        new nodes.Class variable, parent, body

      # Splats and expansions
      when 'Splat'
        name = @dataToClass node.name or node.body
        new nodes.Splat name

      when 'Expansion'
        new nodes.Expansion()

      # Parentheticals
      when 'Parens'
        body = if Array.isArray node.body
          # If body is an array, wrap in Block
          bodyNodes = node.body.map (n) => @dataToClass n
          new nodes.Block bodyNodes
        else
          @dataToClass node.body
        new nodes.Parens body

      # String interpolation
      when 'StringWithInterpolations'
        # The body should be a Block containing the parts
        body = if node.body
          parts = node.body.map (part) => @dataToClass part
          new nodes.Block parts
        else
          new nodes.Block []
        quote = node.quote or '"'
        new nodes.StringWithInterpolations body, {quote}

      when 'Interpolation'
        expression = if Array.isArray node.expression
          # For single-element arrays, just use the element
          if node.expression.length is 1
            @dataToClass node.expression[0]
          else
            # Wrap multiple expressions in Block
            expressionNodes = node.expression.map (n) => @dataToClass n
            new nodes.Block expressionNodes
        else if node.expression
          @dataToClass node.expression
        else
          new nodes.Block []
        new nodes.Interpolation expression

      # Import/Export
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
        # Handle various export types
        new nodes.ExportDeclaration(@dataToClass node.clause)

      # Default case - warn and return a comment
      else
        console.warn "Unknown CS3 node type: #{node.type}"
        new nodes.PassthroughLiteral "/* Unknown node type: #{node.type} */"

# Export the backend
module.exports = ES5Backend
