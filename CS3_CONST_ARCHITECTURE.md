# CS3 Data-Oriented Architecture for const Detection

## The Insight

CS3's data-oriented AST (Solar directives) are **pure data structures**, not executable code. This fundamentally enables multi-pass compilation in a way that CS2's class-based AST cannot.

## Current Architecture (Incremental)

```
Parser → backend.reduce() → CoffeeScript Nodes → JavaScript
         (during parsing)     (immediate)        (immediate)
```

The parser calls `backend.reduce()` for each grammar production, building the AST incrementally.

## Proposed Architecture (Multi-Pass)

```
Parser → Directive Tree → Analysis Pass → Generation Pass → JavaScript
         (pure data)      (read-only)     (informed)
```

## Implementation Options

### Option 1: Minimal Change - Store Directives
```coffee
# In ES5Backend
reduce: (stack, markers, top, count, directive) ->
  # Store directive for later analysis
  @directives ?= []
  @directives.push directive
  
  # Continue normal processing
  frame = @createReductionFrame(stack, markers, top, count)
  @evaluateDirective(directive, frame)
```

### Option 2: Parser Returns Pure Data
```coffee
# Modified parser that doesn't call backend
parserCS3.parse() # Returns directive tree

# Backend does multi-pass
backend.analyze(directiveTree)  # Pass 1: Variable analysis
backend.generate(directiveTree) # Pass 2: Code generation
```

### Option 3: Hybrid Approach
```coffee
# Keep current architecture but add analysis phase
class ES5Backend
  constructor: (@options = {}) ->
    @analysisMode = false
    @variableInfo = {}
  
  reduce: (stack, markers, top, count, directive) ->
    if @analysisMode
      @analyzeDirective(directive)  # Just analyze, don't generate
      return null
    else
      # Normal generation with variableInfo available
      frame = @createReductionFrame(stack, markers, top, count)
      @evaluateDirective(directive, frame)
```

## Why CS3 Makes This Possible

1. **Pure Data**: Directives are just objects with properties
2. **No Side Effects**: Unlike CS2 nodes with methods, directives don't execute
3. **Serializable**: Can traverse, store, and replay directives
4. **Analyzable**: Can extract patterns without generating code

## Example: const Detection

With pure directive tree:
```coffee
analyzeVariables: (directive) ->
  switch directive.$ast
    when "Assign"
      if directive.context  # +=, -=, etc
        @markAsReassigned(directive.variable)
      else
        @markAsDeclaration(directive.variable)
    
    when "For"
      @markAsReassigned(directive.name)  # Loop vars change
    
    when "Block"
      for expr in directive.body
        @analyzeVariables(expr)
```

Then during generation:
```coffee
createAssign: (directive, frame) ->
  varName = directive.variable?.value
  canBeConst = @variableInfo[varName]?.neverReassigned
  # Generate const or let accordingly
```

## Benefits for Rip

When you design Rip, you can build this in from the start:
- Parser always returns pure data
- Backend is explicitly multi-pass
- Each pass can annotate the tree
- Final pass generates optimal code

## Next Steps

1. **Proof of Concept**: Implement Option 1 (minimal change) to validate
2. **Performance Test**: Ensure multi-pass doesn't slow compilation
3. **Full Implementation**: Restructure for Option 2 if beneficial
4. **Apply to Rip**: Use learnings for Rip's architecture
