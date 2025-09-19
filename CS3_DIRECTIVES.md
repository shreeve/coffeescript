# CS3 Solar Directive System

The CS3 Solar Directive System provides a universal, language-agnostic approach to AST representation using just 4 core directives.

## Core Directives

### 1. `$ast` - Create AST Nodes

Creates Abstract Syntax Tree nodes with a type and properties.

```coffee
# Basic syntax
$ast: 'NodeType', property1: value1, property2: value2

# Examples
$ast: 'If', condition: 1, body: 2              # Create If node
$ast: 'Value', val: 1                          # Create Value node with val property
$ast: 'Class', variable: 2, parent: 4          # Create Class node
$ast: 'Op', operator: '+', left: 1, right: 2   # Create operator node
$ast: '@', name: 1                             # Use rule name as node type
```

### 2. `$ary` - Create Arrays

Creates arrays and can attach properties to them.

```coffee
# Basic syntax
$ary: [elements...]                  # Array with elements
$ary: position                       # Array from position reference
$ary: position, property: value      # Array with attached properties

# Examples
$ary: []                             # Empty array
$ary: [1, 2, 3]                      # Array from positions 1, 2, 3
$ary: 2                              # Use value at position 2 as array
$ary: 2, implicit: true              # Array with implicit property
$ary: [1], length: {$use: 2}         # Array with dynamic property
```

### 3. `$ops` - Apply Operations

Performs categorized operations on existing values.

```coffee
# Basic syntax
$ops: 'category', operation: parameters

# Categories and operations
$ops: 'array', append: [1, 2]        # Array operations
$ops: 'array', gather: [1, 2, 3]     # Flatten and append

$ops: 'value', add: [1, 2]           # Add accessor to value
$ops: 'if', addElse: [1, 2]          # Add else branch to if

$ops: 'loop', addBody: [1, 2]        # Add body to loop
$ops: 'loop', addSource: [1, 2]      # Add source to loop  
$ops: 'loop', addBody: [1, 2], postfix: true  # Postfix loop

$ops: 'prop', set: {target: 1, property: 'name', value: 2}  # Set property
```

### 4. `$use` - Reference Values

References values from the parse stack or accesses their properties and methods.

```coffee
# Basic syntax
$use: position                        # Reference by position (1-based)
$use: position, prop: 'property'     # Access property
$use: position, method: 'name'        # Call method
$use: position, method: 'name', args: [...]  # Call with arguments
$use: position, index: n              # Array index access

# Examples
$use: 1                               # Value at position 1
$use: 2, prop: 'value'                # $2.value
$use: 1, method: 'toString'           # $1.toString()
$use: 1, method: 'slice', args: [0, -1]  # $1.slice(0, -1)
$use: 3, index: 0                     # $3[0]
```

## Metadata Directive

### `$pos` - Position Tracking

Tracks source code location for error reporting and source maps.

```coffee
$pos: 1                               # Copy position from element 1
$pos: [1, 3]                          # Span from element 1 to 3
$pos: [line, col, endLine, endCol]   # Explicit position
```

## Plain Objects

Properties without directives create plain objects:

```coffee
# No directive needed for plain objects
name: 1, value: 2                    # {name: $1, value: $2}
soak: true, optional: false          # {soak: true, optional: false}
```

## Common Patterns

### Creating Nodes with Properties

```coffee
# If statement with condition and body
$ast: 'If', condition: {$use: 1}, body: {$use: 2}

# Class with inheritance
$ast: 'Class', variable: {$use: 2}, parent: {$use: 4}

# Function with parameters and body
$ast: 'Code', params: {$ary: 1}, body: {$use: 2}
```

### Building Complex Structures

```coffee
# Nested value with property access
$ast: 'Value', val: {$ast: 'IdentifierLiteral', value: 'foo'}, 
               properties: [{$ast: 'Access', name: 'bar'}]

# Array with mixed elements
$ary: [{$use: 1}, {$ast: 'Literal', value: 0}, {$use: 3}]

# Operations building loops
$ops: 'loop', addBody: [{$ast: 'For', source: 1}, 2]
```

### Control Flow

```coffee
# If-else statement
$ast: 'If', condition: 1, body: 2, elseBody: 3

# While loop
$ast: 'While', condition: 1, body: 2

# For loop
$ast: 'For', body: 1, source: 2, name: 3

# Postfix while
$ops: 'loop', addBody: [2, 1], postfix: true
```

### Operations by Category

#### Array Operations
- `append` - Add elements to array
- `gather` - Append with flattening

#### Value Operations
- `add` - Add accessor/property to value

#### If Operations
- `addElse` - Add else branch

#### Loop Operations
- `addBody` - Set loop body
- `addSource` - Set loop source
- `postfix` - Mark as postfix form

#### Property Operations
- `set` - Set object property

## Design Principles

1. **Universality**: Works for any programming language
2. **Simplicity**: Just 4 directives handle all cases
3. **Composability**: Directives combine naturally
4. **Readability**: Intent is always clear
5. **Consistency**: Uniform patterns throughout

## Grammar Rule Examples

```coffee
# Simple passthrough
Identifier: [
  o 'IDENTIFIER', $use: 1
]

# Creating AST nodes
SimpleAssignable: [
  o 'Identifier', $ast: 'Value', val: 1
]

# Using operations
While: [
  o 'WhileSource Block', $ops: 'loop', addBody: [1, 'Body $2']
  o 'Statement WhileSource', $ops: 'loop', addBody: [2, [1]], postfix: true
]

# Arrays with properties
Arguments: [
  o 'CALL_START CALL_END', $ary: [{}]
  o 'CALL_START ArgList CALL_END', $ary: 2, implicit: true
]

# Complex transformations
Class: [
  o 'CLASS SimpleAssignable', $ast: 'Class', variable: 2
  o 'CLASS SimpleAssignable EXTENDS Value', $ast: 'Class', variable: 2, parent: 4
  o 'CLASS EXTENDS Value Block', $ast: 'Class', parent: 3, body: 4
]
```

## Implementation Notes

- Position references are 1-based (1 = first element)
- Arrays are deeply flattened when used as arguments
- Properties on arrays are preserved through operations
- The `@` symbol in `$ast: '@'` uses the grammar rule name as the node type
- All directives evaluate recursively

## Backend Requirements

A Solar backend must implement:

1. **Directive evaluation**: Process `$ast`, `$ary`, `$ops`, `$use`
2. **Position references**: Handle 1-based stack positions
3. **Property/method access**: Support `$use` with prop/method/index
4. **Operations**: Implement categorized operations
5. **Metadata**: Track `$pos` for source mapping

## Summary

The CS3 Solar Directive System achieves complete AST transformation with minimal complexity:

- **4 directives** handle all transformations
- **Categorized operations** provide type safety
- **Clean syntax** makes intent obvious
- **Universal design** works for any target language
- **No special cases** - everything follows the same patterns
- **Ultra-compact output** - Single-line rules with efficient `r` function aliasing
- **Optimized frame construction** - Flattened arrays without redundant wrappers

This architecture enables CoffeeScript 3 to maintain 100% compatibility while providing a clean, maintainable, and extensible foundation for future development. The optimized parser output demonstrates that data-oriented design can be both elegant and efficient.
