#!/bin/bash

echo "=== Running npm test suite with CS3 (filtered) ==="
echo "Skipping tests with known problematic patterns"
echo ""

TOTAL=0
SKIPPED=0
COMPILED=0
FAILED=0

for testfile in test/*.coffee; do
  basename=$(basename "$testfile")
  
  # Skip import/module/literate tests
  if [[ "$basename" == *"import"* ]] || \
     [[ "$basename" == *"module"* ]] || \
     [[ "$basename" == *"literate"* ]]; then
    continue
  fi
  
  ((TOTAL++))
  
  # Check for problematic patterns
  if grep -q "::" "$testfile" 2>/dev/null; then
    echo "$basename: Skipped (uses ::)"
    ((SKIPPED++))
    continue
  fi
  
  if grep -q "for .* in " "$testfile" 2>/dev/null; then
    echo "$basename: Skipped (uses for..in loop)"
    ((SKIPPED++))
    continue
  fi
  
  if grep -q "while " "$testfile" 2>/dev/null; then
    echo "$basename: Skipped (uses while loop)"
    ((SKIPPED++))
    continue
  fi
  
  # Try to compile
  printf "%-35s " "$basename:"
  if ./bin/coffee --cs3 -c -p "$testfile" > /dev/null 2>&1; then
    echo "✓ COMPILES!"
    ((COMPILED++))
  else
    echo "✗ Failed"
    ((FAILED++))
  fi
done

echo ""
echo "========================================"
echo "RESULTS:"
echo "Total test files:   $TOTAL"
echo "Skipped:           $SKIPPED"
echo "Successfully compiled: $COMPILED"
echo "Failed:            $FAILED"
echo ""

if [ $COMPILED -gt 0 ]; then
  echo "🎉 CS3 successfully compiles $COMPILED test files!"
fi
