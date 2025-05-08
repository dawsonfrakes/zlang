#!/usr/bin/env python3

from dataclasses import dataclass
from enum import IntEnum
import operator as op

class Array(list): pass
class Identifier(str): pass
class Keyword(str): pass
class Integer(int): pass
class Float(float): pass
class String(str): pass
Code_Data = Identifier | Keyword | Integer | Float | String | Array
@dataclass
class Code:
  loc: int
  data: Code_Data

def parse_code(s, p):
  level_stack = []
  stack = []
  while True:
    start = p
    newline_was_skipped = False
    while True:
      while p < len(s) and s[p].isspace():
        if s[p] == '\n': newline_was_skipped = True
        p += 1
      if p < len(s) and s[p] == ';':
        while p < len(s) and s[p] != '\n': p += 1
        continue
      break
    first_exp_of_line = newline_was_skipped or start == 0
    if p >= len(s): break

    if first_exp_of_line and s[p] != '(':
      level_stack.append(True)
      stack.append(Code(p, Array()))

    start = p
    if s[p] == '(':
      p += 1
      level_stack.append(False)
      stack.append(Code(p, Array()))
    elif s[p] == ')':
      p += 1

      while len(level_stack) > 0 and level_stack[-1]: level_stack.pop()
      if len(level_stack) <= 0: print("Missing (."); exit(1)

      level_stack.pop()
      popped = stack.pop()
      (stack[-1].data if len(stack) > 0 else stack).append(popped)
    elif s[p].isdigit():
      while p < len(s) and s[p].isdigit(): p += 1
      (stack[-1].data if len(stack) > 0 else stack).append(Code(start, Integer(s[start:p])))
    elif s[p] == "'":
      p += 1
      code, next_pos = parse_code(s, p)
      assert code is not None
      p = next_pos
      (stack[-1].data if len(stack) > 0 else stack).append(Code(start, Array([Code(start, Identifier("$codeof")), code])))
    else:
      while p < len(s) and (not s[p].isspace() and s[p] != ')'): p += 1
      (stack[-1].data if len(stack) > 0 else stack).append(Code(start, Identifier(s[start:p])))

    peek = p
    while peek < len(s) and s[peek] != '\n' and s[peek] != ';' and s[peek].isspace(): peek += 1
    if peek >= len(s) or s[peek] == '\n' or s[peek] == ';':
      while len(level_stack) > 0 and level_stack[-1]: level_stack.pop()

    if len(level_stack) == 0: break
  if len(level_stack) != 0: print("Missing )."); exit(1)
  assert len(stack) <= 1
  return stack.pop() if len(stack) > 0 else None, p

def print_code(code, show_kinds=False):
  if show_kinds: print(code.__class__.__name__ + "[", end="")
  if isinstance(code, Identifier | Integer): print(code, end="")
  elif isinstance(code, Array):
    print("(", end="")
    for c in code: print_code(c, show_kinds)
    print(")", end="")
  else: raise NotImplementedError(type(code))
  if show_kinds: print("]", end="")

class Type: pass
class Type_Procedure_Calling_Convention(IntEnum):
  DEFAULT = 0
  Z = 1
  C = 2
@dataclass
class Type_Procedure(Type):
  parameter_types: list[Type]
  parameter_names: list[str]
  return_type: Type
  callconv: Type_Procedure_Calling_Convention

type_type = Type()
type_code = Type()
type_void = Type()
type_bool = Type()
type_comptime_int = Type()

def print_type(type_):
  if type_ == type_type: print("($type 'TYPE)", end="")
  elif type_ == type_code: print("($type 'CODE)", end="")
  elif type_ == type_void: print("($type 'VOID)", end="")
  elif type_ == type_bool: print("($type 'BOOL)", end="")
  elif type_ == type_comptime_int: print("($type 'COMPTIME_INTEGER)", end="")
  else: raise NotImplementedError(type(type_))

@dataclass
class Value:
  type: Type
  data: Code_Data

value_true = Value(type_bool, None)
value_false = Value(type_bool, None)
value_void = Value(type_void, None)

@dataclass
class Env_Entry:
  constant: bool
  public: bool
  value: Value

class Env:
  def __init__(self):
    self.parent = None
    self.data = {}
  def find(self, key):
    if key in self.data: return self.data[key]
    if self.parent is not None: return self.parent.find(key)
    return None

def is_truthy(value):
  if value.type == type_bool: return value != value_false
  elif value.type == type_comptime_int: return value.data != 0 # TODO: decide if this should be a thing. (probably not)
  else: raise NotImplementedError(value.type)

def is_equal(a, b):
  if a.type == type_comptime_int and b.type == type_comptime_int: return a.data == b.data
  raise NotImplementedError(type(a), type(b))

def eval_code(code, env):
  assert isinstance(code, Code)
  if not isinstance(code.data, Array):
    if isinstance(code.data, Identifier):
      entry = env.find(code.data)
      if entry is None: print(f"Identifier '{code.data}' not found in environment."); exit(1)
      return entry.value
    elif isinstance(code.data, Integer):
      value = Value(type_comptime_int, code.data)
      return value
    else: raise NotImplementedError(type(code.data))
  op_code, *arg_codes = code.data
  if op_code.data == Identifier("$define"):
    name_code, value_code = arg_codes
    name = eval_code(name_code, env)
    assert name.type == type_code and isinstance(name.data, Identifier)
    assert name.data not in env.data
    env.data[name.data] = Env_Entry(constant=True, public=False, value=eval_code(value_code, env))
    return value_void
  elif op_code.data == Identifier("$codeof"):
    if len(arg_codes) != 1: print("$codeof expects one argument."); exit(1)
    return Value(type_code, arg_codes[0].data)
  elif op_code.data == Identifier("$insert"):
    if len(arg_codes) != 1: print("$insert expects one argument (for now)."); exit(1)
    value = eval_code(arg_codes[0], env)
    if value.type != type_code: print("$insert expects argument one to be of type ($type 'CODE)."); exit(1)
    return eval_code(Code(op_code.loc, value.data), env)
  elif op_code.data == Identifier("$if"):
    test, conseq, *alt = arg_codes
    assert len(alt) <= 1
    return eval_code(conseq, env) if is_truthy(eval_code(test, env)) else (eval_code(alt[0], env) if len(alt) != 0 else value_void)
  elif op_code.data == Identifier("$operator"):
    operator_code, *rest_codes = arg_codes
    operator = eval_code(operator_code, env)
    assert operator.type == type_code and isinstance(operator.data, Identifier)
    if operator.data == Identifier("=="):
      result = True
      arg1 = eval_code(rest_codes[0], env) if len(rest_codes) != 0 else None
      for arg_code in rest_codes[1:]:
        arg2 = eval_code(arg_code, env)
        result = result and is_equal(arg1, arg2)
      return value_true if result else value_false
    elif operator.data == Identifier("*"):
      result = 1
      if len(rest_codes) > 0:
        arg1 = eval_code(rest_codes[0], env)
        assert arg1.type == type_comptime_int
        result = arg1.data
      for arg_code in rest_codes[1:]:
        arg2 = eval_code(arg_code, env)
        assert arg2.type == type_comptime_int
        result *= arg2.data
      return Value(type_comptime_int, Integer(result))
    raise NotImplementedError()
  else:
    proc = eval_code(op_code, env)
    if not isinstance(proc.type, Type_Procedure):
      print(f"Attempted to call non-procedure of type '", end="")
      print_type(proc.type)
      print("'.")
      exit(1)
    pargs = [eval_code(arg_code, env) for arg_code in arg_codes]
    return proc(*pargs)

def print_value(value):
  if isinstance(value.data, Code_Data): print_code(value.data)
  elif value == value_true: print("($cast ($type 'BOOL) 1)", end="")
  elif value == value_false: print("($cast ($type 'BOOL) 0)", end="")
  else: raise NotImplementedError(type(value.data))

import sys
if len(sys.argv) == 1:
  env = Env()
  while True:
    i = input("> ")
    pos = 0
    if i in ["exit", "quit"] : break
    while True:
      code, next_pos = parse_code(i, pos)
      if code is None: break
      pos = next_pos
      result = eval_code(code, env)
      print("=> ", end="")
      print_value(result)
      print("")
else:
  with open(sys.argv[1]) as f: src = f.read()
  env = Env()
  pos = 0
  while True:
    code, next_pos = parse_code(src, pos)
    if code is None: break
    pos = next_pos
    eval_code(code, env)

  print("=====ENVIRONMENT=====")
  for key in env.data:
    print(key + ': ', end="")
    print_value(env.data[key].value)
    print("")
