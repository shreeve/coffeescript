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
      return (@dataToClass item for item in node)

    # Must be an object with a type
    return null unless node.type

    # Convert based on node type
    switch node.type
      # Root and structural nodes
      when 'Root'
        # Root expects a Block, not an array
        bodyNodes = if Array.isArray node.body
          @dataToClass item for item in node.body
        else if node.body
          [@dataToClass node.body]
        else
          []
        body = new nodes.Block bodyNodes
        new nodes.Root body

      when 'Block'
        expressions = if node.expressions
          @dataToClass node.expressions
        else if node.body
          @dataToClass node.body
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
        new nodes.StringLiteral value, {quote}

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
          @dataToClass prop for prop in node.properties
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
          new nodes.Op op, first, second, flip
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
          @dataToClass param for param in node.params
        else
          []
        # Code expects a Block for body
        bodyNodes = if Array.isArray node.body
          @dataToClass item for item in node.body
        else if node.body
          [@dataToClass node.body]
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
          @dataToClass arg for arg in node.args
        else
          []
        soak = node.soak
        new nodes.Call variable, args, soak

      when 'SuperCall'
        args = if node.args
          @dataToClass arg for arg in node.args
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
          @dataToClass prop for prop in node.properties when prop
        else
          []
        generated = node.generated
        new nodes.Obj properties, generated

      when 'Range'
        from = @dataToClass node.from
        to = @dataToClass node.to
        tag = if node.exclusive then 'exclusive' else 'inclusive'
        new nodes.Range from, to, tag

      # Control flow
      when 'If', 'if'
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
          bodyNodes = node.body.map (n) => @dataToClass n
          new nodes.Block bodyNodes
        else if node.body
          @dataToClass node.body
        else
          new nodes.Block []

        # Add dummy locationData to body to prevent errors
        body.locationData ?= {first_line: 0, first_column: 0, last_line: 0, last_column: 0}

        # Convert source (handle ForSource object)
        source = @dataToClass node.source

        # Create For node with body and source
        forNode = new nodes.For body, {source}

        # Set other properties
        forNode.guard = @dataToClass node.guard if node.guard
        forNode.step = @dataToClass node.step if node.step
        forNode.name = @dataToClass node.name if node.name
        forNode.index = @dataToClass node.index if node.index
        forNode.object = node.object if node.object
        forNode.from = node.from if node.from
        forNode.own = node.own if node.own
        forNode.await = node.await if node.await

        forNode

      when 'Source'
        # Source is a wrapper node in CS3 - unwrap it
        @dataToClass node.value

      when 'Switch'
        subject = @dataToClass node.subject
        cases = if node.cases
          @dataToClass c for c in node.cases
        else
          []
        otherwise = @dataToClass node.otherwise if node.otherwise
        new nodes.Switch subject, cases, otherwise

      when 'SwitchWhen'
        conditions = @dataToClass node.conditions
        body = @dataToClass node.body
        new nodes.SwitchWhen conditions, body

      when 'Try'
        attempt = @dataToClass node.attempt
        catch_ = @dataToClass node.catch if node.catch
        ensure = @dataToClass node.ensure if node.ensure
        new nodes.Try attempt, catch_, ensure

      when 'Catch'
        recovery = @dataToClass node.recovery or node.body
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

        # Body is an array of nodes, convert to Block
        body = if Array.isArray node.body
          bodyNodes = node.body.map (n) => @dataToClass n
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
        body = @dataToClass node.body
        new nodes.Parens body

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
