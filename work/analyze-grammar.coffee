#!/usr/bin/env coffee

# ==============================================================================
# Grammar Analyzer - Extract and Analyze All Actions from grammar.coffee
# ==============================================================================

fs = require 'fs'
path = require 'path'

class GrammarAnalyzer
  constructor: (@filePath) ->
    @rules = {}
    @actions = []
    @statistics =
      totalRules: 0
      rulesWithActions: 0
      passthroughRules: 0
      singleLineActions: 0
      multiLineActions: 0
      classInstantiations: {}
      helpers: {}
      patterns: {}

  analyze: ->
    content = fs.readFileSync @filePath, 'utf8'
    lines = content.split '\n'

    inGrammar = false
    currentNonterminal = null
    inRule = false
    rulePattern = null
    inAction = false
    actionLines = []
    actionIndent = 0
    lineNum = 0

    for line in lines
      lineNum++

      # Track grammar section
      if line.match /^grammar\s*=/
        inGrammar = true
        continue

      if line.match /^operators\s*=/
        inGrammar = false
        break

      if inGrammar
        # Check for nonterminal definition
        if match = line.match /^\s*(\w+):\s*\[/
          currentNonterminal = match[1]
          @rules[currentNonterminal] = []
          continue

        # Check for rule with pattern
        if match = line.match /^\s*o\s+'([^']*)'(?:\s*,\s*(.*))?$/
          pattern = match[1]
          rest = match[2] or ''

          # Check if action starts on same line
          if arrowMatch = rest.match /^(.*?)->\s*(.*)$/
            beforeArrow = arrowMatch[1]
            afterArrow = arrowMatch[2].trim()

            if afterArrow
              # Single-line action
              @addRule currentNonterminal, pattern, afterArrow, lineNum, lineNum
              @statistics.singleLineActions++
            else
              # Multi-line action starting
              inAction = true
              rulePattern = pattern
              actionLines = []
              actionIndent = line.match(/^\s*/)?[0].length or 0
          else
            # No action (passthrough)
            @addRule currentNonterminal, pattern, null, lineNum, lineNum
            @statistics.passthroughRules++

        else if match = line.match /^\s*o\s+'([^']*)'.*?->\s*$/
          # Multi-line action starting
          pattern = match[1]
          inAction = true
          rulePattern = pattern
          actionLines = []
          actionIndent = line.match(/^\s*/)?[0].length or 0

        else if inAction
          currentIndent = line.match(/^\s*/)?[0].length or 0

          # Check if still in action
          if line.trim() is '' or (currentIndent > actionIndent and not line.match(/^\s*o\s+'/))
            actionLines.push line
          else
            # Action ended
            if actionLines.length > 0
              actionStr = actionLines.join('\n').trim()
              @addRule currentNonterminal, rulePattern, actionStr, lineNum - actionLines.length, lineNum - 1
              @statistics.multiLineActions++

            inAction = false
            actionLines = []

            # Check if this line is a new rule
            if match = line.match /^\s*o\s+'([^']*)'(?:\s*,\s*(.*))?$/
              pattern = match[1]
              rest = match[2] or ''

              if arrowMatch = rest.match /^(.*?)->\s*(.*)$/
                afterArrow = arrowMatch[2].trim()
                if afterArrow
                  @addRule currentNonterminal, pattern, afterArrow, lineNum, lineNum
                  @statistics.singleLineActions++
                else
                  inAction = true
                  rulePattern = pattern
                  actionLines = []
                  actionIndent = line.match(/^\s*/)?[0].length or 0
              else
                @addRule currentNonterminal, pattern, null, lineNum, lineNum
                @statistics.passthroughRules++

    # Handle any remaining action
    if inAction and actionLines.length > 0
      actionStr = actionLines.join('\n').trim()
      @addRule currentNonterminal, rulePattern, actionStr, lineNum - actionLines.length, lineNum
      @statistics.multiLineActions++

    @analyzeActions()
    this

  addRule: (nonterminal, pattern, action, startLine, endLine) ->
    return unless nonterminal

    rule =
      nonterminal: nonterminal
      pattern: pattern
      action: action
      startLine: startLine
      endLine: endLine
      hasAction: action?

    @rules[nonterminal].push rule
    @actions.push rule
    @statistics.totalRules++
    @statistics.rulesWithActions++ if action

  analyzeActions: ->
    for rule in @actions when rule.action
      action = rule.action

      # Count class instantiations
      classMatches = action.match(/new\s+(\w+)/g) or []
      for match in classMatches
        className = match.replace('new ', '')
        @statistics.classInstantiations[className] = (@statistics.classInstantiations[className] or 0) + 1

      # Count helper functions
      if action.includes 'Block.wrap'
        @statistics.helpers['Block.wrap'] = (@statistics.helpers['Block.wrap'] or 0) + 1
      if action.includes 'LOC('
        @statistics.helpers['LOC'] = (@statistics.helpers['LOC'] or 0) + 1
      if action.includes 'extend('
        @statistics.helpers['extend'] = (@statistics.helpers['extend'] or 0) + 1

      # Identify patterns
      if action.match /^\$\d+$/
        @statistics.patterns['simple_passthrough'] = (@statistics.patterns['simple_passthrough'] or 0) + 1
      if action.match /\$\d+\.\w+/
        @statistics.patterns['property_access'] = (@statistics.patterns['property_access'] or 0) + 1
      if action.match /\$\d+\.push/
        @statistics.patterns['array_push'] = (@statistics.patterns['array_push'] or 0) + 1
      if action.match /\$\d+\.concat/
        @statistics.patterns['array_concat'] = (@statistics.patterns['array_concat'] or 0) + 1
      if action.match /\$\d+\.add/
        @statistics.patterns['method_call'] = (@statistics.patterns['method_call'] or 0) + 1

  printReport: ->
    console.log """
    ================================================================================
    Grammar Analysis Report
    ================================================================================

    📊 Overall Statistics:
    ----------------------
    Total rules:           #{@statistics.totalRules}
    Rules with actions:    #{@statistics.rulesWithActions}
    Passthrough rules:     #{@statistics.passthroughRules}
    Single-line actions:   #{@statistics.singleLineActions}
    Multi-line actions:    #{@statistics.multiLineActions}

    📦 Class Instantiations:
    ------------------------
    """

    # Sort classes by frequency
    classes = Object.entries(@statistics.classInstantiations).sort (a, b) -> b[1] - a[1]
    for [className, count] in classes[0...20]  # Top 20
      console.log "  #{className.padEnd(25)} #{count}"

    if classes.length > 20
      console.log "  ... and #{classes.length - 20} more"

    console.log """

    🔧 Helper Functions:
    --------------------
    """

    for helper, count of @statistics.helpers
      console.log "  #{helper.padEnd(25)} #{count}"

    console.log """

    🎯 Action Patterns:
    -------------------
    """

    for pattern, count of @statistics.patterns
      console.log "  #{pattern.padEnd(25)} #{count}"

    console.log """

    📝 Nonterminals:
    ----------------
    """

    nonterminals = Object.keys(@rules).sort()
    for nt in nonterminals[0...20]  # First 20
      ruleCount = @rules[nt].length
      withActions = @rules[nt].filter((r) -> r.hasAction).length
      console.log "  #{nt.padEnd(25)} #{ruleCount} rules (#{withActions} with actions)"

    if nonterminals.length > 20
      console.log "  ... and #{nonterminals.length - 20} more"

  exportActions: (outputPath) ->
    output = []
    output.push "# Extracted Actions from #{@filePath}"
    output.push "# Generated: #{new Date().toISOString()}"
    output.push ""

    for nt, rules of @rules
      output.push ""
      output.push "# #{nt}"
      output.push "# " + "=".repeat(60)

      for rule, i in rules
        output.push ""
        output.push "# Rule #{i + 1}: '#{rule.pattern}'"
        output.push "# Lines: #{rule.startLine}-#{rule.endLine}"

        if rule.action
          if rule.action.includes('\n')
            output.push "# Multi-line action:"
            for line in rule.action.split('\n')
              output.push "#   #{line}"
          else
            output.push "# Action: #{rule.action}"
        else
          output.push "# Action: <passthrough>"

    fs.writeFileSync outputPath, output.join('\n')
    console.log "\n✅ Exported all actions to: #{outputPath}"

  findComplexActions: ->
    complex = []

    for rule in @actions when rule.action
      isComplex = false
      reasons = []

      # Check complexity indicators
      if rule.action.includes('if ') or rule.action.includes('unless ')
        isComplex = true
        reasons.push 'conditional logic'

      if rule.action.match(/for\s+\w+\s+in/)
        isComplex = true
        reasons.push 'loop'

      if rule.action.split('\n').length > 5
        isComplex = true
        reasons.push 'many lines'

      if rule.action.match(/\$\d+\[/)
        isComplex = true
        reasons.push 'array indexing'

      if rule.action.includes('.slice') or rule.action.includes('.split')
        isComplex = true
        reasons.push 'string manipulation'

      if rule.action.match(/\{[^}]{50,}/)
        isComplex = true
        reasons.push 'complex object literal'

      if isComplex
        complex.push
          nonterminal: rule.nonterminal
          pattern: rule.pattern
          reasons: reasons
          lineCount: rule.action.split('\n').length

    console.log """

    ⚠️  Complex Actions Requiring Special Attention:
    ------------------------------------------------
    """

    for item in complex[0...10]  # Top 10
      console.log "  #{item.nonterminal} / '#{item.pattern}'"
      console.log "    Reasons: #{item.reasons.join(', ')}"
      console.log "    Lines: #{item.lineCount}"

    if complex.length > 10
      console.log "\n  ... and #{complex.length - 10} more complex actions"

# ==============================================================================
# Main
# ==============================================================================

if require.main is module
  grammarPath = path.join __dirname, 'src', 'grammar.coffee'

  unless fs.existsSync grammarPath
    console.error "Error: #{grammarPath} not found"
    process.exit 1

  console.log "Analyzing #{grammarPath}..."
  console.log ""

  analyzer = new GrammarAnalyzer grammarPath
  analyzer.analyze()
  analyzer.printReport()
  analyzer.findComplexActions()

  # Export to file
  outputPath = path.join __dirname, 'grammar-actions.txt'
  analyzer.exportActions outputPath

module.exports = GrammarAnalyzer
