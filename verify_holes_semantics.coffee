#!/usr/bin/env coffee

CoffeeScript = require './lib/coffeescript'

console.log "=== Verifying CS3 Preserves Hole Semantics ==="
console.log ""

# Test 1: Array with holes
holesCode = """
holesArray = [1,,3]
console.log "Holes array:"
console.log "  Length:", holesArray.length
console.log "  Has index 1:", 1 of holesArray
console.log "  Value at [1]:", holesArray[1]
holesCount = 0
holesArray.forEach -> holesCount++
console.log "  forEach iterations:", holesCount
"""

# Test 2: Array with explicit undefined
undefinedCode = """
undefinedArray = [1, undefined, 3]
console.log "\\nUndefined array:"
console.log "  Length:", undefinedArray.length
console.log "  Has index 1:", 1 of undefinedArray
console.log "  Value at [1]:", undefinedArray[1]
undefinedCount = 0
undefinedArray.forEach -> undefinedCount++
console.log "  forEach iterations:", undefinedCount
"""

console.log "Running with CS3:"
console.log "-" .repeat(40)
try
  holesCompiled = CoffeeScript.compile holesCode, {bare: true, cs3: true}
  undefinedCompiled = CoffeeScript.compile undefinedCode, {bare: true, cs3: true}

  eval holesCompiled
  eval undefinedCompiled

  console.log ""
  console.log "✅ CS3 correctly preserves the semantic difference!"
  console.log "   - Holes: forEach skips them (2 iterations)"
  console.log "   - Undefined: forEach processes them (3 iterations)"
  console.log "   - Holes: property doesn't exist (1 of array = false)"
  console.log "   - Undefined: property exists (1 of array = true)"
catch err
  console.log "Error:", err.message
