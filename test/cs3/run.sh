#!/bin/bash
# CS3 Test Suite Runner
# Quick way to run all CS3/ES5 tests
# Usage: ./test/cs3/run.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run the test runner
"$SCRIPT_DIR/../../bin/coffee" "$SCRIPT_DIR/runner.coffee" "$@"
