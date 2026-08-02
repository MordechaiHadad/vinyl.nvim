; 1. Delimiter Scopes (Handles block, struct, enum, tuple, array, and args bodies)
[
  "{"
  "("
  "["
] @indent.begin

[
  "}"
  ")"
  "]"
] @indent.end

; 2. Non-Delimiter Scopes
; Indent arms inside a match statement (if they span multiple lines)
(match_arm) @indent.begin

; 3. Branch Keywords
[
  "else"
] @indent.branch
