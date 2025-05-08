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
  loc: int,
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
      exp.loc = start
      exp.kind = .ARRAY
      append(&stack, exp)
    }

    if s[p] == '(' {
      p += 1
      append(&level_stack, false)
      exp := new(Exp)
      exp.loc = start
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
      exp.loc = start
      exp.kind = .INTEGER
      exp.as_atom = s[start:p]
      append(&stack[len(stack) - 1].as_array if len(stack) > 0 else &stack, exp)
    } else if s[p] == '\'' {
      p += 1
      exp := new(Exp);
      exp.loc = start
      exp.kind = .ARRAY;
      identifier := new(Exp);
      identifier.loc = start
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
      exp.loc = start
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

Type_Kind :: enum {
  TYPE,
  CODE,
  VOID,
  BOOL,
  NORETURN,
  COMPTIME_INTEGER,
  COMPTIME_FLOAT,
  INTEGER,
  FLOAT,
  OPTIONAL,
  POINTER,
  ARRAY,
  STRUCT,
  UNION,
  ENUM,
  ENUM_FLAGS,
  PROCEDURE,
  TYPEOF_NULL,
}

Type_Integer :: struct {
  bits: u8,
  signed: bool,
}

Type_Float :: struct {
  bits: u8,
}

Type_Optional :: struct {
  child: ^Type,
}

Type_Pointer_Kind :: enum {
  SINGLE,
  MANY,
  SLICE,
}

Type_Pointer :: struct {
  kind: Type_Pointer_Kind,
  child: ^Type,
}

Type_Array_Kind :: enum {
  STATIC,
  DYNAMIC,
}

Type_Array_Static :: struct {
  count: u32,
}

Type_Array :: struct {
  kind: Type_Array_Kind,
  child: ^Type,
  using data: struct #raw_union {
    as_static: Type_Array_Static,
  },
}

Type_Struct_Field :: struct {
  type: ^Type,
  alignment: u8,
}

Type_Struct :: struct {
  field_names: []string,
  field_types: []Type_Struct_Field,
  field_offsets: []u32,
  alignment: u8,
}

Type_Union :: struct {
  field_names: []string,
  field_types: []Type_Struct_Field,
  alignment: u8,
  tag_type: ^Type,
}

Type_Enum :: struct {
  field_names: []string,
  field_values: []u32,
  tag_type: ^Type,
}

Type_Enum_Flags :: struct {
  field_names: []string,
  field_values: []u32,
  tag_type: ^Type,
}

Type_Procedure_Calling_Convention :: enum {
  DEFAULT,
  Z,
  C,
}

Type_Procedure :: struct {
  parameter_names: []string,
  parameter_types: []^Type,
  return_type: ^Type,
  callconv: Type_Procedure_Calling_Convention,
}

Type :: struct {
  kind: Type_Kind,
  using data: struct #raw_union {
    as_integer: Type_Integer,
    as_optional: Type_Optional,
    as_pointer: Type_Pointer,
    as_array: Type_Array,
    as_struct: Type_Struct,
    as_union: Type_Union,
    as_enum: Type_Enum,
    as_enum_flags: Type_Enum_Flags,
    as_procedure: Type_Procedure,
  },
}

type_code: ^Type
type_void: ^Type
type_comptime_int: ^Type
type_comptime_float: ^Type
type_u8: ^Type
type_slice_u8: ^Type

print_type :: proc(type: ^Type) {
  // switch type.kind {
  // }
  fmt.println("%s", type.data)
}

Value_Kind :: enum {
  NONE,
  EXP,
  TYPE,
  PROCEDURE,
}

Value :: struct {
  type: ^Type,
  kind: Value_Kind,
  using data: struct #raw_union {
    as_exp: ^Exp,
    as_type: ^Type,
    as_procedure: proc "c" (..^Value) -> ^Value,
  },
}

value_void: ^Value

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
  if env.parent != nil do return env_find(env.parent, key)
  return nil
}

eval_exp :: proc(x: ^Exp, env: ^Env, filename: string) -> ^Value {
  switch x.kind {
    case .IDENTIFIER:
      value := env_find(env, x.as_atom)
      if value == nil do fmt.panicf("%s:=%d I couldn't find %s in this environment.\n", filename, x.loc, x.as_atom)
      return value.value
    case .KEYWORD:
      value := new(Value)
      value.type = type_code
      value.kind = .EXP
      value.as_exp = x
      return value
    case .INTEGER:
      value := new(Value)
      value.type = type_comptime_int
      value.kind = .EXP
      value.as_exp = x
      return value
    case .FLOAT:
      value := new(Value)
      value.type = type_comptime_float
      value.kind = .EXP
      value.as_exp = x
      return value
    case .STRING:
      value := new(Value)
      value.type = type_slice_u8
      value.kind = .EXP
      value.as_exp = x
      return value
    case .ARRAY:
      op_exp, arg_exps := x.as_array[0], x.as_array[1:]
      if op_exp.kind == .IDENTIFIER {
        if op_exp.as_atom == "$define" {
          if len(arg_exps) != 2 do fmt.panicf("%s:=%d $define expects two arguments (for now).\n", filename, op_exp.loc)
          name_exp, value_exp := arg_exps[0], arg_exps[1]
          name := eval_exp(name_exp, env, filename)
          if name.kind != .EXP || name.as_exp.kind != .IDENTIFIER do fmt.panicf("%s:=%d I expected an identifier as the first argument to $define. Maybe you forgot to quote it?\n", filename, name_exp.loc)
          if name.as_exp.as_atom in env.table do fmt.panicf("%s:=%d There's already a $define in this environment named %s.\n", filename, name_exp.loc, name.as_exp.as_atom)
          env.table[name.as_exp.as_atom] = {constant = true, public = false, value = eval_exp(value_exp, env, filename)}
          return value_void
        }
        if op_exp.as_atom == "$codeof" {
          if len(arg_exps) != 1 do fmt.panicf("%s:=%d $codeof expects one argument.\n", filename, op_exp.loc)
          value := new(Value)
          value.type = type_code
          value.kind = .EXP
          value.as_exp = arg_exps[0]
          return value
        }
        if op_exp.as_atom == "$insert" {
          if len(arg_exps) != 1 do fmt.panicf("%s:=%d $insert expects one argument (for now).\n", filename, op_exp.loc)
          arg := eval_exp(arg_exps[0], env, filename)
          if arg.kind != .EXP || arg.type.kind != .CODE do fmt.panicf("%s:=%d I expected code as the first parameter but received %s instead.\n", filename, op_exp.loc, arg.kind)
          return eval_exp(arg.as_exp, env, filename)
        }
      }
      proc_ := eval_exp(op_exp, env, filename)
      if proc_.kind != .PROCEDURE do fmt.panicf("%s:=%d I expected a procedure as the first parameter but received %s instead.\n", filename, op_exp.loc, proc_.type)
      args: [dynamic]^Value
      defer delete(args)
      for arg_exp in arg_exps do append(&args, eval_exp(arg_exp, env, filename))
      return proc_.as_procedure(..args[:])
  }
  assert(false, "How did we get here? (compiler bug)")
  return value_void
}

print_value :: proc(value: ^Value) {
  switch value.kind {
    case .NONE:
    case .EXP: print_exp(value.as_exp)
    case .TYPE: print_type(value.as_type)
    case .PROCEDURE: fmt.panicf("Unimplemented\n")
  }
}

main :: proc() {
  if len(os.args) == 0 do fmt.panicf("I expected there to be at least one argument.\n")
  if len(os.args) == 1 do fmt.panicf("Please provide me a file to compile, like this: %s your_main_file.z", filepath.base(os.args[0]))

  filename := os.args[1]
  src, success := os.read_entire_file(filename)
  if !success do fmt.panicf("I failed to read '%s' from your drive. Maybe you need to quote the entire path?", filename)

  type_code = &{kind = .CODE}
  type_void = &{kind = .VOID}
  type_comptime_int = &{kind = .COMPTIME_INTEGER}
  type_comptime_float = &{kind = .COMPTIME_FLOAT}
  type_u8 = &{kind = .INTEGER, as_integer = {bits = 8, signed = false}}
  type_slice_u8 = &{kind = .POINTER, as_pointer = {kind = .SLICE, child = type_u8}}

  value_void = &{type = type_void}

  env: Env
  pos := 0
  for {
    exp, next_pos := parse_exp(string(src), pos, filename)
    if exp == nil do break
    pos = next_pos
    // print_exp(exp, show_kinds=false)
    // fmt.printf("\n")
    result := eval_exp(exp, &env, filename)
    if result != value_void {
      fmt.printf("=> ")
      print_value(result)
      fmt.printf("\n")
    }
  }

  fmt.printf("=====ENVIRONMENT=====\n")
  for key, value in env.table {
    fmt.printf("%s: ", key)
    print_value(value.value)
    fmt.printf("\n")
  }
}
