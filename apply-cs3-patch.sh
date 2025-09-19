#!/bin/bash

# Script to apply minimal CS3 patch to CoffeeScript commit 817c39a
# This adds CS3 functionality with the Solar parser and ES5 backend

echo "=== CS3 Minimal Patch Installer ==="
echo ""

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Store current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Check if cs3 branch exists
if ! git show-ref --verify --quiet refs/heads/cs3; then
    echo "Error: cs3 branch not found. You need the cs3 branch available."
    exit 1
fi

echo ""
echo "This will add CS3 support to commit 817c39a"
echo "Files to be added:"
echo "  - src/syntax.coffee (CS3 grammar)"
echo "  - solar.coffee (Parser generator)"
echo "  - backends/es5/index.coffee (ES5 backend)"
echo "  - Minimal Cakefile modifications"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Create a new branch for the patch
PATCH_BRANCH="cs3-minimal-patch"
echo ""
echo "Creating branch: $PATCH_BRANCH from 817c39a..."

# Checkout the target commit
git checkout -b $PATCH_BRANCH 817c39a

# Copy essential CS3 files
echo ""
echo "Copying CS3 core files..."
git checkout cs3 -- src/syntax.coffee
git checkout cs3 -- solar.coffee
mkdir -p backends/es5
git checkout cs3 -- backends/es5/index.coffee

# Create minimal lib/backends directory
mkdir -p lib/backends/es5

# Apply minimal Cakefile patch
echo ""
echo "Patching Cakefile..."
cat >> Cakefile << 'EOF'

# CS3 Support - Minimal Patch
buildParserCS3 = ->
  helpers.extend global, require 'util'
  syntax = require('./src/syntax')
  language =
    grammar: syntax.grammar
    operators: syntax.operators
  {Generator} = require './solar.coffee'
  parser = Generator(language).generate(compress: !true)
  fs.writeFileSync 'lib/coffeescript/parser-cs3.js', parser
  console.log "CS3 parser built successfully!"

task 'build:parser-cs3', 'build the CS3 parser using Solar', buildParserCS3

task 'test:cs3', 'test CS3 compilation', ->
  console.log "Building CS3 parser..."
  buildParserCS3()
  
  # Simple inline test
  {Lexer} = require './lib/coffeescript/lexer'
  parserCS3 = require './lib/coffeescript/parser-cs3'
  
  # Compile the ES5 backend
  {exec} = require 'child_process'
  exec 'coffee -c backends/es5/index.coffee', (err) ->
    if err
      console.error "Failed to compile ES5 backend:", err
      process.exit 1
    
    ES5Backend = require './backends/es5/index'
    
    code = 'x = 42\nconsole.log x'
    console.log "\nTesting CS3 with code:\n#{code}\n"
    
    try
      lexer = new Lexer()
      tokens = lexer.tokenize code
      backend = new ES5Backend()
      parserCS3.yy = {backend}
      ast = parserCS3.parse tokens
      result = ast.compileToFragments().map((f) -> f.code).join('')
      console.log "CS3 compiled output:\n#{result}"
      console.log "\n✅ CS3 is working!"
    catch e
      console.error "CS3 test failed:", e
      process.exit 1
EOF

echo ""
echo "Compiling ES5 backend..."
coffee -c backends/es5/index.coffee
cp backends/es5/index.js lib/backends/es5/

echo ""
echo "Building CS3 parser..."
cake build:parser-cs3

echo ""
echo "✅ CS3 patch applied successfully!"
echo ""
echo "You can now test CS3 with:"
echo "  cake test:cs3"
echo ""
echo "To use CS3 in your code:"
echo "  1. Require the parser: parserCS3 = require('./lib/coffeescript/parser-cs3')"
echo "  2. Use the ES5 backend: ES5Backend = require('./backends/es5')"
echo ""
echo "Current branch: $PATCH_BRANCH"
echo "Original branch was: $CURRENT_BRANCH"
