; Block structures and multi-line containers that increase indentation
[
  (block)
  (struct_definition)
  (enum_definition)
  (match_expression)
  (struct_literal_fields)
  (parameters)
  (arguments)
  (array_expression)
  (array_type)
  (tuple_expression)
  (tuple_type)
  (tuple_definition)
] @indent.begin

; Closing delimiters that un-indent
[
  "}"
  ")"
  "]"
] @indent.end

; Branch control keywords
[
  "else"
] @indent.branch
