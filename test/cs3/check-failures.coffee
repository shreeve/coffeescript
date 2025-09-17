fs = require 'fs'
{execSync} = require 'child_process'

output = execSync('coffee cs3-runner.coffee 2>&1', encoding: 'utf8')
lines = output.split('\n')

testFiles = {}
currentFile = null

for line in lines
  if line.includes('Testing:')
    match = line.match(/Testing: (.+\.test\.coffee)/)
    if match
      currentFile = match[1]
      testFiles[currentFile] = {passed: 0, failed: 0, error: null}
  else if currentFile and line.includes('✓')
    testFiles[currentFile].passed++
  else if currentFile and line.includes('✗')
    testFiles[currentFile].failed++
  else if currentFile and line.includes('Compilation/Runtime Error:')
    testFiles[currentFile].error = line.replace(/.*Error: /, '')

console.log "\nTest File Summary:"
console.log "=================="

totalPassed = 0
totalFailed = 0

for file, results of testFiles
  totalPassed += results.passed
  totalFailed += results.failed

  status = if results.error
    "ERROR: #{results.error}"
  else if results.failed > 0
    "#{results.passed}/#{results.passed + results.failed} tests pass"
  else
    "All #{results.passed} tests pass ✓"

  console.log "#{file}: #{status}"

console.log "\nTotal: #{totalPassed} passed, #{totalFailed} failed"
