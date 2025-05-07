#import "Basic";
#import "Compiler";
#import "File";
#import "Hash_Table";
#import "String";


Exp :: struct {
  Kind :: enum {
    SYMBOL :: 0;
    INTEGER :: 1;
    FLOAT :: 2;
    STRING :: 3;
    LIST :: 4;
  }

  kind: Kind;
  loc: int;
  using data: union {
    as_atom: string;
    as_list: [..]*Exp;
  };
}

make_list :: (loc: int) -> *Exp {
  exp := New(Exp);
  exp.kind = .LIST;
  exp.loc = loc;
  return exp;
}

make_string :: (s: string, start: int, p: int) -> *Exp {
  exp := New(Exp);
  exp.kind = .STRING;
  exp.loc = start;
  exp.as_atom = string.{count = p - start - 2, data = s.data + start + 1};
  return exp;
}

make_integer :: (s: string, start: int, p: int) -> *Exp {
  exp := New(Exp);
  exp.kind = .INTEGER;
  exp.loc = start;
  exp.as_atom = string.{count = p - start, data = s.data + start};
  return exp;
}

make_symbol :: (value: string, start: int) -> *Exp {
  exp := New(Exp);
  exp.kind = .SYMBOL;
  exp.loc = start;
  exp.as_atom = value;
  return exp;
}

parse_exp :: (s: string, p: int, first_exp_of_line := true) -> (*Exp, int) {
  level := 0;
  stack: [..]*Exp;
  defer array_free(stack);
  implicit_parentheses := false;
  while true {
    newline_was_skipped := false;
    while true {
      while p < s.count && is_space(s[p]) {
        if s[p] == #char "\n" newline_was_skipped = true;
        p += 1;
      }
      if p < s.count && s[p] == #char ";" {
        while p < s.count && s[p] != #char "\n" p += 1;
        continue;
      }
      break;
    }
    start := p;
    if implicit_parentheses && level == 1 && (newline_was_skipped || p >= s.count) {
      assert(level > 0);
      level -= 1;
      popped := pop(*stack);
      assert(stack.count == 0 || stack[stack.count - 1].kind == .LIST);
      array_add(ifx stack.count > 0 then *stack[stack.count - 1].as_list else *stack, popped);
    } else if p >= s.count {
      break;
    } else if first_exp_of_line && s[p] != #char "(" {
      implicit_parentheses = true;
      level += 1;
      array_add(*stack, make_list(p));
    } else if s[p] == #char "(" {
      p += 1;
      level += 1;
      array_add(*stack, make_list(p));
    } else if s[p] == #char ")" {
      p += 1;
      assert(level > 0 && !(level == 0 && implicit_parentheses));
      level -= 1;
      popped := pop(*stack);
      assert(stack.count == 0 || stack[stack.count - 1].kind == .LIST);
      array_add(ifx stack.count > 0 then *stack[stack.count - 1].as_list else *stack, popped);
    } else if s[p] == #char "\"" {
      p += 1;
      while p < s.count && (s[p - 1] == #char "\\" || s[p] != #char "\"") p += 1;
      assert(p < s.count && s[p] == #char "\"");
      p += 1;
      assert(stack.count == 0 || stack[stack.count - 1].kind == .LIST);
      array_add(ifx stack.count > 0 then *stack[stack.count - 1].as_list else *stack, make_string(s, start, p));
    } else if is_digit(s[p]) {
      while p < s.count && is_digit(s[p]) p += 1;
      assert(stack.count == 0 || stack[stack.count - 1].kind == .LIST);
      array_add(ifx stack.count > 0 then *stack[stack.count - 1].as_list else *stack, make_integer(s, start, p));
    } else if s[p] == #char "'" {
      p += 1;
      list := make_list(p);
      array_add(*list.as_list, make_symbol("$codeof", start));
      exp, next_pos := parse_exp(s, p, first_exp_of_line = false);
      p = next_pos;
      array_add(*list.as_list, exp);
      assert(stack.count == 0 || stack[stack.count - 1].kind == .LIST);
      array_add(ifx stack.count > 0 then *stack[stack.count - 1].as_list else *stack, list);
    } else {
      while p < s.count && !is_space(s[p]) && s[p] != #char ")" p += 1;
      assert(stack.count == 0 || stack[stack.count - 1].kind == .LIST);
      array_add(ifx stack.count > 0 then *stack[stack.count - 1].as_list else *stack, make_symbol(string.{count = p - start, data = s.data + start}, start));
    }
    first_exp_of_line = false;
    if level == 0 break;
  }
  assert(level == 0);
  assert(stack.count <= 1);
  return ifx stack.count > 0 pop(*stack), p;
}

print_exp :: (x: *Exp, s: string, level := 0, show_kinds := false) {
  if show_kinds print("%[", x.kind);
  if #complete x.kind == {
    case .SYMBOL; #through;
    case .INTEGER; #through;
    case .FLOAT;
      print("%", x.as_atom);
    case .STRING;
      print("\"%\"", x.as_atom);
    case .LIST;
      print("(");
      for x.as_list {
        print_exp(it, s, level + 1, show_kinds);
        if it_index != x.as_list.count - 1 print(" ");
      }
      print(")");
  }
  if show_kinds print("]");
  if level == 0 print("\n");
}

Typespec :: struct {
  Kind :: enum {
    TYPE :: 0;
    CODE :: 1;
    VOID :: 2;
    BOOL :: 3;
    NORETURN :: 4;
    INTEGER :: 5;
    FLOAT :: 6;
    COMPTIME_INTEGER :: 7;
    COMPTIME_FLOAT :: 8;
    POINTER :: 9;
    ARRAY :: 10;
    STRUCT :: 11;
    UNION :: 12;
    ENUM :: 13;
    ENUM_FLAGS :: 14;
    ENUM_LITERAL :: 15;
    STRUCT_LITERAL :: 16;
    NULL :: 17;
  }

  kind: Kind;
  using data: union {
    as_pointer: struct {
      kind: enum {
        SINGLE;
        MANY;
        SLICE;
      };
      child: *Typespec;
    };
    as_integer: struct {
      bits: u8;
      signed: bool;
    };
  };
}

type_code: *Typespec;
type_comptime_int: *Typespec;
type_u8: *Typespec;
type_slice_u8: *Typespec;

Value :: struct {
  Kind :: enum {
    EXP :: 0;
    TYPE :: 1;
    PROCEDURE :: 2;
    ENUM_LITERAL :: 3;
  }

  type: *Typespec;
  kind: Kind;
  using data: union {
    as_exp: *Exp;
    as_type: *Typespec;
    as_procedure: (args: [..]*Value) -> *Value;
    as_enum_literal: string;
  };
}

Env :: struct {
  parent: *Env;
  using table: Table(string, Value);
}

env_find :: (env: *Env, symbol: string) -> *Value {
  value := table_find_pointer(*env.table, symbol);
  if value return value;
  if env.parent return env_find(env.parent, symbol);
  return null;
}

eval_exp :: (x: *Exp, env: *Env) -> *Value {
  if #complete x.kind == {
    case .SYMBOL;
      if x.as_atom[0] == #char "." {
        value := New(Value);
        value.kind = .ENUM_LITERAL;
        value.as_enum_literal = string.{count = x.as_atom.count - 1, data = x.as_atom.data + 1};
        return value;
      }
      value := env_find(env, x.as_atom);
      assert(value != null, "% is not in env", x.as_atom);
      return value;
    case .INTEGER;
      value := New(Value);
      value.type = type_comptime_int;
      value.kind = .EXP;
      value.as_exp = x;
      return value;
    case .FLOAT;
      assert(false);
      return null;
    case .STRING;
      value := New(Value);
      value.type = type_slice_u8;
      value.kind = .EXP;
      value.as_exp = x;
      return value;
    case .LIST;
      op, args := x.as_list[0], array_view(x.as_list, 1);
      assert(op.kind == .SYMBOL);
      if op.as_atom == "$define" {
        assert(args.count == 2);
        name_exp, value_exp := args[0], args[1];
        name := eval_exp(name_exp, env);
        assert(name.kind == .EXP && name.as_exp.kind == .SYMBOL);
        assert(!table_find_pointer(*env.table, name.as_exp.as_atom));
        table_add(*env.table, name.as_exp.as_atom, eval_exp(value_exp, env));
        return eval_exp(parse_exp("($cast ($type .VOID) 0)", 0), env);
      } else if op.as_atom == "$codeof" {
        assert(args.count == 1);
        exp := args[0];
        value := New(Value);
        value.type = type_code;
        value.kind = .EXP;
        value.as_exp = exp;
        return value;
      } else if op.as_atom == "$cast" {
        assert(args.count == 2);
        type_exp, value_exp := args[0], args[1];
        type := eval_exp(type_exp, env);
        assert(type.kind == .TYPE);
        value := eval_exp(value_exp, env);
        // assert(); // TODO(dfra): make sure these types are compatible
        value.type = type.as_type;
        return value;
      } else if op.as_atom == "$type" {
        assert(args.count <= 2);
        kind_exp := args[0];
        kind := eval_exp(kind_exp, env);
        assert(kind.kind == .ENUM_LITERAL);
        kind_literal := kind.as_enum_literal;
        ts := New(Typespec);
        names, values := enum_names(Typespec.Kind), enum_values_as_s64(Typespec.Kind);
        kind_kind_kind := Typespec.Kind.TYPE;
        for names if it == kind_literal kind_kind_kind = cast(Typespec.Kind) values[it_index];
        ts.* = .{kind = kind_kind_kind};
        value := New(Value);
        value.kind = .TYPE;
        value.as_type = ts;
        return value;
      } else {
        proc := eval_exp(op, env);
        assert(proc.kind == .PROCEDURE);
        pargs: [..]*Value;
        for args array_add(*pargs, eval_exp(it, env));
        return proc.as_procedure(pargs);
      }
  }
}

print_value :: (value: *Value, s: string) {
  if #complete value.kind == {
    case .EXP; print_exp(value.as_exp, s);
    case .TYPE;
      print("($cast ($type .TYPE) %)", value.as_type);
    case .PROCEDURE;
      print("procedure");
    case .ENUM_LITERAL;
      print(".%", value.as_enum_literal);
  }
}

args: []string;

do_compile :: () {
  if args.count == 1 {
    print("Grrr! I wanted you to give me a file to compile! Like this: jai zc.jai - your_main_file.z");
    exit(1);
  }

  src, success := read_entire_file(args[1]);
  if !success {
    print("I failed to find '%' on your drive. Maybe you need to quote the entire path?\n", args[1]);
    exit(1);
  }

  type_code = *(Typespec.{kind = .CODE});
  type_comptime_int = *(Typespec.{kind = .COMPTIME_INTEGER});
  type_u8 = *(Typespec.{kind = .INTEGER, as_integer = .{bits = 8, signed = false}});
  type_slice_u8 = *(Typespec.{kind = .POINTER, as_pointer = .{kind = .SLICE, child = type_u8}});

  default_env: Env;

  env: Env;
  env.parent = *default_env;

  // print("%", src);
  pos := 0;
  while true {
    exp, next_pos := parse_exp(src, pos);
    if !exp break;
    pos = next_pos;
    // print_exp(exp, src, show_kinds = false);
    result := eval_exp(exp, *env);
    for * env.table {
      print("%: ", it_index);
      print_value(it, src);
      print("\n");
    }
  }
}

#run {
  set_build_options_dc(.{do_output=false});
  temp_args: [..]string;
  array_add(*temp_args, "jai");
  array_add(*temp_args, ..get_build_options().compile_time_command_line);
  args = temp_args;
  do_compile();
}
