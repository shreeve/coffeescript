# Strings
# -------

# String literals

test "single quote string", "'hello'", 'hello'
test "double quote string", '"hello"', 'hello'
test "empty string", "''", ''

# String concatenation

test "string concatenation", """
  'hello' + ' ' + 'world'
""", 'hello world'

test "string concatenation multiline", """
  str = 'hello' +
        ' ' +
        'world'
  str
""", 'hello world'

# String interpolation

test "basic interpolation", """
  name = 'World'
  "Hello \#{name}"
""", 'Hello World'

test "expression interpolation", """
  "2 + 2 = \#{2 + 2}"
""", '2 + 2 = 4'

test "nested interpolation", """
  x = 5
  y = 10
  "x = \#{x}, y = \#{y}, sum = \#{x + y}"
""", 'x = 5, y = 10, sum = 15'

# Multiline strings

test "multiline string basic", '''
  """
  Line 1
  Line 2
  """
''', 'Line 1\\nLine 2'

test "multiline string indented", '''
  str = """
    Indented
    String
  """
  str
''', 'Indented\\nString'

# Block strings

test "block string single quotes", """
  '''
  Block
  String
  '''
""", 'Block\\nString'

# Escape sequences

test "escape newline", '"line1\\nline2"', 'line1\\nline2'
test "escape tab", '"col1\\tcol2"', 'col1\\tcol2'
test "escape quote", '"It\\'s"', "It's"
test "escape backslash", '"back\\\\slash"', 'back\\slash'

# String methods

test "string length", '"hello".length', 5
test "string charAt", '"hello".charAt(1)', 'e'
test "string indexOf", '"hello".indexOf("l")', 2
test "string slice", '"hello".slice(1, 4)', 'ell'
test "string substring", '"hello".substring(1, 4)', 'ell'
test "string substr", '"hello".substr(1, 3)', 'ell'

# String case

test "toUpperCase", '"hello".toUpperCase()', 'HELLO'
test "toLowerCase", '"HELLO".toLowerCase()', 'hello'

# String trimming

test "trim", '" hello ".trim()', 'hello'
test "trimStart", '" hello".trimStart()', 'hello'
test "trimEnd", '"hello ".trimEnd()', 'hello'

# String splitting and joining

test "split", '"a,b,c".split(",")', ['a', 'b', 'c']
test "split with limit", '"a,b,c".split(",", 2)', ['a', 'b']
test "join", '["a", "b", "c"].join(",")', 'a,b,c'

# String replacement

test "replace first", '"hello".replace("l", "L")', 'heLlo'
test "replace global", '"hello".replace(/l/g, "L")', 'heLLo'

# String search

test "includes", '"hello".includes("ell")', true
test "includes false", '"hello".includes("xyz")', false
test "startsWith", '"hello".startsWith("he")', true
test "endsWith", '"hello".endsWith("lo")', true

# String repeat

test "repeat", '"ab".repeat(3)', 'ababab'
test "repeat zero", '"ab".repeat(0)', ''

# String padding

test "padStart", '"5".padStart(3, "0")', '005'
test "padEnd", '"5".padEnd(3, "0")', '500'

# Template literals

test "template literal", '`hello`', 'hello'
test "template with expression", '`2 + 2 = ${2 + 2}`', '2 + 2 = 4'

# String comparison

test "string equality", '"hello" is "hello"', true
test "string inequality", '"hello" isnt "world"', true
test "string less than", '"a" < "b"', true
test "string greater than", '"b" > "a"', true

# String coercion

test "number to string", '5 + ""', '5'
test "boolean to string", 'true + ""', 'true'
test "String constructor", 'String(42)', '42'

# Character codes

test "charCodeAt", '"A".charCodeAt(0)', 65
test "fromCharCode", 'String.fromCharCode(65)', 'A'

# Regular expressions in strings

test "string match", '"hello".match(/l+/)[0]', 'll'
test "string search method", '"hello".search("l")', 2

# Tagged template literals

test "tagged template function", """
  tag = (strings, ...values) -> strings.join('')
  tag\`hello world\`
""", 'hello world'

# Heredocs

test "heredoc", '''
  """
    This is a heredoc
    It preserves indentation
  """
''', '  This is a heredoc\\n  It preserves indentation'

# String iteration

test "string spread", '[..."abc"]', ['a', 'b', 'c']
test "string for loop", """
  result = []
  for char in 'abc'
    result.push char
  result
""", ['a', 'b', 'c']

# Empty string checks

test "empty string falsy", '!! ""', false
test "non-empty string truthy", '!! "hello"', true

# String raw

test "String.raw", 'String.raw`\\n`', '\\n'

# Backslash escapes
test 'backslash escapes', '"\\/\\\\"', '/\\'

# Multiline string joining
test 'multiline literal joining', '"one\n two\n three"', 'one two three'

# Escaped backslash at end of line
test 'escaped backslash EOL', '"line1\\\\\nline2"', 'line1\\ line2'

# Unicode escapes
test 'unicode escape', '"\\u0041"', 'A'
test 'unicode escape emoji', '"\\u{1F600}"', '😀'

# String indexing
test 'string bracket indexing', '"hello"[1]', 'e'
test 'string negative indexing', '"hello"[-1]', undefined

# toString on string literals
test 'string toString', '"hello".toString()', 'hello'

# String constructor with new
test 'new String', '(new String("hello")).valueOf()', 'hello'
