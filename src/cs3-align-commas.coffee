#!/usr/bin/env coffee

# ==============================================================================
# CS3 Align Commas - Beautify syntax.coffee with aligned commas
# ==============================================================================

fs = require 'fs'
path = require 'path'

# Read syntax.coffee
syntaxPath = path.join(__dirname, 'syntax.coffee')
content = fs.readFileSync(syntaxPath, 'utf8')
lines = content.split('\n')

outputLines = []
inRule = false
currentRuleLines = []
currentRuleName = null

# Process each rule group and align commas
processRuleGroup = (ruleLines) ->
  return ruleLines if ruleLines.length == 0
  
  # Find the widest pattern (everything between o ' and ')
  maxPatternWidth = 0
  patterns = []
  
  for line in ruleLines
    if match = line.match(/^(\s*o\s+')([^']+)('\s*,?\s*)(.*)$/)
      indent = match[1]
      pattern = match[2]
      patternClose = match[3]
      rest = match[4]
      
      # Calculate pattern width including quotes
      patternWidth = (indent + pattern + patternClose).length
      maxPatternWidth = Math.max(maxPatternWidth, patternWidth)
      
      patterns.push
        line: line
        indent: indent
        pattern: pattern
        patternClose: patternClose
        rest: rest
        hasAction: rest.length > 0
    else
      patterns.push
        line: line
        isOther: true
  
  # Rebuild lines with aligned commas
  aligned = []
  for item in patterns
    if item.isOther
      aligned.push item.line
    else if item.hasAction
      # Calculate spaces needed for alignment
      currentWidth = (item.indent + item.pattern + item.patternClose).length
      spacesNeeded = maxPatternWidth - currentWidth
      
      # Add comma with proper spacing
      if item.rest.startsWith(',')
        # Already has comma, just adjust spacing
        alignedLine = item.indent + item.pattern + "'" + ' '.repeat(spacesNeeded) + ', ' + item.rest.slice(1).trim()
      else
        # No comma (probably no action), add one with spacing
        alignedLine = item.indent + item.pattern + "'" + ' '.repeat(spacesNeeded) + ', ' + item.rest
      
      aligned.push alignedLine
    else
      # No action, just close the quote
      aligned.push item.line
  
  aligned

# Process the file
for line, i in lines
  # Check if we're starting a new rule
  if match = line.match(/^\s*(\w+):\s*\[$/)
    # Process previous rule if exists
    if currentRuleLines.length > 0
      outputLines = outputLines.concat processRuleGroup(currentRuleLines)
      outputLines.push '  ]'
      outputLines.push ''
    
    # Start new rule
    currentRuleName = match[1]
    currentRuleLines = []
    inRule = true
    outputLines.push line
    
  else if inRule
    # Check if rule is ending
    if line.match(/^\s*\]/)
      # Process current rule
      if currentRuleLines.length > 0
        outputLines = outputLines.concat processRuleGroup(currentRuleLines)
      outputLines.push line
      inRule = false
      currentRuleLines = []
      currentRuleName = null
      
    else if line.match(/^\s*o\s+'/)
      # Add to current rule lines
      currentRuleLines.push line
      
    else
      # Other lines within rule (comments, etc.)
      currentRuleLines.push line
  else
    # Not in a rule, copy as is
    outputLines.push line

# Process final rule if needed
if currentRuleLines.length > 0
  outputLines = outputLines.concat processRuleGroup(currentRuleLines)
  outputLines.push '  ]'

# Write the result
outputContent = outputLines.join('\n')
fs.writeFileSync(syntaxPath, outputContent)

console.log "=" .repeat 80
console.log "CS3 COMMA ALIGNMENT COMPLETE"
console.log "=" .repeat 80
console.log()
console.log "✓ Processed all grammar rules"
console.log "✓ Aligned commas to widest pattern in each rule"
console.log "✓ Updated syntax.coffee with beautiful formatting"
console.log()
console.log "Example transformation:"
console.log "  Before: o 'SUPER . Property', $ast: '@'"
console.log "  After:  o 'SUPER . Property'                                     , $ast: '@'"
console.log()
console.log "=" .repeat 80
