#!/usr/bin/env coffee

# ==============================================================================
# CS3: What Creates AST Nodes? Understanding Node Creation
# ==============================================================================

console.log "=" .repeat 80
console.log "WHAT CREATES AST NODES?"
console.log "=" .repeat 80
console.log()

console.log "KEY DISTINCTION: AST Node vs Plain Object"
console.log "-" .repeat 40
console.log()
console.log "AST Node = Object with a 'type' field (represents language construct)"
console.log "Plain Object = Object without 'type' field (just data)"
console.log()

console.log "=" .repeat 80
console.log "DIRECTIVE BREAKDOWN:"
console.log "=" .repeat 80
console.log()

directives = [
  directive: "$ast"
  creates: "AST NODE"
  example: "$ast: 'If', test: $ref: 1"
  output: "{type: 'If', test: ...}  # HAS type field!"
  explanation: "ONLY directive that creates AST nodes"
,
  directive: "$obj"
  creates: "PLAIN OBJECT"
  example: "$obj: yes, source: $ref: 2"
  output: "{source: ...}  # NO type field!"
  explanation: "Creates plain data objects, NOT AST nodes"
,
  directive: "$ref"
  creates: "NOTHING"
  example: "$ref: 1"
  output: "(whatever $1 is)"
  explanation: "References existing value, doesn't create"
,
  directive: "$ary"
  creates: "ARRAY"
  example: "$ary: [$ref: 1, $ref: 2]"
  output: "[value1, value2]"
  explanation: "Creates arrays, not AST nodes"
,
  directive: "$seq"
  creates: "NOTHING (returns last value)"
  example: "$seq: [{$var: 'x', value: $ref: 1}, {$use: 'x'}]"
  output: "(value of last item in sequence)"
  explanation: "Executes sequence, returns final value"
,
  directive: "$ops"
  creates: "NOTHING (performs operation)"
  example: "$ops: 'push', target: $ref: 1, args: [$ref: 2]"
  output: "(result of operation)"
  explanation: "Calls methods, doesn't directly create nodes"
,
  directive: "$ite"
  creates: "NOTHING (returns branch value)"
  example: "$ite: {test: $ref: 1, then: yes, else: no}"
  output: "(either yes or no)"
  explanation: "Returns one of two values, doesn't create"
]

for dir in directives
  console.log "#{dir.directive}: #{dir.creates}"
  console.log "  Example: #{dir.example}"
  console.log "  Output:  #{dir.output}"
  console.log "  → #{dir.explanation}"
  console.log()

console.log "=" .repeat 80
console.log "BUT WAIT! NESTING CHANGES THINGS:"
console.log "=" .repeat 80
console.log()

console.log "Other directives can CONTAIN $ast directives:"
console.log "-" .repeat 40
console.log()

nesting_examples = [
  title: "$seq containing $ast"
  code: """
    $seq: [
      {$var: 'node', value: {$ast: 'Value', base: $ref: 1}}  # ← Creates AST node!
      {$ops: 'add', target: {$use: 'node'}, args: [$ref: 2]}
      {$use: 'node'}
    ]
  """
  explanation: "The $seq doesn't create the node, the nested $ast does"
,
  title: "$ite containing $ast"
  code: """
    $ite: {
      test: $ref: 1
      then: {$ast: 'Assign', left: $ref: 2, right: $ref: 3}  # ← Creates AST node!
      else: null
    }
  """
  explanation: "The $ite doesn't create the node, the nested $ast does"
,
  title: "$var storing $ast"
  code: """
    $var: 'temp', value: {$ast: 'Block', statements: []}  # ← Creates AST node!
  """
  explanation: "The $var doesn't create the node, it stores the result of $ast"
,
  title: "$ary containing $ast"
  code: """
    $ary: [
      {$ast: 'NumberLiteral', value: 1}  # ← Creates AST node!
      {$ast: 'NumberLiteral', value: 2}  # ← Creates AST node!
    ]
  """
  explanation: "The $ary creates an array, the nested $ast creates nodes"
]

for example in nesting_examples
  console.log "#{example.title}:"
  console.log example.code
  console.log "  → #{example.explanation}"
  console.log()

console.log "=" .repeat 80
console.log "THE RULE:"
console.log "=" .repeat 80
console.log()
console.log "🎯 ONLY $ast CREATES AST NODES (objects with 'type' field)"
console.log()
console.log "But $ast can appear:"
console.log "  • At the top level of an action"
console.log "  • Nested inside $seq"
console.log "  • As a branch of $ite"
console.log "  • As a value in $var"
console.log "  • As an element in $ary"
console.log "  • As an argument in $ops"
console.log()
console.log "Other directives create different things:"
console.log "  • $obj creates plain objects (no type)"
console.log "  • $ary creates arrays"
console.log "  • Others reference or transform existing values"
console.log()

console.log "=" .repeat 80
console.log "EXAMPLES OF EACH TYPE OF CREATION:"
console.log "=" .repeat 80
console.log()

creation_examples = [
  what: "AST NODE"
  how: "$ast"
  example: "$ast: 'If', test: $ref: 1"
  result: "{type: 'If', test: ...}"
,
  what: "PLAIN OBJECT"
  how: "$obj"
  example: "$obj: yes, source: $ref: 2"
  result: "{source: ...}  # No type!"
,
  what: "ARRAY"
  how: "$ary"
  example: "$ary: [$ref: 1, $ref: 2]"
  result: "[value1, value2]"
,
  what: "NOTHING (reference)"
  how: "$ref"
  example: "$ref: 1"
  result: "(existing value)"
]

for ex in creation_examples
  console.log "To create #{ex.what}:"
  console.log "  Use: #{ex.how}"
  console.log "  Example: #{ex.example}"
  console.log "  Result: #{ex.result}"
  console.log()

console.log "=" .repeat 80
console.log "SUMMARY:"
console.log "=" .repeat 80
console.log()
console.log "• $ast is the ONLY directive that creates AST nodes"
console.log "• $obj creates plain objects (different from AST nodes!)"
console.log "• $ary creates arrays"
console.log "• All others manipulate/reference existing values"
console.log "• $ast can be nested inside other directives"
console.log()
console.log "AST Node = has 'type' field = created by $ast"
console.log "Plain Object = no 'type' field = created by $obj"
console.log()
console.log "=" .repeat 80
