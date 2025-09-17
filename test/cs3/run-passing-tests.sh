#!/bin/bash

echo "=== Running tests that compile with CS3 ==="
echo ""

# Test infrastructure
cat > /tmp/test-infra.js << 'INFRA'
global.test = function(description, fn) {
  try {
    fn();
    process.stdout.write("✓");
    global.passedTests = (global.passedTests || 0) + 1;
  } catch(err) {
    process.stdout.write("✗");
    global.failedTests = (global.failedTests || 0) + 1;
  }
};

global.eq = function(a, b) {
  if (a !== b && (a + '') !== (b + '')) {
    throw new Error(`${a} != ${b}`);
  }
};

global.ok = function(val) {
  if (!val) throw new Error("Assertion failed");
};

global.arrayEq = function(a, b) {
  if (a.length !== b.length) throw new Error("Array length mismatch");
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) throw new Error(`Array mismatch at ${i}`);
  }
};
INFRA

for testfile in test/cluster.coffee test/exponentiation.coffee test/numbers_bigint.coffee test/regex_dotall.coffee; do
  basename=$(basename "$testfile")
  echo ""
  echo "Running $basename:"
  
  # Compile with CS3
  ./bin/coffee --cs3 -c "$testfile" 2>/dev/null
  jsfile="${testfile%.coffee}.js"
  
  if [ -f "$jsfile" ]; then
    # Run the compiled JS with test infrastructure
    node -e "$(cat /tmp/test-infra.js); $(cat $jsfile); console.log('\nPassed:', global.passedTests || 0, 'Failed:', global.failedTests || 0);"
    rm -f "$jsfile"
  else
    echo "Failed to compile"
  fi
done

rm -f /tmp/test-infra.js
