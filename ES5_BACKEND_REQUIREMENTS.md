# ES5 Backend Requirements Specification

## Purpose
Convert CS3 data-oriented AST nodes to CoffeeScript's class-based AST nodes, enabling the existing CoffeeScript compiler to generate JavaScript.

## Core Requirements

### 1. Main API
- **Class**: `ES5Backend`
- **Constructor**: Accept options (bare, header, sourceMap, inlineMap)
- **Main Method**: `generate(dataNode)` - converts CS3 node → CoffeeScript node → JavaScript
- **Core Method**: `dataToClass(node)` - recursive converter

### 2. Node Conversion Rules

#### Primitives & Basic Types
- `null` → return null
- Strings, numbers, booleans → return as-is
- Arrays → map recursively with `dataToClass`

#### Literals (Must Handle)
- `NumberLiteral` → `nodes.NumberLiteral(value, parsedValue)`
- `StringLiteral` → `nodes.StringLiteral(value, {quote})`
  - **CRITICAL**: Must set `locationData` and `originalValue` to prevent crashes
- `Literal` → `nodes.Literal(value)`
- `BooleanLiteral` → `nodes.BooleanLiteral(value)`
- `NullLiteral` → `nodes.NullLiteral()`
- `UndefinedLiteral` → `nodes.UndefinedLiteral()`
- `InfinityLiteral` → `nodes.InfinityLiteral(value)`
- `NaNLiteral` → `nodes.NaNLiteral()`
- `IdentifierLiteral` → `nodes.IdentifierLiteral(value)`
- `PropertyName` → `nodes.PropertyName(value)`
- `StatementLiteral` → `nodes.StatementLiteral(value)`
- `ThisLiteral` → `nodes.ThisLiteral(value || 'this')`
- `RegexLiteral` → `nodes.RegexLiteral(value, options)`
- `PassthroughLiteral` → `nodes.PassthroughLiteral(value, options)`

#### Structural Nodes
- `Root` → `nodes.Root(Block)` - filter nulls from body
- `Block` → `nodes.Block(expressions)` - filter nulls
- `Parens` → `nodes.Parens(body)`

#### Values & Properties
- `Value` → `nodes.Value(base, properties)`
- `Access` → `nodes.Access(name)` with soak/shorthand
- `Index` → `nodes.Index(object)` with soak
- `Super` → `nodes.Super(accessor)`

#### Assignment
- `Assign` → `nodes.Assign(variable, value, context, options)`
  - Handle object context specially
  - Pass through operatorToken, param, subpattern, moduleDeclaration

#### Operations
- `Op` → `nodes.Op(op, first, second, flip, options)`
  - **CRITICAL**: Must pass `invertOperator` and `originalOperator` in options
- `Existence` → `nodes.Existence(expression)`

#### Functions
- `Code` → `nodes.Code(params, Block(body), tag)`
  - Filter null params
  - Determine tag from funcGlyph (=> is 'boundfunc')
- `Param` → `nodes.Param(name, value, splat)`
- `Call` → `nodes.Call(variable, args, soak)`
  - **CRITICAL**: Filter null args, wrap primitives in Literal
- `SuperCall` → `nodes.SuperCall(args)`
  - **BUG TO FIX**: Currently throws empty error

#### Collections
- `Arr` → `nodes.Arr(objects)` - handle nested arrays, filter empties
- `Obj` → `nodes.Obj(properties, generated)` - filter nulls
- `Range` → `nodes.Range(from, to, tag)`
- `Slice` → Unwrap to inner Range
- `Splat` → `nodes.Splat(name)`
- `Expansion` → `nodes.Expansion()`
- **Elision** → **BUG TO FIX**: Must create `nodes.Elision()` or equivalent

#### Control Flow
- `If`/`unless` → `nodes.If(condition, body, options)`
  - Handle elseBody, set isChain if else is If
- `While` → `nodes.While(condition, guard).addBody(body)`
- `For` → `nodes.For(body, sourceObj)`
  - **BUG TO FIX**: Must ensure loop counter variables don't conflict with destructured variables
  - Must set locationData on body and expressions
  - Build sourceObj with all for-loop properties
- `Switch` → `nodes.Switch(subject, cases, Block(otherwise))`
- `SwitchWhen` → `nodes.SwitchWhen(conditions, Block(body))`
- `Try` → `nodes.Try(Block(attempt), catch, Block(ensure))`
- `Catch` → `nodes.Catch(Block(recovery), variable)`
- `Throw` → `nodes.Throw(expression)`
- `Return` → `nodes.Return(expression)`
- `YieldReturn` → `nodes.YieldReturn(expression)`
- `AwaitReturn` → `nodes.AwaitReturn(expression)`

#### Classes
- `Class` → `nodes.Class(variable, parent, body)`
  - Extract methods from Obj nodes in body

#### String Interpolation
- `StringWithInterpolations` → `nodes.StringWithInterpolations(Block(body), {quote})`
- `Interpolation` → `nodes.Interpolation(expression)`

#### Import/Export
- `ImportDeclaration` → `nodes.ImportDeclaration(clause, source, assertions)`
- `ImportClause` → `nodes.ImportClause(defaultBinding, namedImports)`
- `ExportDeclaration` → `nodes.ExportDeclaration(clause)`

### 3. Critical Bug Fixes Needed

#### Bug #1: Loop Variable Conflicts
**Problem**: Nested loops reuse variable names
```coffeescript
for x in arr1     # Uses 'i' as counter
  for i,j in arr2 # Destructures to 'i', conflicts!
```
**Solution**: Track used variable names and ensure unique counters

#### Bug #2: Super Calls
**Problem**: SuperCall nodes throw empty errors
**Solution**: Debug and fix the SuperCall conversion

#### Bug #3: Array Elisions
**Problem**: `[1,,3]` becomes `[1]` instead of `[1, undefined, 3]`
**Solution**: Add handler for Elision nodes

### 4. Best Practices
- Always filter null values from arrays before passing to nodes
- Ensure locationData exists on nodes that need it (especially StringLiteral)
- Wrap non-node values in appropriate node types
- Handle both array and single-value cases for body/expressions
- Use Block wrapper for code bodies
- Preserve all metadata (soak, shorthand, invert, etc.)

### 5. Import Requirements
```coffeescript
nodes = require '../../lib/coffeescript/nodes'
```

### 6. Export Requirements
```coffeescript
module.exports = ES5Backend
```
