#!/usr/bin/env coffee

CoffeeScript = require './lib/coffeescript'

console.log "=== How CoffeeScript compiles 'of' and 'in' ==="

# Show 'of' compilation
code1 = "'name' of obj"
console.log "\nCoffeeScript: #{code1}"
console.log "Compiles to:"
console.log CoffeeScript.compile(code1, bare: true).trim()

# Show 'in' compilation
code2 = "'apple' in ['apple', 'banana']"
console.log "\nCoffeeScript: #{code2}"
console.log "Compiles to:"
console.log CoffeeScript.compile(code2, bare: true).trim()

console.log "\n=== Key points ==="
console.log "• 'of' uses JavaScript's native 'in' operator"
console.log "• 'in' uses indexOf for arrays (or compileOrTest for literals)"
