#!/usr/bin/env coffee

# ==============================================================================
# Grammar Transformer V2: Class-based to Data-oriented AST
#
# More robust transformation with better pattern matching
# ==============================================================================

fs = require 'fs'
path = require 'path'

# ==============================================================================
# Transformation Functions
# ==============================================================================

transformAction = (actionStr) ->
  return actionStr unless actionStr

  # Store original for debugging
  original = actionStr
  result = actionStr

  # Step 1: Transform new Class() expressions
  result = result.replace /new\s+(\w+)(?:\s*\(((?:[^()]*|\([^)]*\))*)\))?/g, (match, className, args = '') ->
    # Handle special cases
    switch className
      when 'Root'
        if args
          "n('Program', {body: #{args}})"
        else
          "n('Program', {body: n('BlockStatement', {body: []})})"

      when 'Block'
        if args
          "n('BlockStatement', {body: #{args}})"
        else
          "n('BlockStatement', {body: []})"

      when 'Value'
        parts = args.split(/,\s*(?![^()]*\))/)  # Split on commas not in parens
        base = parts[0] or 'null'
        props = parts[1] or '[]'
        "n('Value', {base: #{base}, properties: #{props}})"

      when 'Assign'
        parts = args.split(/,\s*(?![^()]*\))/)
        left = parts[0] or 'null'
        right = parts[1] or 'null'
        op = parts[2] or "'='"
        "n('AssignmentExpression', {left: #{left}, right: #{right}, operator: #{op}})"

      when 'Op'
        parts = args.split(/,\s*(?![^()]*\))/)
        op = parts[0] or "''"
        first = parts[1] or 'null'
        second = parts[2]
        if second and second.trim() isnt '' and second.trim() isnt 'null'
          "n('BinaryOperation', {operator: #{op}, left: #{first}, right: #{second}})"
        else
          "n('UnaryOperation', {operator: #{op}, argument: #{first}, prefix: true})"

      when 'If'
        parts = args.split(/,\s*(?![^()]*\))/)
        test = parts[0] or 'null'
        consequent = parts[1] or 'null'
        extra = parts[2] or ''
        postfix = if extra.includes('postfix') then 'true' else 'false'
        "n('ConditionalExpression', {test: #{test}, consequent: #{consequent}, alternate: null, postfix: #{postfix}})"

      when 'While'
        parts = args.split(/,\s*(?![^()]*\))/)
        test = parts[0] or 'null'
        "n('WhileStatement', {test: #{test}, body: null})"

      when 'For'
        if args
          "n('ForStatement', {init: null, test: null, update: null, body: null})"
        else
          "n('ForStatement', {body: null})"

      when 'Switch'
        parts = args.split(/,\s*(?![^()]*\))/)
        discriminant = parts[0] or 'null'
        cases = parts[1] or '[]'
        "n('SwitchStatement', {discriminant: #{discriminant}, cases: #{cases}})"

      when 'SwitchWhen'
        parts = args.split(/,\s*(?![^()]*\))/)
        tests = parts[0] or '[]'
        consequent = parts[1] or 'null'
        "n('SwitchCase', {tests: #{tests}, consequent: #{consequent}})"

      when 'Try'
        parts = args.split(/,\s*(?![^()]*\))/)
        block = parts[0] or 'null'
        handler = parts[1] or 'null'
        finalizer = parts[2] or 'null'
        "n('TryStatement', {block: #{block}, handler: #{handler}, finalizer: #{finalizer}})"

      when 'Catch'
        parts = args.split(/,\s*(?![^()]*\))/)
        body = parts[0] or 'null'
        param = parts[1] or 'null'
        "n('CatchClause', {body: #{body}, param: #{param}})"

      when 'Throw'
        "n('ThrowStatement', {argument: #{args or 'null'}})"

      when 'Return'
        "n('ReturnStatement', {argument: #{args or 'null'}})"

      when 'YieldReturn'
        parts = args.split(/,\s*(?![^()]*\))/)
        arg = parts[0] or 'null'
        "n('YieldReturn', {argument: #{arg}})"

      when 'AwaitReturn'
        parts = args.split(/,\s*(?![^()]*\))/)
        arg = parts[0] or 'null'
        "n('AwaitReturn', {argument: #{arg}})"

      when 'Code'
        parts = args.split(/,\s*(?![^()]*\))/)
        params = parts[0] or '[]'
        body = parts[1] or "n('BlockStatement', {body: []})"
        "n('FunctionExpression', {params: #{params}, body: #{body}, generator: false, async: false})"

      when 'FuncGlyph'
        "n('FuncGlyph', {glyph: #{args or "''"}})"

      when 'Param'
        parts = args.split(/,\s*(?![^()]*\))/)
        name = parts[0] or 'null'
        defaultValue = parts[1] or 'null'
        "n('Parameter', {name: #{name}, default: #{defaultValue}})"

      when 'Call'
        parts = args.split(/,\s*(?![^()]*\))/)
        callee = parts[0] or 'null'
        args = parts[1] or '[]'
        "n('CallExpression', {callee: #{callee}, arguments: #{args}})"

      when 'SuperCall'
        parts = args.split(/,\s*(?![^()]*\))/)
        "n('SuperCall', {arguments: #{parts[1] or '[]'}})"

      when 'Super'
        "n('Super', {accessor: #{args or 'null'}})"

      when 'Class'
        parts = args.split(/,\s*(?![^()]*\))/)
        name = parts[0] or 'null'
        parent = parts[1] or 'null'
        body = parts[2] or 'null'
        "n('ClassExpression', {name: #{name}, superClass: #{parent}, body: #{body}})"

      when 'Literal'
        "n('Literal', {value: #{args or "''"}})"

      when 'NumberLiteral'
        "n('NumericLiteral', {value: #{args or '0'}})"

      when 'StringLiteral'
        if args.includes('{') and args.includes('quote:')
          "n('StringLiteral', #{args})"
        else
          "n('StringLiteral', {value: #{args or "''"}})"

      when 'BooleanLiteral'
        "n('BooleanLiteral', {value: #{args or 'false'}})"

      when 'NullLiteral'
        "n('NullLiteral', {value: null})"

      when 'UndefinedLiteral'
        "n('UndefinedLiteral', {value: undefined})"

      when 'ThisLiteral'
        "n('ThisExpression', {})"

      when 'IdentifierLiteral'
        "n('Identifier', {name: #{args or "''"}})"

      when 'PropertyName'
        "n('PropertyName', {value: #{args or "''"}})"

      when 'ComputedPropertyName'
        "n('ComputedPropertyName', {expression: #{args or 'null'}})"

      when 'StatementLiteral'
        "n('StatementLiteral', {value: #{args or "''"}})"

      when 'DefaultLiteral'
        "n('DefaultLiteral', {value: 'default'})"

      when 'PassthroughLiteral'
        "n('PassthroughLiteral', {value: #{args or "''"}})"

      when 'RegexLiteral'
        "n('RegexLiteral', {pattern: #{args or "''"}})"

      when 'Arr'
        "n('ArrayExpression', {elements: #{args or '[]'}})"

      when 'Obj'
        parts = args.split(/,\s*(?![^()]*\))/)
        props = parts[0] or '[]'
        "n('ObjectExpression', {properties: #{props}})"

      when 'Access'
        "n('MemberExpression', {property: #{args or 'null'}})"

      when 'Index'
        "n('ComputedMemberExpression', {property: #{args or 'null'}})"

      when 'Range'
        parts = args.split(/,\s*(?![^()]*\))/)
        from = parts[0] or 'null'
        to = parts[1] or 'null'
        exclusive = parts[2] or 'false'
        "n('Range', {from: #{from}, to: #{to}, exclusive: #{exclusive}})"

      when 'Slice'
        "n('Slice', {range: #{args or 'null'}})"

      when 'Splat'
        "n('SpreadElement', {argument: #{args or 'null'}})"

      when 'Expansion'
        "n('Expansion', {})"

      when 'Elision'
        "n('Elision', {})"

      when 'Parens'
        "n('ParenthesizedExpression', {expression: #{args or 'null'}})"

      when 'StringWithInterpolations'
        "n('TemplateLiteral', {quasis: [], expressions: #{args or '[]'}})"

      when 'Interpolation'
        "n('TemplateElement', {value: #{args or 'null'}})"

      when 'RegexWithInterpolations'
        "n('RegexWithInterpolations', {parts: #{args or '[]'}})"

      when 'MetaProperty'
        parts = args.split(/,\s*(?![^()]*\))/)
        meta = parts[0] or 'null'
        property = parts[1] or 'null'
        "n('MetaProperty', {meta: #{meta}, property: #{property}})"

      when 'DynamicImport'
        "n('DynamicImport', {})"

      when 'DynamicImportCall'
        "n('DynamicImportCall', {arguments: #{args or '[]'}})"

      when 'TaggedTemplateCall'
        parts = args.split(/,\s*(?![^()]*\))/)
        tag = parts[0] or 'null'
        quasi = parts[1] or 'null'
        "n('TaggedTemplateExpression', {tag: #{tag}, quasi: #{quasi}})"

      when 'JSXTag'
        "n('JSXElement', {name: #{args or 'null'}})"

      when 'Existence'
        "n('ExistenceCheck', {argument: #{args or 'null'}})"

      # Import/Export nodes
      when 'ImportDeclaration'
        "n('ImportDeclaration', {specifiers: null, source: #{args or 'null'}})"

      when 'ImportClause'
        "n('ImportClause', {specifiers: #{args or '[]'}})"

      when 'ImportSpecifier'
        "n('ImportSpecifier', {imported: #{args or 'null'}, local: null})"

      when 'ImportDefaultSpecifier'
        "n('ImportDefaultSpecifier', {local: #{args or 'null'}})"

      when 'ImportNamespaceSpecifier'
        "n('ImportNamespaceSpecifier', {local: #{args or 'null'}})"

      when 'ImportSpecifierList'
        "n('ImportSpecifierList', {specifiers: #{args or '[]'}})"

      when 'ExportNamedDeclaration'
        "n('ExportNamedDeclaration', {declaration: #{args or 'null'}})"

      when 'ExportDefaultDeclaration'
        "n('ExportDefaultDeclaration', {declaration: #{args or 'null'}})"

      when 'ExportAllDeclaration'
        "n('ExportAllDeclaration', {source: #{args or 'null'}})"

      when 'ExportSpecifier'
        "n('ExportSpecifier', {exported: #{args or 'null'}, local: null})"

      when 'ExportSpecifierList'
        "n('ExportSpecifierList', {specifiers: #{args or '[]'}})"

      else
        # Unknown class, just make generic node
        if args
          "n('#{className}', {args: #{args}})"
        else
          "n('#{className}')"

  # Step 2: Transform Block.wrap
  result = result.replace /Block\.wrap\s*\((.*?)\)/g, (match, content) ->
    "n('BlockStatement', {body: #{content}, implicit: true})"

  # Step 3: Remove LOC calls (they wrap location data)
  # LOC(1)(expression) -> expression
  # LOC(1,2)(expression) -> expression
  result = result.replace /LOC\([^)]+\)\s*\(([^(].*?)\)/g, '$1'

  # Step 4: Transform extend calls
  result = result.replace /\bextend\s*\((.*?),\s*(.*?)\)/g,
    "Object.assign($1, $2)"

  # Step 5: Remove yy. prefix
  result = result.replace /\byy\./g, ''

  result

# ==============================================================================
# File Processing
# ==============================================================================

processGrammarFile = (inputPath, outputPath) ->
  console.log "📝 Reading #{inputPath}..."

  input = fs.readFileSync inputPath, 'utf8'
  lines = input.split '\n'
  output = []

  inGrammar = false
  inAction = false
  actionLines = []
  actionIndent = 0
  ruleCount = 0
  transformCount = 0

  for line, i in lines
    # Track grammar section
    if line.match /^grammar\s*=/
      inGrammar = true
      output.push '# Automatically transformed from class-based to data-oriented AST'
      output.push '# Generated by transform-grammar-v2.coffee'
      output.push ''
      output.push '# Node creation helper'
      output.push "n = (type, props = {}) -> {type, ...props}"
      output.push ''
      output.push line
      continue

    if line.match /^operators\s*=/
      inGrammar = false

    if inGrammar
      # Handle o() calls with arrow functions
      if match = line.match /^(\s*)o\s+'([^']*)'(.*?)(->)\s*(.*)$/
        indent = match[1]
        pattern = match[2]
        middle = match[3]
        arrow = match[4]
        action = match[5]

        ruleCount++

        if action.trim()
          # Single-line action
          transformed = transformAction(action)
          transformCount++ if transformed isnt action
          output.push "#{indent}o '#{pattern}'#{middle}#{arrow} #{transformed}"
        else
          # Multi-line action starting
          inAction = true
          actionLines = []
          actionIndent = indent.length
          output.push line
      else if inAction
        currentIndent = line.match(/^\s*/)?[0].length or 0

        if line.trim() is '' or currentIndent > actionIndent
          # Still in action
          actionLines.push line
        else
          # Action ended - transform it
          if actionLines.length > 0
            actionStr = actionLines.join('\n')
            transformed = transformAction(actionStr)
            transformCount++ if transformed isnt actionStr
            for tLine in transformed.split('\n')
              output.push tLine

          inAction = false
          actionLines = []

          # Process current line (might be new rule)
          if match = line.match /^(\s*)o\s+'([^']*)'(.*?)(->)\s*(.*)$/
            indent = match[1]
            pattern = match[2]
            middle = match[3]
            arrow = match[4]
            action = match[5]

            ruleCount++

            if action.trim()
              transformed = transformAction(action)
              transformCount++ if transformed isnt action
              output.push "#{indent}o '#{pattern}'#{middle}#{arrow} #{transformed}"
            else
              inAction = true
              actionLines = []
              actionIndent = indent.length
              output.push line
          else
            output.push line
      else
        output.push line
    else
      output.push line

  # Handle remaining action
  if inAction and actionLines.length > 0
    actionStr = actionLines.join('\n')
    transformed = transformAction(actionStr)
    transformCount++ if transformed isnt actionStr
    for tLine in transformed.split('\n')
      output.push tLine

  console.log "📝 Writing #{outputPath}..."
  fs.writeFileSync outputPath, output.join('\n')

  console.log "✅ Success!"
  console.log "   Processed #{ruleCount} grammar rules"
  console.log "   Transformed #{transformCount} actions"

# ==============================================================================
# Main
# ==============================================================================

if require.main is module
  args = process.argv[2..]

  if args.length is 0
    inputPath = path.join(__dirname, 'src', 'grammar.coffee')
    outputPath = path.join(__dirname, 'src', 'grammar-data.coffee')
  else if args.length is 1
    inputPath = args[0]
    outputPath = inputPath.replace(/\.coffee$/, '-data.coffee')
  else
    [inputPath, outputPath] = args

  unless fs.existsSync inputPath
    console.error "❌ File not found: #{inputPath}"
    process.exit 1

  processGrammarFile inputPath, outputPath

  console.log """

  📋 Next steps:
     1. Review generated grammar
     2. Add to Cakefile: task 'build:parser-data'
     3. Test with existing test suite
  """

module.exports = {transformAction, processGrammarFile}
