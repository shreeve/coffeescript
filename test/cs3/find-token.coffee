fs = require 'fs'
{Lexer} = require '../../lib/coffeescript/lexer'

# Read the full test file
testCode = fs.readFileSync('15-advanced-literals.test.coffee', 'utf8')

console.log "Finding token 228..."

lexer = new Lexer()
tokens = lexer.tokenize testCode

# Show tokens around 228
for i in [225..235]
  if tokens[i]
    t = tokens[i]
    console.log "Token #{i}: #{t[0]}:#{t[1]}" + (if i is 228 then " <-- ERROR HERE" else "")
    
# Show the code around this token
if tokens[228]
  loc = tokens[228][2]
  if loc
    lines = testCode.split('\n')
    console.log "\nCode around line #{loc.first_line + 1}:"
    for i in [Math.max(0, loc.first_line - 2)..Math.min(lines.length - 1, loc.first_line + 2)]
      marker = if i == loc.first_line then " <--" else ""
      console.log "  Line #{i+1}: #{lines[i]}#{marker}"
