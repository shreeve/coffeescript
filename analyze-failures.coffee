#!/usr/bin/env coffee

{execSync} = require 'child_process'

# Run the test suite and capture output (ignore exit code)
output = ''
try
  output = execSync('coffee test/cs3/cs3-runner.coffee 2>&1', {encoding: 'utf8'})
catch e
  output = e.stdout or e.output?[1] or ''

lines = output.split('\n')

# Categorize failures
categories = {}
failureCount = 0

# Parse the output
for line in lines
  if line.includes('✗')
    failureCount++
    # Extract test name - look for the pattern after '✗][0m '
    parts = line.split('✗')[1]
    if parts
      # Remove ANSI codes and get test name
      cleanParts = parts.replace(/\[0m /g, '').trim()
      colonIndex = cleanParts.indexOf(':')
      if colonIndex > 0
        testName = cleanParts.substring(0, colonIndex)

        # Categorize
        category = switch
          when testName.includes('unless') then 'Unless/Postfix Unless'
          when testName.includes('exclusive') then 'Exclusive Ranges'
          when testName.includes('class') or testName.includes('super') then 'Classes & Inheritance'
          when testName.includes('throw') or testName.includes('catch') or testName.includes('rethrow') then 'Exception Handling'
          when testName.includes('tagged template') then 'Tagged Templates'
          when testName.includes('return') then 'Return Values'
          when testName.includes('of operator') then 'Of Operator'
          when testName.includes('conditional') then 'Conditionals'
          when testName.includes('slicing') or testName.includes('splicing') then 'Slicing/Splicing'
          when testName.includes('string literal') then 'String Literals'
          when testName.includes('for-from') then 'For-From Loops'
          when testName.includes('multi-line') then 'Multi-line Strings'
          when testName.includes('dynamic property') then 'Dynamic Properties'
          when testName.includes('proto') then 'Prototype Access'
          else 'Other'

        categories[category] ?= []
        categories[category].push testName

# Sort by count
sorted = Object.entries(categories).sort((a, b) -> b[1].length - a[1].length)

console.log "\n=== CS3 Failure Analysis ==="
console.log "Total failures: #{failureCount}\n"

for [category, tests] in sorted
  console.log "#{category}: #{tests.length} failures"
  for test in tests[0...3]  # Show first 3 tests
    console.log "  - #{test}"
  console.log "  ..." if tests.length > 3
  console.log()

# Show highest impact fixes
console.log "=== Recommended Priority Fixes ===\n"
console.log "1. Exception Handling (5 failures) - Core control flow feature"
console.log "2. Classes & Inheritance (4-5 failures) - Super calls and bound methods"
console.log "3. Unless/Postfix Unless (4 failures) - Common CoffeeScript pattern"
console.log "4. Exclusive Ranges (3-4 failures) - Used throughout CoffeeScript"
console.log "5. Tagged Templates (2 remaining) - Almost fixed, needs interpolation work"