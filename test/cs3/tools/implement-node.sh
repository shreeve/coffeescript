#!/bin/bash

# Quick script to implement a new node type
# Usage: ./implement-node.sh StringLiteral

NODE_TYPE=$1

if [ -z "$NODE_TYPE" ]; then
    echo "Usage: ./implement-node.sh <NodeType>"
    echo "Example: ./implement-node.sh StringLiteral"
    exit 1
fi

echo "=== Implementing $NODE_TYPE ==="

# Step 1: Find examples in test files
echo "Step 1: Finding examples..."
grep -r "$NODE_TYPE" test/*.coffee 2>/dev/null | head -5

# Step 2: Check AST structure
echo -e "\nStep 2: Checking AST structure..."
echo "Run: echo '<example>' | ./bin/coffee --cs3-ast -s | grep -A10 '$NODE_TYPE'"

# Step 3: Check traditional implementation
echo -e "\nStep 3: Checking traditional nodes.coffee implementation..."
grep -A10 "class $NODE_TYPE" lib/coffeescript/nodes.js 2>/dev/null | head -15

# Step 4: Generate template
echo -e "\nStep 4: Template for backends/es5/index.coffee:"
cat << EOF

when '$NODE_TYPE'
  # TODO: Check directive structure with --cs3-ast
  value = @evaluateDirective directive.value, frame, ruleName
  new nodes.$NODE_TYPE value

EOF

echo "Step 5: Test with: echo '<example>' | ./bin/coffee --cs3 -c -s"
