#!/usr/bin/env coffee

# ==============================================================================
# Extract Minimal Grammar Rules
#
# Extracts all grammar rules that create our 13 node types needed for square.coffee
# ==============================================================================

fs = require 'fs'
path = require 'path'

# The 13 node types we need for square.coffee
minimalNodeTypes = [
  'Root'
  'Block'
  'Code'
  'Param'
  'Value'
  'IdentifierLiteral'
  'NumberLiteral'
  'PassthroughLiteral'
  'PropertyName'
  'Assign'
  'Op'
  'Call'
  'Access'
]

# Create regex to match any of these node types
nodePattern = minimalNodeTypes.join('|')
regex = new RegExp("new\\s+(#{nodePattern})\\b", 'g')

# Read grammar file
grammarPath = path.join(__dirname, 'grammar.coffee')
content = fs.readFileSync(grammarPath, 'utf8')
lines = content.split('\n')

# Extract rules
rules = []
inGrammar = false
currentRule = null
collectingAction = false
actionLines = []
actionIndent = 0

for line, i in lines
  # Check if we're entering grammar section
  if line.match(/^grammar\s*=/)
    inGrammar = true
    continue

  continue unless inGrammar

  # Check for rule definition (o function call)
  if match = line.match(/^(\s*)o\s+'([^']+)'(.*)$/)
    indent = match[1].length
    pattern = match[2]
    rest = match[3]

    # If we were collecting an action, save it
    if collectingAction and currentRule
      currentRule.action = actionLines.join('\n')
      if currentRule.action.match(regex)
        rules.push currentRule

    # Start new rule
    currentRule =
      line: i + 1
      pattern: pattern
      indent: indent
      action: null

    # Check if action starts on same line
    if arrowMatch = rest.match(/\s*(?:,\s*[^,]+)?\s*->\s*(.*)$/)
      action = arrowMatch[1].trim()
      if action
        # Single-line action
        currentRule.action = action
        if action.match(regex)
          rules.push currentRule
        currentRule = null
        collectingAction = false
      else
        # Multi-line action starting
        collectingAction = true
        actionLines = []
        actionIndent = indent

  else if collectingAction
    # Check if we're still in the action
    currentIndent = line.match(/^(\s*)/)?[0].length or 0

    if currentIndent > actionIndent or line.trim() is ''
      # Still part of the action
      actionLines.push line
    else
      # End of action
      if currentRule
        currentRule.action = actionLines.join('\n')
        if currentRule.action.match(regex)
          rules.push currentRule

      currentRule = null
      collectingAction = false
      actionLines = []

# Handle last rule if needed
if collectingAction and currentRule
  currentRule.action = actionLines.join('\n')
  if currentRule.action.match(regex)
    rules.push currentRule

# Group rules by node type
rulesByType = {}
for nodeType in minimalNodeTypes
  rulesByType[nodeType] = []

for rule in rules
  for nodeType in minimalNodeTypes
    if rule.action.match(new RegExp("new\\s+#{nodeType}\\b"))
      rulesByType[nodeType].push rule

# Output results
console.log "=" .repeat 80
console.log "EXTRACTED MINIMAL GRAMMAR RULES"
console.log "=" .repeat 80
console.log()
console.log "Found #{rules.length} rules that create our 13 minimal node types:"
console.log()

for nodeType in minimalNodeTypes
  typeRules = rulesByType[nodeType]
  if typeRules.length > 0
    console.log "#{nodeType} (#{typeRules.length} rules):"
    console.log "-" .repeat 40
    for rule in typeRules[0..2]  # Show first 3 examples
      console.log "  Line #{rule.line}: o '#{rule.pattern}' -> #{rule.action.trim().slice(0, 60)}..."
    if typeRules.length > 3
      console.log "  ... and #{typeRules.length - 3} more"
    console.log()

# Save to file for transformation
output =
  nodeTypes: minimalNodeTypes
  rules: rules
  rulesByType: rulesByType

outputPath = path.join(__dirname, '..', 'work', 'minimal-grammar-rules.json')
fs.writeFileSync(outputPath, JSON.stringify(output, null, 2))

console.log "=" .repeat 80
console.log "Saved to:", outputPath
console.log "=" .repeat 80
