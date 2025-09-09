# CoffeeScript AST Migration Plan: Class-based to Data-oriented

## Overview
This document outlines the strategy for migrating CoffeeScript's AST from class-based nodes to data-oriented nodes (similar to Babel/ESTree).

## Current Architecture
- **Grammar** (`src/grammar.coffee`): Uses `new ClassName()` to create AST nodes
- **Nodes** (`src/nodes.coffee`): ~90 classes extending `Base`, each with:
  - Constructor accepting parsed values
  - `compileNode()` method for code generation
  - Helper methods for traversal and analysis
- **Compiler**: Calls methods on node instances

## Target Architecture
- **Grammar**: Returns plain JavaScript objects with `type` field
- **AST Schema**: Standardized node shapes (like ESTree)
- **Compiler**: Visitor pattern for traversal and compilation

## Migration Strategy

### Phase 1: Parallel Infrastructure (Low Risk)
1. **Create AST Builder Module** (`ast-builder.coffee`) ✅
   - Factory functions returning data nodes
   - One function per node type
   - Standardized node structure

2. **Add Compatibility Layer**
   - `NodeWrapper` class that wraps data nodes
   - Provides old class methods (`compileNode`, etc.)
   - Allows gradual migration

3. **Create New Grammar Processor**
   - Modified `o()` function that generates data nodes
   - Keep original grammar.coffee unchanged
   - Create `grammar-data.coffee` using new style

### Phase 2: Incremental Migration
1. **Start with Simple Nodes**
   - Literals (Number, String, Boolean, Null, Undefined)
   - Basic operations (Op, Assign)
   - Simple control flow (If, While)

2. **Test Each Migration**
   - Run full test suite after each node type
   - Ensure compatibility layer works correctly

3. **Complex Nodes**
   - Functions (Code, Param)
   - Classes
   - Comprehensions

### Phase 3: Compiler Refactoring
1. **Visitor Pattern**
   ```coffee
   visitors =
     Root: (node, o) ->
       # compile Root node
     Block: (node, o) ->
       # compile Block node
     # ... etc
   ```

2. **Traversal Utilities**
   - Generic `traverse(node, visitor)` function
   - Scope management
   - Location tracking

### Phase 4: Optimization
1. **Remove Compatibility Layer**
   - Once all nodes migrated
   - Direct visitor compilation

2. **Performance Tuning**
   - Object pooling for common nodes
   - Optimize traversal

## Implementation Steps

### Step 1: Create Dual Grammar (This Week)
```coffee
# grammar-data.coffee
ast = require './ast-builder'

grammar =
  Root: [
    o '', -> ast.Root ast.Block []
    o 'Body', -> ast.Root $1
  ]

  Body: [
    o 'Line', -> ast.BlockWrap [$1]
    o 'Body TERMINATOR Line', -> ast.Block $1.statements.concat [$3]
  ]
  # ... continue for all rules
```

### Step 2: Adapter for Parser Generator
```coffee
# In Cakefile
buildDataParser = ->
  grammar = require './src/grammar-data'
  # Transform grammar actions to use data nodes
  for own name, rules of grammar.bnf
    for rule in rules
      if rule[1]  # if there's an action
        rule[1] = wrapActionForDataNodes rule[1]

  parser = Solar.Generator(grammar).generate()
  fs.writeFileSync 'lib/coffeescript/parser-data.js', parser
```

### Step 3: Test Harness
```coffee
# test-data-ast.coffee
CoffeeScript = require './lib/coffeescript'
DataParser = require './lib/coffeescript/parser-data'
Adapter = require './src/ast-adapter'

testCode = """
  x = 42
  if x > 40
    console.log "big"
"""

# Parse with data parser
tokens = CoffeeScript.tokens testCode
dataAst = DataParser.parse tokens

# Compile using adapter
output = Adapter.compile dataAst

console.log output
```

## Benefits of Migration

1. **Tooling Compatibility**
   - ESLint plugins
   - Prettier formatters
   - IDE support
   - AST explorers

2. **Performance**
   - Smaller memory footprint (no methods)
   - Better serialization
   - Easier optimization

3. **Maintainability**
   - Clear separation of concerns
   - Easier to test
   - Standardized structure

4. **Interoperability**
   - Convert to/from Babel AST
   - Share transformations
   - Use existing AST utilities

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing code | Compatibility layer + extensive testing |
| Performance regression | Benchmark each phase |
| Lost functionality | Careful feature mapping |
| Complex migration | Incremental approach with rollback ability |

## Success Criteria
- [ ] All 1473+ tests pass with data AST
- [ ] Performance within 10% of current
- [ ] Can round-trip: Code → AST → Code
- [ ] ESTree compatibility for common nodes
- [ ] Clean separation of parsing and compilation

## Timeline Estimate
- Phase 1: 1-2 weeks (parallel infrastructure)
- Phase 2: 2-3 weeks (incremental migration)
- Phase 3: 1-2 weeks (compiler refactoring)
- Phase 4: 1 week (optimization)

Total: 5-8 weeks for complete migration

## Next Steps
1. Review and approve plan
2. Create `grammar-data.coffee` with 10 basic rules
3. Test compatibility layer
4. Proceed with full grammar conversion
5. Begin incremental node migration
