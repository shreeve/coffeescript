###
CS3 Minimal Grammar - Data-Oriented Actions
Generated from CoffeeScript grammar for testing with square.coffee
###

# Helper function to create data nodes
n = (type, props = {}) -> {$type: type, ...props}

# The minimal grammar with data-oriented actions
grammar =
  Root: [
    o 'Body', -> {"$type":"Root","body":{"$ref":1}}
  ]

  Yield: [
    o 'YIELD', -> {"$type":"Op","operator":{"$ref":1},"first":{"$type":"Value","base":{"$type":"Literal","args":[""]}}}
    o 'YIELD Expression', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
    o 'YIELD INDENT Object OUTDENT', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":3}}
    o 'YIELD FROM Expression', -> {"$type":"Op","operator":{"$ref":1,"call":"concat","args":[{"$ref":2}]},"first":{"$ref":3}}
  ]

  Block: [
    o 'INDENT OUTDENT', -> {"$type":"Block"}
  ]

  Identifier: [
    o 'IDENTIFIER', -> {"$type":"IdentifierLiteral","value":{"$ref":1}}
  ]

  Property: [
    o 'PROPERTY', -> {"$type":"PropertyName","value":{"$ref":1,"call":"toString","args":[]}}
  ]

  AlphaNumeric: [
    o 'NUMBER', -> {"$type":"NumberLiteral","value":{"$ref":1,"call":"toString","args":[]},"parsedValue":"parsedValue: $1.parsedValue"}
  ]

  Literal: [
    o 'JS', -> {"$type":"PassthroughLiteral","value":{"$ref":1,"call":"toString","args":[]},"here":"here: $1.here","generated":"generated: $1.generated"}
  ]

  Assign: [
    o 'Assignable = Expression', -> {"$type":"Assign","variable":{"$ref":1},"value":{"$ref":3}}
    o 'Assignable = TERMINATOR Expression', -> {"$type":"Assign","variable":{"$ref":1},"value":{"$ref":4}}
    o 'Assignable = INDENT Expression OUTDENT', -> {"$type":"Assign","variable":{"$ref":1},"value":{"$ref":4}}
  ]

  AssignObj: [
    o 'ObjAssignable', -> {"$type":"Value","base":{"$ref":1}}
    o 'ObjAssignable : Expression', -> {"$type":"Assign","variable":"LOC(1)(new Value $1)","value":{"$ref":3},"context":"object"}
    o 'SimpleObjAssignable = Expression', -> {"$type":"Assign","variable":"LOC(1)(new Value $1)","value":{"$ref":3},"context":"null"}
  ]

  ObjAssignable: [
    o '[ Expression ]', -> {"$type":"Value","base":{"$type":"ComputedPropertyName","args":[{"$ref":2}]}}
    o '@ [ Expression ]', -> {"$type":"Value","base":"LOC(1)(new ThisLiteral $1)","properties":{"$array":["LOC(3)(new ComputedPropertyName($3))"]}}
  ]

  ObjRestValue: [
    o 'SimpleObjAssignable ...', -> {"$type":"Splat","args":[{"$type":"Value","base":{"$ref":1}}]}
    o '... SimpleObjAssignable', -> {"$type":"Splat","args":[{"$type":"Value","base":{"$ref":2}},"postfix: no"]}
  ]

  ObjSpreadExpr: [
    o 'SimpleObjAssignable OptFuncExist Arguments', -> {"$type":"Call","variable":"(new Value $1)","args":{"$ref":3},"soak":{"$ref":2,"prop":"soak"}}
    o 'ObjSpreadExpr OptFuncExist Arguments', -> {"$type":"Call","variable":{"$ref":1},"args":{"$ref":3},"soak":{"$ref":2,"prop":"soak"}}
  ]

  ObjSpreadIdentifier: [
    o 'SimpleObjAssignable Accessor', -> "(new Value $1).add $2"
    o 'ObjSpreadExpr Accessor', -> "(new Value $1).add $2"
  ]

  Return: [
    o 'RETURN INDENT Object OUTDENT', -> {"$type":"Return","args":[{"$type":"Value","base":{"$ref":3}}]}
  ]

  Code: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Block', -> {"$type":"Code","params":{"$ref":2},"body":{"$ref":5},"bound":{"$ref":4},"isGenerator":"LOC(1)(new Literal $1)"}
    o 'FuncGlyph Block', -> {"$type":"Code","params":{"$array":[]},"body":{"$ref":2},"bound":{"$ref":1}}
  ]

  CodeLine: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Line', -> {"$type":"Code","params":{"$ref":2},"body":"LOC(5)(Block.wrap [$5])","bound":{"$ref":4}}
    o 'FuncGlyph Line', -> {"$type":"Code","params":{"$array":[]},"body":"LOC(2)(Block.wrap [$2])","bound":{"$ref":1}}
  ]

  Param: [
    o 'ParamVar', -> {"$type":"Param","name":{"$ref":1}}
    o 'ParamVar ...', -> {"$type":"Param","name":{"$ref":1},"value":"null","splat":"on"}
    o '... ParamVar', -> {"$type":"Param","name":{"$ref":2},"value":"null","splat":"postfix: no"}
    o 'ParamVar = Expression', -> {"$type":"Param","name":{"$ref":1},"value":{"$ref":3}}
  ]

  SimpleAssignable: [
    o 'Identifier', -> {"$type":"Value","base":{"$ref":1}}
    o 'Code Accessor', -> "new Value($1).add $2"
  ]

  Assignable: [
    o 'Array', -> {"$type":"Value","base":{"$ref":1}}
    o 'Object', -> {"$type":"Value","base":{"$ref":1}}
  ]

  Value: [
    o 'Literal', -> {"$type":"Value","base":{"$ref":1}}
    o 'Parenthetical', -> {"$type":"Value","base":{"$ref":1}}
    o 'Range', -> {"$type":"Value","base":{"$ref":1}}
    o 'Invocation', -> {"$type":"Value","base":{"$ref":1}}
    o 'DoIife', -> {"$type":"Value","base":{"$ref":1}}
    o 'Super', -> {"$type":"Value","base":{"$ref":1}}
    o 'MetaProperty', -> {"$type":"Value","base":{"$ref":1}}
  ]

  Super: [
    o 'SUPER . Property', -> {"$type":"Super","args":["LOC(3)(new Access $3)","LOC(1)(new Literal $1)"]}
  ]

  MetaProperty: [
    o 'NEW_TARGET . Property', -> {"$type":"MetaProperty","args":["LOC(1)(new IdentifierLiteral $1)","LOC(3)(new Access $3)"]}
    o 'IMPORT_META . Property', -> {"$type":"MetaProperty","args":["LOC(1)(new IdentifierLiteral $1)","LOC(3)(new Access $3)"]}
  ]

  Accessor: [
    o '.  Property', -> {"$type":"Access","name":{"$ref":2}}
    o '?. Property', -> {"$type":"Access","name":{"$ref":2},"soak":"soak: yes"}
    o ':: Property', -> {"$array":["LOC(1)(new Access new PropertyName('prototype'), shorthand: yes)","LOC(2)(new Access $2)"]}
    o '?:: Property', -> {"$array":["LOC(1)(new Access new PropertyName('prototype'), shorthand: yes, soak: yes)","LOC(2)(new Access $2)"]}
    o '::', -> {"$type":"Access","name":{"$type":"PropertyName","value":"prototype"},"soak":"shorthand: yes"}
    o '?::', -> {"$type":"Access","name":{"$type":"PropertyName","value":"prototype"},"soak":"shorthand: yes","shorthand":"soak: yes"}
  ]

  Export: [
    o 'EXPORT Identifier = Expression', -> {"$type":"ExportNamedDeclaration","args":["LOC(2,4)(new Assign $2, $4, null,"]}
    o 'EXPORT Identifier = TERMINATOR Expression', -> {"$type":"ExportNamedDeclaration","args":["LOC(2,5)(new Assign $2, $5, null,"]}
    o 'EXPORT Identifier = INDENT Expression OUTDENT', -> {"$type":"ExportNamedDeclaration","args":["LOC(2,6)(new Assign $2, $5, null,"]}
    o 'EXPORT DEFAULT INDENT Object OUTDENT', -> {"$type":"ExportDefaultDeclaration","args":[{"$type":"Value","base":{"$ref":4}}]}
  ]

  Invocation: [
    o 'Value OptFuncExist Arguments', -> {"$type":"Call","variable":{"$ref":1},"args":{"$ref":3},"soak":{"$ref":2,"prop":"soak"}}
  ]

  This: [
    o 'THIS', -> {"$type":"Value","base":{"$type":"ThisLiteral","args":[{"$ref":1}]}}
    o '@', -> {"$type":"Value","base":{"$type":"ThisLiteral","args":[{"$ref":1}]}}
  ]

  ThisProperty: [
    o '@ Property', -> {"$type":"Value","base":"LOC(1)(new ThisLiteral $1)","properties":{"$array":["LOC(2)(new Access($2))"]}}
  ]

  Catch: [
    o 'CATCH Object Block', -> {"$type":"Catch","args":[{"$ref":3},"LOC(2)(new Value($2))"]}
  ]

  Throw: [
    o 'THROW INDENT Object OUTDENT', -> {"$type":"Throw","args":[{"$type":"Value","base":{"$ref":3}}]}
  ]

  ForBody: [
    o 'FOR Range', -> {"$type":"For","args":[{"$array":[]},"source: (LOC(2) new Value($2))"]}
    o 'FOR Range BY Expression', -> {"$type":"For","args":[{"$array":[]},"source: (LOC(2) new Value($2))","step: $4"]}
  ]

  ForLineBody: [
    o 'FOR Range BY ExpressionLine', -> {"$type":"For","args":[{"$array":[]},"source: (LOC(2) new Value($2))","step: $4"]}
  ]

  ForValue: [
    o 'Array', -> {"$type":"Value","base":{"$ref":1}}
    o 'Object', -> {"$type":"Value","base":{"$ref":1}}
  ]

  OperationLine: [
    o 'UNARY ExpressionLine', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
    o 'DO ExpressionLine', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
    o 'DO_IIFE CodeLine', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
  ]

  Operation: [
    o 'UNARY Expression', -> {"$type":"Op","operator":{"$ref":1,"call":"toString","args":[]},"first":{"$ref":2},"second":"undefined","flip":"undefined","options":"originalOperator: $1.original"}
    o 'DO Expression', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
    o 'UNARY_MATH Expression', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
    o '-     Expression', -> {"$type":"Op","operator":"-","first":"$2), prec: 'UNARY_MATH'"}
    o '+     Expression', -> {"$type":"Op","operator":"+","first":"$2), prec: 'UNARY_MATH'"}
    o 'AWAIT Expression', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
    o 'AWAIT INDENT Object OUTDENT', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":3}}
    o '-- SimpleAssignable', -> {"$type":"Op","operator":"--","first":{"$ref":2}}
    o '++ SimpleAssignable', -> {"$type":"Op","operator":"++","first":{"$ref":2}}
    o 'SimpleAssignable --', -> {"$type":"Op","operator":"--","first":{"$ref":1},"second":"null","flip":true}
    o 'SimpleAssignable ++', -> {"$type":"Op","operator":"++","first":{"$ref":1},"second":"null","flip":true}
    o 'Expression +  Expression', -> {"$type":"Op","operator":"+","first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression -  Expression', -> {"$type":"Op","operator":"-","first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression MATH     Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression **       Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression SHIFT    Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression COMPARE  Expression', -> {"$type":"Op","operator":{"$ref":2,"call":"toString","args":[]},"first":{"$ref":1},"second":{"$ref":3},"flip":"undefined","options":"originalOperator: $2.original"}
    o 'Expression &        Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression ^        Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression |        Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression &&       Expression', -> {"$type":"Op","operator":{"$ref":2,"call":"toString","args":[]},"first":{"$ref":1},"second":{"$ref":3},"flip":"undefined","options":"originalOperator: $2.original"}
    o 'Expression ||       Expression', -> {"$type":"Op","operator":{"$ref":2,"call":"toString","args":[]},"first":{"$ref":1},"second":{"$ref":3},"flip":"undefined","options":"originalOperator: $2.original"}
    o 'Expression BIN?     Expression', -> {"$type":"Op","operator":{"$ref":2},"first":{"$ref":1},"second":{"$ref":3}}
    o 'Expression RELATION Expression', -> {"$type":"Op","operator":{"$ref":2,"call":"toString","args":[]},"first":{"$ref":1},"second":{"$ref":3},"flip":"undefined","options":"invertOperator: $2.invert?.original ? $2.invert"}
  ]

  DoIife: [
    o 'DO_IIFE Code', -> {"$type":"Op","operator":{"$ref":1},"first":{"$ref":2}}
  ]

# Export for use
exports.grammar = grammar