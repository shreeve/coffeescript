
var arrayEgal, diffOutput, egal, getAstExpressions, getAstRoot;

egal = function(a, b) {
  if (a === b) {
    return a !== 0 || 1 / a === 1 / b;
  } else {
    return a !== a && b !== b;
  }
};

arrayEgal = function(a, b) {
  var el, i, idx, len;
  if (egal(a, b)) {
    return true;
  } else if (a instanceof Array && b instanceof Array) {
    if (a.length !== b.length) {
      return false;
    }
    for (idx = i = 0, len = a.length; i < len; idx = ++i) {
      el = a[idx];
      if (!arrayEgal(el, b[idx])) {
        return false;
      }
    }
    return true;
  }
};

diffOutput = function(expectedOutput, actualOutput) {
  var actualOutputLines, expectedOutputLines, i, j, len, line;
  expectedOutputLines = expectedOutput.split('\n');
  actualOutputLines = actualOutput.split('\n');
  for (i = j = 0, len = actualOutputLines.length; j < len; i = ++j) {
    line = actualOutputLines[i];
    if (line !== expectedOutputLines[i]) {
      actualOutputLines[i] = `${yellow}${line}${reset}`;
    }
  }
  return `Expected generated JavaScript to be:
${reset}${expectedOutput}${red}
  but instead it was:
${reset}${actualOutputLines.join('\n')}${red}`;
};

exports.eq = function(a, b, msg) {
  return ok(egal(a, b), msg || `Expected ${reset}${a}${red} to equal ${reset}${b}${red}`);
};

exports.arrayEq = function(a, b, msg) {
  return ok(arrayEgal(a, b), msg || `Expected ${reset}${a}${red} to deep equal ${reset}${b}${red}`);
};

exports.eqJS = function(input, expectedOutput, msg) {
  var actualOutput;
  actualOutput = CoffeeScript.compile(input, {
    bare: true
  }).replace(/^\s+|\s+$/g, '');
  return ok(egal(expectedOutput, actualOutput), msg || diffOutput(expectedOutput, actualOutput));
};

exports.isWindows = function() {
  return process.platform === 'win32';
};

exports.inspect = function(obj) {
  if (global.testingBrowser) {
    return JSON.stringify(obj, null, 2);
  } else {
    return require('util').inspect(obj);
  }
};

exports.getAstRoot = getAstRoot = function(code) {
  return CoffeeScript.compile(code, {
    ast: true
  });
};

getAstExpressions = function(code) {
  var ast;
  ast = getAstRoot(code);
  return ast.program.body;
};

exports.getAstExpression = function(code) {
  var expressionStatementAst;
  expressionStatementAst = getAstExpressions(code)[0];
  ok(expressionStatementAst.type === 'ExpressionStatement', 'Expected ExpressionStatement AST wrapper');
  return expressionStatementAst.expression;
};

exports.getAstStatement = function(code) {
  var statement;
  statement = getAstExpressions(code)[0];
  ok(statement.type !== 'ExpressionStatement', "Didn't expect ExpressionStatement AST wrapper");
  return statement;
};

exports.getAstExpressionOrStatement = function(code) {
  var expressionAst;
  expressionAst = getAstExpressions(code)[0];
  if (expressionAst.type !== 'ExpressionStatement') {
    return expressionAst;
  }
  return expressionAst.expression;
};

exports.throwsCompileError = function(code, compileOpts, ...args) {
  throws(function() {
    return CoffeeScript.compile(code, compileOpts, ...args);
  });
  return throws(function() {
    return CoffeeScript.compile(code, Object.assign({}, compileOpts != null ? compileOpts : {}, {
      ast: true
    }), ...args);
  });
};

exports.doesNotThrowCompileError = function(code, compileOpts, ...args) {
  doesNotThrow(function() {
    return CoffeeScript.compile(code, compileOpts, ...args);
  });
  return doesNotThrow(function() {
    return CoffeeScript.compile(code, Object.assign({}, compileOpts != null ? compileOpts : {}, {
      ast: true
    }), ...args);
  });
};
