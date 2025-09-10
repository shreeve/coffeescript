# The CS3 Directive System

The CS3 directive system provides a clean, categorized approach to AST transformation with clear separation between **creation** and **operation**.

## 1️⃣ AST Creation (`$ast`)

Creates Abstract Syntax Tree nodes with a `type` field.

**Signature:** `{$ast: string | '@', ...properties: any, $pos?: Pos}`

```coffee
# Explicit type
$ast: 'If', condition: 2, body: 3       # Creates If node
$ast: 'Value', val: 1                   # Value with semantic property
$ast: 'Op', args: [1, 2]                # Op with positional args

# Implicit type (@ = use rule name)
$ast: '@', condition: 2, body: 3        # Uses rule name as type
```

## 2️⃣ Data Structure Creation

Creates plain data structures without a `type` field.

### Array Creation (`$ary`)
**Signature:** `{$ary: any[], $pos?: Pos}`

```coffee
$ary: []              # Empty array
$ary: [1]             # Single element from position 1
$ary: [1, 3, 5]       # Multiple elements from positions
$ary: [{$ast: 'Literal', value: 'foo'}]  # Can contain complex nodes
```

### Object Creation (`$obj`)
**Signature:** `{$obj: true, ...properties: any, $pos?: Pos}`

```coffee
$obj: {}                          # Empty object
$obj: {name: 1, value: 3}         # Properties from positions
$obj: {foo: 'bar', baz: 2}        # Mixed literal and positional
```

## 3️⃣ Operations (`$ops`)

Performs operations on existing objects, **categorized by type** for clarity.

### Array Operations
```coffee
$ops: 'array', append: [1, 3]    # $1.push($3) - add to end
$ops: 'array', gather: [1, 2, 4] # Append + flatten arrays
```

### Value Node Operations
```coffee
$ops: 'value', add: [1, 2]       # $1.add($2) - add accessor
```

### If Node Operations
```coffee
$ops: 'if', addElse: [1, 3]      # $1.addElse($3) - add else branch
```

### Loop Operations
```coffee
$ops: 'loop', addBody: [1, 2]    # $1.addBody($2)
$ops: 'loop', addSource: [1, 2]  # $1.addSource($2)
```

### Property Operations
```coffee
$ops: 'prop', set: {target: 2, property: 'implicit', value: true}
```

## 4️⃣ Control Flow

Handles complex logic and multi-step operations.

### Sequence (`$seq`)
**Signature:** `{$seq: any[], $var?: any, $use?: string, $pos?: Pos}`

```coffee
$seq: [
  {$var: 'temp', value: 1}              # Create temp variable
  {$ops: 'array', append: ['temp', 2]}  # Use temp
  {$use: 'temp'}                         # Return temp
]
```

### If-Then-Else (`$ite`)
**Signature:** `{$ite: {test: any, then: any, else: any}, $pos?: Pos}`

```coffee
$ite: {test: 1, then: 2, else: 3}    # Ternary conditional
```

## 5️⃣ References (`$rhs`)

Access to Right-Hand Side (parser stack) elements.

**Signature:** `number | {$rhs: number, prop?: string, method?: string, args?: any[]}`

```coffee
# Direct position (simplified syntax)
1                             # Element at position 1
3                             # Element at position 3

# Property access
{$rhs: 1, prop: 'value'}      # $1.value
{$rhs: 2, prop: 'original'}   # $2.original

# Method call
{$rhs: 1, method: 'toString'} # $1.toString()
{$rhs: 1, method: 'slice', args: [1, -1]}  # $1.slice(1, -1)
```

## 6️⃣ Metadata (`$pos`)

Position tracking for source location.

```coffee
$pos: 1                       # Copy position from element 1
$pos: [1, 3]                  # Range from element 1 to 3
$pos: [startLine, startCol, endLine, endCol]  # Explicit
```

## The Philosophy

### CREATE vs OPERATE
- **Create** = Make new things: `$ast`, `$ary`, `$obj`
- **Operate** = Modify existing: `$ops`

### Categorized Operations
Operations are grouped by what they operate on, making intent crystal clear:
- `$ops: 'array', append:` vs `$ops: 'value', add:`
- No ambiguity about what's being modified

### Positional Simplicity
- Numbers always refer to RHS positions
- `[1, 3]` = elements from positions 1 and 3
- Direct numbers can replace `{$rhs: n}` for brevity

### Semantic Clarity
- `append` vs `gather` (not just "concat")
- `val` not `base` for Value nodes
- `args` for positional parameters in Op nodes
- `addElse` not just `add` for If nodes

## Summary

This directive system achieves several goals:

1. **Clear Separation**: Creation directives (`$ast`, `$ary`, `$obj`) vs operations (`$ops`)
2. **Type Safety**: Categorized operations prevent misuse
3. **Readability**: Semantic names and consistent patterns
4. **Extensibility**: Easy to add new operations or categories
5. **Simplicity**: Direct numbers for simple references, objects for complex ones

The result is a grammar syntax that is both **powerful** and **self-documenting**, making the CoffeeScript 3 transformation clean and maintainable.
