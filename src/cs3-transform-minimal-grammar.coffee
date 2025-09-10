#!/usr/bin/env coffee

# ==============================================================================
# Transform Minimal Grammar to Data-Oriented Format
#
# Uses CS3PatternMatcher to transform extracted rules to data nodes
# ==============================================================================

fs = require 'fs'
path = require 'path'
CS3PatternMatcher = require './cs3-pattern-matcher-v2'

# Load extracted rules
rulesPath = path.join(__dirname, '..', 'work', 'minimal-grammar-rules.json')
rulesData = JSON.parse(fs.readFileSync(rulesPath, 'utf8'))

# Load original grammar file
grammarPath = path.join(__dirname, 'grammar.coffee')
grammarContent = fs.readFileSync(grammarPath, 'utf8')
grammarLines = grammarContent.split('\n')

# Create pattern matcher
matcher = new CS3PatternMatcher()

# Transform actions
transformedRules = []
transformationErrors = []

for rule in rulesData.rules
  try
    # Get the original action
    action = rule.action.trim()

    # Transform it
    transformed = matcher.transformAction(action)

    # Convert to JSON string for embedding in grammar
    transformedStr = JSON.stringify(transformed)

    transformedRules.push
      line: rule.line
      pattern: rule.pattern
      original: action
      transformed: transformedStr

  catch error
    transformationErrors.push
      rule: rule
      error: error.message

console.log "=" .repeat 80
console.log "TRANSFORMATION RESULTS"
console.log "=" .repeat 80
console.log()
console.log "Successfully transformed: #{transformedRules.length} rules"
console.log "Errors: #{transformationErrors.length}"
console.log()

if transformationErrors.length > 0
  console.log "ERRORS:"
  console.log "-" .repeat 40
  for err in transformationErrors[0..5]
    console.log "  Line #{err.rule.line}: #{err.error}"
    console.log "    Pattern: '#{err.rule.pattern}'"
    console.log "    Action: #{err.rule.action.slice(0, 60)}..."
  if transformationErrors.length > 5
    console.log "  ... and #{transformationErrors.length - 5} more errors"
  console.log()

# Show some examples
console.log "TRANSFORMATION EXAMPLES:"
console.log "-" .repeat 40

examples = transformedRules[0..10]
for rule in examples
  console.log "Line #{rule.line}: '#{rule.pattern}'"
  console.log "  Original:    #{rule.original.slice(0, 60)}..."
  console.log "  Transformed: #{rule.transformed.slice(0, 60)}..."
  console.log()

# Create a minimal grammar file with transformed rules
console.log "=" .repeat 80
console.log "CREATING MINIMAL GRAMMAR FILE"
console.log "=" .repeat 80

# Start with basic structure
output = """
###
CS3 Minimal Grammar - Data-Oriented Actions
Generated from CoffeeScript grammar for testing with square.coffee
###

# Helper function to create data nodes
n = (type, props = {}) -> {$type: type, ...props}

# The minimal grammar with data-oriented actions
grammar =

"""

# Group rules by their nonterminal
rulesByNonterminal = {}
inGrammar = false
currentNonterminal = null

for line, i in grammarLines
  if line.match(/^grammar\s*=/)
    inGrammar = true
    continue

  continue unless inGrammar

  # Check for nonterminal definition
  if match = line.match(/^(\s*)(\w+):\s*\[/)
    currentNonterminal = match[2]
    rulesByNonterminal[currentNonterminal] = []
    continue

  # Check if this line has one of our transformed rules
  transformedRule = transformedRules.find (r) -> r.line is i + 1
  if transformedRule
    rulesByNonterminal[currentNonterminal]?.push transformedRule

# Output only nonterminals that have transformed rules
for nonterminal, rules of rulesByNonterminal when rules.length > 0
  output += "  #{nonterminal}: [\n"

  for rule in rules
    # Format: o 'pattern', -> dataNode
    output += "    o '#{rule.pattern}', -> #{rule.transformed}\n"

  output += "  ]\n\n"

# Add exports
output += """
# Export for use
exports.grammar = grammar
"""

# Save the minimal grammar
outputPath = path.join(__dirname, 'cs3-grammar-minimal.coffee')
fs.writeFileSync(outputPath, output)

console.log()
console.log "Created minimal CS3 grammar at:"
console.log "  #{outputPath}"
console.log()
console.log "This grammar contains #{transformedRules.length} transformed rules"
console.log "covering our 13 minimal node types for square.coffee"
console.log()
console.log "=" .repeat 80
