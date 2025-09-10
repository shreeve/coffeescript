#!/usr/bin/env coffee

# ==============================================================================
# CS3 Transform Grammar - Convert grammar.coffee to data-oriented syntax.coffee
#
# This script transforms the class-based CoffeeScript grammar into a
# data-oriented grammar using our finalized CS3 directives:
#   $ast, $ref, $obj, $seq, $ops, $ary, $ite, $pos, $var, $use
# ==============================================================================

fs = require 'fs'
path = require 'path'

# Statistics tracking
stats =
  totalRules: 0
  simplePassthrough: 0
  astCreation: 0
  arrayCreation: 0
  operations: 0
  sequences: 0
  conditionals: 0
  errors: []

# Transform a single action string to data-oriented format
transformAction = (actionStr, ruleName) ->
  return null unless actionStr
  
  stats.totalRules++
  original = actionStr
  
  try
    # Remove LOC() calls for now (will add $pos later)
    cleaned = actionStr.replace(/LOC\(\d+(?:,\s*\d+)?\)\s*\(/g, '(')
    
    # Simple passthrough: just $1, $2, etc.
    if cleaned.match(/^\$\d+$/)
      stats.simplePassthrough++
      return "$ref: #{cleaned.slice(1)}"
    
    # Array literal: [$1], [$1, $2], etc.
    if match = cleaned.match(/^\[(.*)\]$/)
      stats.arrayCreation++
      elements = match[1].split(/,\s*/).map (el) ->
        if el.match(/^\$\d+$/)
          "$ref: #{el.slice(1)}"
        else
          transformExpression(el)
      return "$ary: [#{elements.join(', ')}]"
    
    # Block.wrap special case
    if match = cleaned.match(/^Block\.wrap\s*\[(.*?)\]$/)
      stats.operations++
      args = match[1]
      if args.match(/^\$\d+$/)
        return "$ops: 'Block.wrap', args: [{$ref: #{args.slice(1)}}]"
      else
        return "$ops: 'Block.wrap', args: [#{transformExpression(args)}]"
    
    # Method calls: $1.push $2, $1.concat $2, etc.
    if match = cleaned.match(/^(\$\d+)\.(push|concat|add|slice|toString|unwrap)\s*(.*)$/)
      stats.operations++
      target = match[1]
      method = match[2]
      args = match[3]
      
      targetRef = "$ref: #{target.slice(1)}"
      
      if args
        # Parse arguments
        argList = parseArguments(args)
        return "$ops: '#{method}', target: {#{targetRef}}, args: [#{argList}]"
      else
        return "$ops: '#{method}', target: {#{targetRef}}"
    
    # Property access: $1.prop
    if match = cleaned.match(/^(\$\d+)\.(\w+)$/)
      return "$ref: #{match[1].slice(1)}, prop: '#{match[2]}'"
    
    # new ClassName(...) - AST node creation
    if match = cleaned.match(/^new\s+(\w+)\s*(.*)$/)
      stats.astCreation++
      className = match[1]
      args = match[2]
      
      # Check if type matches rule name (use '@')
      useAtSymbol = className.toLowerCase() == ruleName.toLowerCase()
      typeValue = if useAtSymbol then "'@'" else "'#{className}'"
      
      # Parse constructor arguments
      if args and args != '()'
        props = parseConstructorArgs(args, className)
        if props
          return "$ast: #{typeValue}#{props}"
      
      return "$ast: #{typeValue}"
    
    # Assignment: $1.prop = value
    if match = cleaned.match(/^(\$\d+)\.(\w+)\s*=\s*(.+)$/)
      stats.operations++
      target = "$ref: #{match[1].slice(1)}"
      prop = match[2]
      value = transformExpression(match[3])
      return "$ops: 'set', target: {#{target}}, prop: '#{prop}', value: #{value}"
    
    # Ternary: condition ? then : else
    if match = cleaned.match(/^(.+?)\s*\?\s*(.+?)\s*:\s*(.+)$/)
      stats.conditionals++
      test = transformExpression(match[1])
      thenVal = transformExpression(match[2])
      elseVal = transformExpression(match[3])
      return "$ite: {test: #{test}, then: #{thenVal}, else: #{elseVal}}"
    
    # Complex multi-statement (contains semicolon)
    if cleaned.indexOf(';') > -1
      stats.sequences++
      statements = cleaned.split(/;\s*/)
      ops = statements.map (stmt) -> transformExpression(stmt.trim())
      return "$seq: [#{ops.join(', ')}]"
    
    # If we can't transform it, keep the original for manual review
    stats.errors.push
      rule: ruleName
      action: original
      reason: "Could not transform"
    
    # Return original wrapped in a comment for manual review
    "# TODO: Transform manually: #{original}"
    
  catch error
    stats.errors.push
      rule: ruleName
      action: original
      reason: error.message
    "# ERROR: #{error.message} - Original: #{original}"

# Parse constructor arguments for AST nodes
parseConstructorArgs = (argsStr, className) ->
  # Remove outer parens if present
  argsStr = argsStr.replace(/^\s*\(\s*/, '').replace(/\s*\)\s*$/, '')
  return '' unless argsStr
  
  # Check for known patterns
  # Simple single argument
  if match = argsStr.match(/^(\$\d+)$/)
    return ", base: $ref: #{match[1].slice(1)}"
  
  # Two arguments
  if match = argsStr.match(/^(\$\d+),\s*(\$\d+)$/)
    return ", first: $ref: #{match[1].slice(1)}, second: $ref: #{match[2].slice(1)}"
  
  # Three arguments
  if match = argsStr.match(/^(\$\d+),\s*(\$\d+),\s*(\$\d+)$/)
    return ", first: $ref: #{match[1].slice(1)}, second: $ref: #{match[2].slice(1)}, third: $ref: #{match[3].slice(1)}"
  
  # String literal first (operator pattern)
  if match = argsStr.match(/^['"]([^'"]+)['"]\s*,\s*(.+)$/)
    return ", operator: '#{match[1]}', operand: #{transformExpression(match[2])}"
  
  # Object literal
  if match = argsStr.match(/^\{(.+)\}$/)
    return ", #{match[1]}"
  
  # Default: try to parse as comma-separated values
  parts = argsStr.split(/,\s*/)
  if parts.length == 1
    ", value: #{transformExpression(parts[0])}"
  else
    props = parts.map((p, i) -> "arg#{i+1}: #{transformExpression(p)}").join(', ')
    ", #{props}"

# Transform a sub-expression
transformExpression = (expr) ->
  return "{}" unless expr
  expr = expr.trim()
  
  # Dollar reference
  if expr.match(/^\$\d+$/)
    return "{$ref: #{expr.slice(1)}}"
  
  # String literal
  if expr.match(/^['"]/)
    return expr
  
  # Boolean/null/undefined
  if expr in ['true', 'false', 'null', 'undefined', 'yes', 'no', 'on', 'off']
    return expr
  
  # Number
  if expr.match(/^\d+$/)
    return expr
  
  # new ClassName(...)
  if match = expr.match(/^new\s+(\w+)/)
    className = match[1]
    return "{$ast: '#{className}'}"
  
  # Property access
  if match = expr.match(/^(\$\d+)\.(\w+)$/)
    return "{$ref: #{match[1].slice(1)}, prop: '#{match[2]}'}"
  
  # Array
  if match = expr.match(/^\[(.*)\]$/)
    elements = match[1].split(/,\s*/).map (el) -> transformExpression(el.trim())
    return "{$ary: [#{elements.join(', ')}]}"
  
  # Default: wrap in quotes as string
  "'#{expr}'"

# Parse function arguments
parseArguments = (argsStr) ->
  return "" unless argsStr
  
  # Remove outer parens
  argsStr = argsStr.replace(/^\s*\(/, '').replace(/\)\s*$/, '')
  return "" unless argsStr
  
  # Split by comma and transform each
  parts = argsStr.split(/,\s*/)
  parts.map((arg) -> transformExpression(arg.trim())).join(', ')

# Main transformation
grammarPath = path.join(__dirname, 'grammar.coffee')
grammarContent = fs.readFileSync(grammarPath, 'utf8')

lines = grammarContent.split('\n')
outputLines = []
inGrammar = false
currentRule = null

# Add CS3 header
outputLines.push """# ==============================================================================
# CS3 Syntax - Data-Oriented Grammar for CoffeeScript 3
#
# Automatically generated from grammar.coffee
# 
# KEY CHANGES:
# - Actions are pure data objects, NOT functions
# - Uses CS3 directives: $ast, $ref, $obj, $seq, $ops, $ary, $ite
# - Export key is 'grammar' not 'bnf' to signal data-oriented format
#
# EXAMPLES:
#   Old: o 'Body', -> new Root $1
#   New: o 'Body', $ast: 'Root', body: $ref: 1
# ==============================================================================

"""

# Process each line
for line, i in lines
  # Keep first few comment lines
  if i < 15 and line.match(/^#/)
    outputLines.push line
    continue
  
  # Skip the old 'o' function definition
  if line.match(/^o\s*=\s*\(/) and not inGrammar
    # Add our new o function for pure data
    outputLines.push """
# CS3: The 'o' function now handles pure data actions
o = (patternString, action, options) ->
  patternString = patternString.replace /\\s{2,}/g, ' '
  # Action is now a data object, not a function
  [patternString, action, options]
"""
    # Skip the rest of the old o function
    while i < lines.length - 1 and not lines[i+1].match(/^[a-z]/i)
      i++
    continue
  
  # Skip the unwrap variable
  if line.match(/^unwrap\s*=/)
    continue
  
  # Grammar section starts
  if line.match(/^grammar\s*=/)
    inGrammar = true
    outputLines.push ""
    outputLines.push "# CS3 Grammar Rules"
    outputLines.push "grammar ="
    continue
  
  if inGrammar
    # Track current rule name
    if match = line.match(/^\s*(\w+):\s*\[/)
      currentRule = match[1]
      outputLines.push line
      continue
    
    # Transform rules with actions
    if match = line.match(/^(\s*)o\s+'([^']+)'(?:\s*,\s*->\s*(.+))?$/)
      indent = match[1]
      pattern = match[2]
      action = match[3]
      
      if action
        transformed = transformAction(action, currentRule)
        if transformed
          # Format for clean CoffeeScript
          if transformed.indexOf(',') > -1 or transformed.indexOf('{') > -1
            # Multi-line for complex objects
            outputLines.push "#{indent}o '#{pattern}',"
            outputLines.push "#{indent}  #{transformed}"
          else
            outputLines.push "#{indent}o '#{pattern}', #{transformed}"
        else
          outputLines.push line
      else
        # No action, passthrough
        outputLines.push line
    else
      outputLines.push line
  else
    # Keep operators and other definitions
    if line.match(/^operators\s*=/) or line.match(/^\s+\[/)
      outputLines.push line
    else if not line.match(/^(unwrap|getAddDataToNodeFunctionString|performActionFunctionString)/)
      outputLines.push line

# Join output
outputContent = outputLines.join('\n')

# Update module.exports - use 'grammar' instead of 'bnf'
outputContent = outputContent.replace(
  /module\.exports\s*=[\s\S]*$/,
  """
# CS3: Export with 'grammar' key to signal data-oriented format
module.exports =
  grammar: grammar      # Changed from 'bnf' to 'grammar' for CS3
  operators: operators.reverse() if operators?
  start: 'Root'
"""
)

# Write output
syntaxPath = path.join(__dirname, 'syntax.coffee')
fs.writeFileSync(syntaxPath, outputContent)

# Print statistics
console.log "=" .repeat 80
console.log "CS3 GRAMMAR TRANSFORMATION COMPLETE"
console.log "=" .repeat 80
console.log()
console.log "Transformation Statistics:"
console.log "  Total rules:        #{stats.totalRules}"
console.log "  Simple passthrough: #{stats.simplePassthrough}"
console.log "  AST creation:       #{stats.astCreation}"
console.log "  Array creation:     #{stats.arrayCreation}"
console.log "  Operations:         #{stats.operations}"
console.log "  Sequences:          #{stats.sequences}"  
console.log "  Conditionals:       #{stats.conditionals}"
console.log "  Errors/TODO:        #{stats.errors.length}"
console.log()

if stats.errors.length > 0
  console.log "Items requiring manual review:"
  for err in stats.errors[0..10]
    console.log "  Rule: #{err.rule}"
    console.log "    Action: #{err.action?.slice(0, 60)}..."
    console.log "    Reason: #{err.reason}"
  if stats.errors.length > 10
    console.log "  ... and #{stats.errors.length - 10} more"
  console.log()

successRate = Math.round((stats.totalRules - stats.errors.length) / stats.totalRules * 100)
console.log "Success rate: #{successRate}%"
console.log()
console.log "Output written to: #{syntaxPath}"
console.log()
console.log "Export format: { grammar, operators, start }"
console.log "  (Not { bnf, operators, start } - this signals CS3 format)"
console.log()
console.log "Next steps:"
console.log "  1. Review and fix TODO/ERROR items"
console.log "  2. Add $pos tracking for location data"
console.log "  3. Update Solar to recognize 'grammar' vs 'bnf'"
console.log "  4. Test with Solar parser"
console.log "  5. Run full test suite"
console.log()
console.log "=" .repeat 80