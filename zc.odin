package main

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:unicode"

Code_Kind :: enum {
  IDENTIFIER,
  KEYWORD,
  INTEGER,
  FLOAT,
  STRING,
  ARRAY,
}

Code :: struct {
  loc: int,
  kind: Code_Kind,
  using data: struct #raw_union {
    as_atom: string,
    as_array: [dynamic]^Code,
  },
}

parse_code :: proc(s: string, p: int, filename: string) -> (^Code, int) {
  p := p
  implicit_indent_stack: [dynamic]int
  defer delete(implicit_indent_stack)
  level_stack: [dynamic]bool
  defer delete(level_stack)
  stack: [dynamic]^Code
  defer delete(stack)

  for {
    start := p
    last_newline := p - 1
    newline_was_skipped := false
    for {
      for p < len(s) && unicode.is_space(rune(s[p])) {
        if s[p] == '\n' {
          last_newline = p
          newline_was_skipped = true
        }
        p += 1
      }
      if p < len(s) && s[p] == ';' {
        for p < len(s) && s[p] != '\n' do p += 1
        continue
      }
      break
    }

    first_exp_of_line := newline_was_skipped || start == 0

    indent := p - (last_newline + 1)
    if p >= len(s) do break
    start = p

    if first_exp_of_line && s[p] != '(' && s[p] != ')' {
      append(&implicit_indent_stack, indent)
      append(&level_stack, true)
      code := new(Code)
      code.loc = p
      code.kind = .ARRAY
      append(&stack, code)
    }

    if s[p] == '(' {
      p += 1
      append(&level_stack, false)
      code := new(Code)
      code.loc = p
      code.kind = .ARRAY
      append(&stack, code)
    } else if s[p] == ')' {
      p += 1

      for len(level_stack) > 0 && level_stack[len(level_stack) - 1] {
        pop(&level_stack)
        popped := pop(&stack)
        append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, popped)
        pop(&implicit_indent_stack)
      }
      if len(level_stack) == 0 do fmt.panicf("%s:=%d unexpected ).\n", filename, start)

      pop(&level_stack)
      popped := pop(&stack)
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, popped)
    } else if unicode.is_digit(rune(s[p])) {
      for p < len(s) && unicode.is_digit(rune(s[p])) do p += 1
      code := new(Code)
      code.loc = start
      code.kind = .INTEGER
      code.as_atom = s[start:p]
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, code)
    } else if s[p] == '\'' {
      p += 1
      array := new(Code)
      array.loc = start
      array.kind = .ARRAY
      identifier := new(Code)
      identifier.loc = start
      identifier.kind = .IDENTIFIER
      identifier.as_atom = "$code-of"
      append(&array.as_array, identifier)
      code, next_pos := parse_code(s, p, filename)
      p = next_pos
      append(&array.as_array, code)
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, array)
    } else {
      for p < len(s) && (!unicode.is_space(rune(s[p])) && s[p] != ')') do p += 1
      code := new(Code)
      code.loc = start
      code.kind = .IDENTIFIER
      code.as_atom = s[start:p]
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, code)
    }

    peek := p
    for peek < len(s) && s[peek] != '\n' && s[peek] != ';' && unicode.is_space(rune(s[peek])) do peek += 1
    if peek >= len(s) || s[peek] == '\n' || s[peek] == ';' {
      start_of_next_non_blank_line := peek
      for {
        for peek < len(s) && unicode.is_space(rune(s[peek])) {
          if s[peek] == '\n' do start_of_next_non_blank_line = peek + 1
          peek += 1
        }
        if peek < len(s) && s[peek] == ';' {
          for peek < len(s) && s[peek] != '\n' do peek += 1
          continue
        }
        break
      }
      next_indent := peek - start_of_next_non_blank_line
      for len(level_stack) > 0 && level_stack[len(level_stack) - 1] && implicit_indent_stack[len(implicit_indent_stack) - 1] >= next_indent {
        pop(&level_stack)
        popped := pop(&stack)
        append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, popped)
        pop(&implicit_indent_stack)
      }
    }

    if len(level_stack) == 0 do break
  }
  if len(level_stack) != 0 do fmt.panicf("%s:=%d unmatched (.\n", filename, p)
  assert(len(stack) <= 1)
  return pop(&stack) if len(stack) > 0 else nil, p
}

print_code :: proc(code: ^Code) {
  switch code.kind {
    case .IDENTIFIER: fallthrough
    case .KEYWORD: fallthrough
    case .INTEGER: fallthrough
    case .FLOAT: fallthrough
    case .STRING: fmt.printf("%s", code.as_atom)
    case .ARRAY:
      fmt.printf("(")
      for child, index in code.as_array {
        print_code(child)
        if index != len(code.as_array) - 1 do fmt.print(" ")
      }
      fmt.printf(")")
  }
}

main :: proc() {
  if len(os.args) == 1 do fmt.panicf("no file given. usage: odin run . -- your_file.z\n")
  src, success := os.read_entire_file(os.args[1])
  if !success do fmt.panicf("file '%s' wasn't found.\n", os.args[1])
  pos := 0
  for {
    code, next_pos := parse_code(string(src), pos, os.args[1])
    if code == nil do break
    pos = next_pos
    print_code(code)
    fmt.println()
  }
}
