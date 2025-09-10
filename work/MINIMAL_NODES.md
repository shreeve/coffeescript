# CS3 Minimal Node Implementation

## Test Program: square.coffee
```coffee
square = (x) ->
  result = x * x
  console.log result
  result

answer = square 5
```

## Required Node Types (13)

### Priority 1: Core Structure (4 types, 8 instances)
1. **Root** (2 instances) - Program root
2. **Block** (2 instances) - Statement blocks
3. **Code** (4 instances) - Function definitions
4. **Param** (4 instances) - Function parameters

### Priority 2: Values & Literals (5 types, 44 instances)
5. **Value** (36 instances) - Value wrapper
6. **IdentifierLiteral** (7 instances) - Variable names
7. **NumberLiteral** (1 instance) - Numbers
8. **PassthroughLiteral** (1 instance) - Comments
9. **PropertyName** (5 instances) - Object properties

### Priority 3: Operations (4 types, 62 instances)
10. **Assign** (13 instances) - Assignments
11. **Op** (32 instances) - Binary/unary operations
12. **Call** (3 instances) - Function calls
13. **Access** (14 instances) - Property access

## Grammar Rules to Transform

Total: ~128 grammar actions to transform across these 13 node types.

## Implementation Steps

1. **Create pattern matcher** for these 13 node types
2. **Transform minimal grammar** - just rules that create these nodes
3. **Test with square.coffee** - ensure it compiles correctly
4. **Expand to full grammar** - add remaining ~271 node instances

## Success Criteria

When complete, this should work:
```bash
coffee -n test-square.coffee  # Should produce identical AST
coffee test-square.coffee     # Should output: 25
```

## Node Transformation Examples

### Before (Class-based)
```coffee
o 'IDENTIFIER', -> new IdentifierLiteral $1
o '', -> new Root new Block
o 'INDENT OUTDENT', -> new Block
```

### After (Data-oriented)
```coffee
o 'IDENTIFIER', -> {$type: 'IdentifierLiteral', name: {$ref: 1}}
o '', -> {$type: 'Root', body: {$type: 'Block', statements: []}}
o 'INDENT OUTDENT', -> {$type: 'Block', statements: []}
```

## Pattern Coverage

Based on our 12 pattern types → 7 node types mapping:
- Pattern 4 (Simple AST): All 13 nodes use this
- Pattern 1 (Passthroughs): Likely used in some rules
- Pattern 7 (Mutations): Possibly for Access/Call

This minimal set should exercise ~3-4 of our 7 node types:
- Type Node (all AST creation)
- Reference Node (parameter references)
- Operation Node (possibly for some helpers)
- Plain Object Node (options)
