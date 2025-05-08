package zc

import "core:os"
import "core:fmt"
import "core:unicode"
import "core:path/filepath"

Exp_Kind :: enum {
  IDENTIFIER,
  KEYWORD,
  INTEGER,
  FLOAT,
  STRING,
  ARRAY,
}

Exp :: struct {
  kind: Exp_Kind,
  using data: struct #raw_union {
    as_atom: string,
    as_array: [dynamic]^Exp,
  },
}

parse_exp :: proc(s: string, p: int, filename := "") -> (^Exp, int) {
  p := p
  level_stack: [dynamic]bool
  defer delete(level_stack)
  stack: [dynamic]^Exp
  defer delete(stack)

  for {
    start := p
    newline_was_skipped := false
    for {
      for p < len(s) && unicode.is_space(rune(s[p])) {
        if s[p] == '\n' do newline_was_skipped = true
        p += 1
      }
      if p < len(s) && s[p] == ';' {
        for p < len(s) && s[p] != '\n' do p += 1
        continue
      }
      break
    }

    first_exp_of_line := newline_was_skipped || start == 0

    if p >= len(s) do break
    start = p

    if first_exp_of_line && s[p] != '(' && s[p] != ')' {
      append(&level_stack, true)
      exp := new(Exp)
      exp.kind = .ARRAY
      append(&stack, exp)
    }

    if s[p] == '(' {
      p += 1
      append(&level_stack, false)
      exp := new(Exp)
      exp.kind = .ARRAY
      append(&stack, exp)
    } else if s[p] == ')' {
      p += 1
      if len(level_stack) <= 0 do fmt.panicf("%s:=%d Unexpected )", filename, start)

      idx := len(level_stack) - 1
      for idx >= 0 && level_stack[idx] do idx -= 1
      if idx < 0 do fmt.panicf("%s:=%d Unmatched )", filename, start)

      for i := len(level_stack) - 1; i >= idx; i -= 1 {
        pop(&level_stack)
        popped := pop(&stack)
        append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, popped)
      }
    } else if unicode.is_digit(rune(s[p])) {
      for p < len(s) && unicode.is_digit(rune(s[p])) do p += 1
      exp := new(Exp)
      exp.kind = .INTEGER
      exp.as_atom = s[start:p]
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, exp)
    } else if s[p] == '\'' {
      p += 1
      exp := new(Exp);
      exp.kind = .ARRAY;
      identifier := new(Exp);
      identifier.kind = .IDENTIFIER
      identifier.as_atom = "$codeof"
      append(&exp.as_array, identifier)
      code, next_p := parse_exp(s, p, filename)
      append(&exp.as_array, code)
      p = next_p
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, exp)
    } else {
      for p < len(s) && !unicode.is_space(rune(s[p])) && s[p] != ')' do p += 1
      exp := new(Exp)
      exp.kind = .IDENTIFIER
      exp.as_atom = s[start:p]
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, exp)
    }

    peek := p
    for peek < len(s) && s[peek] != '\n' && unicode.is_space(rune(s[peek])) do peek += 1
    if peek >= len(s) || s[peek] == '\n' || s[peek] == ';' {
      for len(level_stack) > 0 && level_stack[len(level_stack) - 1] {
        pop(&level_stack)
        popped := pop(&stack)
        append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, popped)
      }
    }

    if len(level_stack) == 0 do break
  }
  if len(level_stack) != 0 do fmt.panicf("%s:=%d Missing )", filename, p)
  assert(len(stack) <= 1)
  return pop(&stack) if len(stack) > 0 else nil, p
}

print_exp :: proc(x: ^Exp, level := 0, show_kinds := false) {
  if show_kinds do fmt.printf("%s[", x.kind)
  switch x.kind {
    case .IDENTIFIER: fallthrough
    case .KEYWORD: fallthrough
    case .INTEGER: fallthrough
    case .FLOAT: fallthrough
    case .STRING: fmt.printf("%s", x.as_atom)
    case.ARRAY:
      fmt.printf("(")
      for x2, index in x.as_array {
        print_exp(x2, level + 1, show_kinds)
        if index != len(x.as_array) - 1 do fmt.printf(" ")
      }
      fmt.printf(")")
  }
  if show_kinds do fmt.printf("]")
}

main :: proc() {
  if len(os.args) == 0 do fmt.panicf("I expected there to be at least one argument.\n")
  if len(os.args) == 1 do fmt.panicf("Please provide me a file to compile, like this: %s your_main_file.z", filepath.base(os.args[0]))

  filename := os.args[1]
  src, success := os.read_entire_file(filename)
  if !success do fmt.panicf("I failed to read '%s' from your drive. Maybe you need to quote the entire path?", filename)

  pos := 0
  for {
    exp, next_pos := parse_exp(string(src), pos, filename)
    if exp == nil do break
    pos = next_pos
    print_exp(exp, show_kinds=false)
    fmt.printf("\n")
  }
}
