#!/bin/bash

# Test which node types are working vs TODO
echo "=== CS3 Node Implementation Coverage ==="

# Test basic literals
echo -e "\n--- Basic Literals ---"
echo '"hello"' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ StringLiteral"
echo 'true' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ BooleanLiteral"
echo 'null' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ NullLiteral"

# Test collections
echo -e "\n--- Collections ---"
echo '[1,2,3]' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ Arr"
echo '{a: 1}' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ Obj"
echo '[1..10]' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ Range"

# Test control flow
echo -e "\n--- Control Flow ---"
echo 'if x then y' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ If"
echo 'try x' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ Try"

# Test loops
echo -e "\n--- Loops ---"
echo 'for x in y then z' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ For"
echo 'while x then y' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ While"

# Test functions
echo -e "\n--- Functions ---"
echo '-> x' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ Code"
echo 'return x' | ./bin/coffee --cs3 -c -s 2>&1 | grep -o "TODO.*" | head -1 || echo "✅ Return"
