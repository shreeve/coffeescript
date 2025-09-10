#!/usr/bin/env coffee

# ==============================================================================
# CS3 Complete Directive Signatures - Every Parameter Documented
# ==============================================================================

console.log "=" .repeat 80
console.log "COMPLETE SIGNATURES FOR ALL CS3 DIRECTIVES"
console.log "=" .repeat 80
console.log()

signatures = [
  directive: "$ast"
  signature: "{$ast: string | '@', ...properties: any, $pos?: Pos}"
  required: "$ast"
  optional: "any properties, $pos"
  examples: [
    "$ast: '@'                                    # Minimal - type = rule name"
    "$ast: '@', body: $ref: 1                    # With properties"
    "$ast: 'IdentifierLiteral', name: $ref: 1    # Explicit type"
    "$ast: '@', body: $ref: 1, $pos: [1,1,1,12]  # With position"
  ]
,
  directive: "$ref"
  signature: "{$ref: number, prop?: string, call?: string, args?: any[], $pos?: Pos}"
  required: "$ref"
  optional: "prop, call, args, $pos"
  examples: [
    "$ref: 1                                      # Simple reference to $1"
    "$ref: 2, prop: 'generated'                  # Access property: $2.generated"
    "$ref: 1, call: 'toString'                   # Method call: $1.toString()"
    "$ref: 1, call: 'slice', args: [1, -1]       # With args: $1.slice(1, -1)"
    "$ref: 3, $pos: [5,2,5,4]                    # With position"
  ]
,
  directive: "$obj"
  signature: "{$obj: true, ...properties: any, $pos?: Pos}"
  required: "$obj"
  optional: "any properties, $pos"
  examples: [
    "$obj: yes                                    # Empty object {}"
    "$obj: yes, source: $ref: 2                  # {source: ...}"
    "$obj: yes, source: $ref: 2, object: yes     # {source: ..., object: true}"
    "$obj: yes, guard: $ref: 4, $pos: [3,1,3,21] # With position"
  ]
,
  directive: "$seq"
  signature: "{$seq: Array<Operation>, $pos?: Pos}"
  required: "$seq (array)"
  optional: "$pos"
  examples: [
    "$seq: [$ref: 1]                              # Single item sequence"
    """$seq: [                                    # Multi-step with temporaries
      {$as: 'temp', value: $ref: 1}              #   Store in 'temp'
      {$ops: 'add', target: {$use: 'temp'}}      #   Use 'temp'
      {$use: 'temp'}                              #   Return 'temp'
    ]"""
    "$seq: [{$ops: 'wrap'}, $ref: 1], $pos: [2,1,2,15]  # With position"
  ]
  notes: [
    "$as: 'name' - Store value in temporary variable"
    "$use: 'name' - Reference temporary variable"
  ]
,
  directive: "$ops"
  signature: "{$ops: string, target?: any, args?: any[], prop?: string, value?: any, $pos?: Pos}"
  required: "$ops"
  optional: "target, args, prop, value, $pos"
  examples: [
    "$ops: 'Block.wrap', args: [$ref: 1]         # Static method"
    "$ops: 'push', target: $ref: 1, args: [$ref: 3]  # Instance method"
    "$ops: 'unwrap', target: $ref: 1              # No args"
    "$ops: 'set', target: $ref: 1, prop: 'generated', value: yes  # Property set"
    "$ops: 'concat', target: $ref: 1, args: [$ref: 2], $pos: [4,1,4,12]"
  ]
,
  directive: "$ary"
  signature: "{$ary: any[] | {$concat: any[][]}, $pos?: Pos}"
  required: "$ary"
  optional: "$pos"
  examples: [
    "$ary: []                                     # Empty array"
    "$ary: [$ref: 1]                              # Single element"
    "$ary: [$ref: 1, $ref: 3]                     # Multiple elements"
    "$ary: {$concat: [$ref: 1, $ref: 3]}          # Concatenation"
    "$ary: [$ref: 1, $ref: 2], $pos: [3,1,3,8]   # With position"
  ]
,
  directive: "$ite"
  signature: "{$ite: {test: any, then: any, else?: any}, $pos?: Pos}"
  required: "test, then"
  optional: "else, $pos"
  examples: [
    "$ite: {test: $ref: 1, then: $ref: 2}         # No else (undefined)"
    "$ite: {test: $ref: 1, then: $ref: 2, else: $ref: 3}  # Full ternary"
    "$ite: {test: $ref: 1, then: $ref: 2, else: null}     # Explicit null"
    """$ite: {                                    # Complex then branch
      test: $ref: 3
      then: $ast: 'Assign', left: $ref: 1
      else: null
    }"""
    "$ite: {test: $ref: 1, then: yes, else: no}, $pos: [2,1,2,20]"
  ]
,
  directive: "$pos"
  signature: "$pos: [startLine: number, startCol: number, endLine: number, endCol: number]"
  required: "All 4 numbers"
  optional: "None (but $pos itself is always optional)"
  examples: [
    "$pos: [1, 1, 1, 12]                          # Single line"
    "$pos: [10, 5, 15, 20]                        # Multi-line span"
    "$pos: [2, 3, 2, 3]                           # Single character"
  ]
  notes: [
    "1-indexed (line 1 = first line, column 1 = first character)"
    "Can be added to ANY directive"
    "Always placed at the end of the node"
  ]
]

# Display each signature
for sig in signatures
  console.log "#{sig.directive}"
  console.log "=" .repeat 80
  console.log()
  console.log "Signature: #{sig.signature}"
  console.log "Required:  #{sig.required}"
  console.log "Optional:  #{sig.optional}"
  console.log()

  if sig.examples
    console.log "Examples:"
    for example in sig.examples
      console.log "  #{example}"
    console.log()

  if sig.notes
    console.log "Notes:"
    for note in sig.notes
      console.log "  • #{note}"
    console.log()

console.log "=" .repeat 80
console.log "KEY PATTERNS"
console.log "=" .repeat 80
console.log()
console.log "1. EVERY directive is exactly 3 characters"
console.log "2. $pos can be added to ANY directive"
console.log "3. $ast: '@' means use the production rule name"
console.log "4. $obj: yes creates plain objects (no type field)"
console.log "5. $seq uses $as/$use for temporary variables"
console.log "6. $ref can access properties and call methods"
console.log "7. $ite 'else' is optional (defaults to undefined)"
console.log()
console.log "=" .repeat 80
