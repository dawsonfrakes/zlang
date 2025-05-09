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

Type_Kind :: enum {
  TYPE,
  CODE,
  VOID,
  NORETURN,
  BOOL,
  COMPTIME_INTEGER,
  COMPTIME_FLOAT,
  INTEGER,
  FLOAT,
  POINTER,
  ARRAY,
  STRUCT,
  UNION,
  // ENUM, // NOTE(dfra): probably better to just handle enums (and enum_flags) in userspace.
  PROCEDURE,
  NULL,
}

Type_Integer :: struct {
  bits: u8,
  signed: bool,
}

Type_Pointer_Kind :: enum {
  SINGLE,
  MANY,
  SLICE,
}

Type_Pointer :: struct {
  kind: Type_Pointer_Kind,
  child: ^Type,
  sentinel: rawptr,
}

Type_Array_Kind :: enum {
  STATIC,
  DYNAMIC,
}

Type_Array :: struct {
  kind: Type_Array_Kind,
  child: ^Type,
  count: uint,
  sentinel: rawptr,
}

Type_Struct :: struct {
  field_names: []string,
  field_types: []^Type,
}

Type_Union :: struct {
  field_names: []string,
  field_types: []^Type,
  tag: ^Type,
}

Type_Procedure_Calling_Convention :: enum {
  DEFAULT,
  Z,
  C,
}

Type_Procedure :: struct {
  parameter_types: []^Type,
  return_type: ^Type,
  callconv: Type_Procedure_Calling_Convention,
}

Type :: struct {
  kind: Type_Kind,
  using data: struct #raw_union {
    as_integer: Type_Integer,
    as_pointer: Type_Pointer,
    as_array: Type_Array,
    as_struct: Type_Struct,
    as_union: Type_Union,
    as_procedure: Type_Procedure,
  },
}

Value :: struct {
  type: ^Type,
  using data: struct #raw_union {
    as_code: ^Code,
    as_type: ^Type,
    as_integer: int,
    as_float: f64,
    as_string: string,
    as_procedure: proc(..^Value) -> ^Value,
  },
}

Env_Entry :: struct {
  constant: bool,
  public: bool,
  value: ^Value,
}

Env :: struct {
  parent: ^Env,
  table: map[string]Env_Entry,
}

env_find :: proc(env: ^Env, key: string) -> ^Env_Entry {
  if key in env.table do return &env.table[key]
  if env.parent != nil do return env_find(env, key)
  return nil
}

type_code: ^Type
type_bool: ^Type
type_comptime_int: ^Type
type_comptime_float: ^Type
type_u8: ^Type
type_slice_u8: ^Type
type_procedures: map[string]Type
value_keywords: map[string]Value
value_void: ^Value

eval_code :: proc(code: ^Code, env: ^Env, filename := "") -> ^Value {
  switch code.kind {
    case .IDENTIFIER:
      value := env_find(env, code.as_atom)
      if value == nil do fmt.panicf("%s:=%d Failed to find '%s' in the environment.\n", filename, code.loc, code.as_atom)
      return value.value
    case .KEYWORD:
      if !(code.as_atom in value_keywords) do value_keywords[code.as_atom] = {type = type_code, as_code = code}
      return &value_keywords[code.as_atom]
    case .INTEGER:
      value := new(Value)
      value.type = type_comptime_int
      value.as_integer = strconv.atoi(code.as_atom)
      return value
    case .FLOAT:
      value := new(Value)
      value.type = type_comptime_float
      value.as_float = strconv.atof(code.as_atom)
      return value
    case .STRING:
      value := new(Value)
      value.type = type_slice_u8
      value.as_string = code.as_atom
      return value
    case .ARRAY:
      op_code, arg_codes := code.as_array[0], code.as_array[1:]
      if op_code.kind == .IDENTIFIER {
        switch op_code.as_atom {
          case "$constant":
            if len(arg_codes) != 2 do fmt.panicf("%s:=%d $constant expects exactly two arguments (for now).\n", filename, op_code.loc)
            name_code, value_code := arg_codes[0], arg_codes[1]
            name := eval_code(name_code, env, filename)
            if name.type.kind != .CODE || name.as_code.kind != .IDENTIFIER do fmt.panicf("%s:=%d $constant expects argument one to be a valid identifier.\n", filename, name_code.loc)
            if name.as_code.as_atom in env.table do fmt.panicf("%s:=%d Attempted to redefine '%s' in the same scope.\n", filename, name.as_code.loc, name.as_code.as_atom)
            env.table[name.as_code.as_atom] = {constant = true, public = false, value = eval_code(value_code, env, filename)}
            return value_void
          case "$proc":
            name_code, parameter_type_codes, return_type_code, rest := arg_codes[0], arg_codes[1], arg_codes[2], arg_codes[3:]
            name := eval_code(name_code, env, filename)
            if name.type.kind != .CODE || name.as_code.kind != .IDENTIFIER do fmt.panicf("%s:=%d $proc expects argument one to be a valid identifier.\n", filename, name_code.loc)
            if name.as_code.as_atom in env.table do fmt.panicf("%s:=%d Attempted to redefine '%s' in the same scope.\n", filename, name.as_code.loc, name.as_code.as_atom)
            value := new(Value)
            if !("()" in type_procedures) do type_procedures["()"] = {kind = .PROCEDURE}
            value.type = &type_procedures["()"]
            value.as_procedure = proc(..^Value) -> ^Value { return nil }
            env.table[name.as_code.as_atom] = {constant = true, public = false, value = value}
            return value_void
          case "$code-of":
            if len(arg_codes) != 1 do fmt.panicf("%s:=%d $code-of expects exactly one argument.\n", filename, op_code.loc)
            value := new(Value)
            value.type = type_code
            value.as_code = arg_codes[0]
            return value
          case "$operator":
            if len(arg_codes) < 1 do fmt.panicf("%s:=%d $operator expects at least one argument (the operator).\n", filename, op_code.loc)
            operator := eval_code(arg_codes[0], env, filename)
            if operator.type.kind != .CODE || operator.as_code.kind != .IDENTIFIER do fmt.panicf("%s:=%d $operator expects argument one to be a valid identifier.\n", filename, arg_codes[0].loc)
            switch operator.as_code.as_atom {
              case "*":
                value := new(Value)
                value.type = type_comptime_int
                value.as_integer = 1
                for arg_code in arg_codes[1:] {
                  arg := eval_code(arg_code, env, filename)
                  if arg.type != type_comptime_int do fmt.panicf("%s:=%d * only supports comptime-int multiplication (for now).\n", filename, op_code.loc)
                  value.as_integer *= arg.as_integer
                }
                return value
              case:
                fmt.panicf("%s:=%d $operator doesn't support op '%' (for now).", filename, arg_codes[0].loc, operator.as_code.as_atom)
            }
        }
      }
      proc_ := eval_code(op_code, env, filename)
      if proc_.type.kind != .PROCEDURE do fmt.panicf("%s:=%d You tried to call a non-procedure.\n", filename, op_code.loc)
      pargs: [dynamic]^Value
      defer delete(pargs)
      for arg_code in arg_codes do append(&pargs, eval_code(arg_code, env, filename))
      return proc_.as_procedure(..pargs[:])
  }
  assert(false, "How did we get here? (compiler bug)")
  return nil
}

print_value :: proc(value: ^Value) {
  #partial switch value.type.kind {
    case .CODE:
      print_code(value.as_code)
    case .COMPTIME_INTEGER:
      fmt.printf("%d", value.as_integer)
    case .PROCEDURE:
      fmt.printf("proc")
    case:
      fmt.print("Unimplemented")
  }
}

main :: proc() {
  type_code = &{kind = .CODE}
  type_bool = &{kind = .BOOL}
  type_comptime_int = &{kind = .COMPTIME_INTEGER}
  type_comptime_float = &{kind = .COMPTIME_FLOAT}
  type_u8 = &{kind = .INTEGER, as_integer = {bits = 8, signed = false}}
  type_slice_u8 = &{kind = .POINTER, as_pointer = {kind = .SLICE, child = type_u8}}

  value_void = &{type = type_bool}

  if len(os.args) == 1 do fmt.panicf("no file given. usage: odin run . -- your_file.z\n")

  src, success := os.read_entire_file(os.args[1])
  if !success do fmt.panicf("file '%s' wasn't found.\n", os.args[1])
  pos := 0
  env: Env
  for {
    code, next_pos := parse_code(string(src), pos, os.args[1])
    if code == nil do break
    pos = next_pos
    // print_code(code)
    // fmt.println()
    result := eval_code(code, &env, os.args[1])
    if result != value_void {
      print_value(result)
      fmt.println()
    }
  }

  fmt.println("=====ENVIRONMENT=====")
  for key, value in env.table {
    fmt.printf("%s: ", key)
    print_value(env.table[key].value)
    fmt.println()
  }
}
