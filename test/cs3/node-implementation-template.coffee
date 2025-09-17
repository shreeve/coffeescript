#!/usr/bin/env coffee

# Template for adding new node types to backends/es5/index.coffee
#
# STEP 1: Find the TODO in the output (e.g., "/* TODO: Solar StringLiteral */")
# STEP 2: Check the AST structure with --cs3-ast
# STEP 3: Add the case to evaluateDirective switch statement
# STEP 4: Test with simple example
# STEP 5: Test with complex example

# === EXAMPLE: StringLiteral Implementation ===

# 1. Check AST structure:
# echo 'x = "hello"' | ./bin/coffee --cs3-ast -s

# 2. See the directive structure:
# {
#   "type": "StringLiteral",
#   "value": "hello"
# }

# 3. Add to evaluateDirective switch:
###
when 'StringLiteral'
  value = @evaluateDirective directive.value, frame, ruleName
  new nodes.StringLiteral value
###

# === COMMON PATTERNS ===

# Simple value extraction:
###
when 'BooleanLiteral'
  value = @evaluateDirective directive.value, frame, ruleName
  new nodes.BooleanLiteral value
###

# Multiple properties:
###
when 'For'
  body = @evaluateDirective directive.body, frame, ruleName
  source = @evaluateDirective directive.source, frame, ruleName
  guard = @evaluateDirective directive.guard, frame, ruleName
  new nodes.For body, source, guard
###

# Arrays of nodes:
###
when 'Arr'
  objects = @evaluateDirective directive.objects, frame, ruleName
  objects = @filterNodes (if Array.isArray(objects) then objects else [])
  new nodes.Arr objects
###

# Optional properties with defaults:
###
when 'Code'
  params = @evaluateDirective directive.params, frame, ruleName
  body = @evaluateDirective directive.body, frame, ruleName
  tag = @evaluateDirective directive.tag, frame, ruleName
  new nodes.Code params or [], body, tag or 'func'
###

# === PRIORITY ORDER ===
#
# Priority 1 (Basic literals - needed for everything):
#   StringLiteral, BooleanLiteral, NullLiteral, UndefinedLiteral
#
# Priority 2 (Collections):
#   Arr, Obj, Range
#
# Priority 3 (Control flow):
#   If, Switch, Try, Throw
#
# Priority 4 (Loops):
#   For, While, Loop
#
# Priority 5 (Functions):
#   Code, Param, Return, Yield
#
# Priority 6 (Classes):
#   Class, Constructor, Super, Extends
#
# Priority 7 (Advanced):
#   Comprehension, Destructuring, Import, Export
