; AST containers that establish an indented body
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

; Closing tokens that pull the line back left
[
  "}"
  ")"
  "]"
] @indent.end

; Align conditional branches
[
  "else"
] @indent.branch
