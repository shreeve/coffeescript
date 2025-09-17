# CS3 Test Suite

This directory contains tests specific to the CoffeeScript 3 (CS3) implementation.

## Directory Structure

### `/simple/`
Minimal test cases for basic CS3 features. Each file tests a single concept:
- `arrays.coffee` - Array literal compilation
- `basic.coffee` - Basic variable assignment
- `booleans.coffee` - Boolean literals
- `conditions.coffee` - If/then conditionals
- `math.coffee` - Mathematical operations
- `objects.coffee` - Object literals
- `ranges.coffee` - Range expressions
- `strings.coffee` - String literals

### Test Files
- `test-es5-nodes.coffee` - Tests for ES5 backend node implementations
- `test-loops.coffee` - Tests for loop constructs (For/While)
- `test-working-features.coffee` - Comprehensive test of all working CS3 features

### Development Tools
- `implement-node.sh` - Script to help implement new AST nodes
- `node-implementation-template.coffee` - Template for new node implementations
- `test-node-coverage.sh` - Script to check AST node coverage

## Running Tests

```bash
# Run a simple test
./bin/coffee --cs3 test/cs3/simple/arrays.coffee

# Compile and check output
./bin/coffee --cs3 -c -p test/cs3/test-working-features.coffee

# Check AST generation
./bin/coffee --cs3-ast test/cs3/simple/objects.coffee

# Check node coverage
./test/cs3/test-node-coverage.sh
```

## Test Status

✅ **Working**: Basic literals, arrays, objects, operators, conditionals, functions, parentheses
🚧 **In Progress**: Loops, prototype operator (::)
📋 **TODO**: Advanced features, edge cases
