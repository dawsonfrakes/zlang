from dataclasses import dataclass

class Symbol(str):
  def __repr__(self): return self
class Keyword(str):
  def __repr__(self): return '.' + self
class EnumLiteral(str):
  def __repr__(self): return '#' + self
class String(str):
  def __repr__(self): return '"' + self + '"'
class Integer(int): pass
class Float(float): pass
class List(list):
  def __repr__(self): return "(" + " ".join(map(repr, self)) + ")"
Atom = Symbol | Keyword | EnumLiteral | Integer | Float | String
Exp = Atom | List

def parse(s, p, first_exp_in_line=True) -> tuple[Exp, int]:
  level = 0
  stack = []
  implicit_parentheses = False
  while True:
    newline_was_skipped = False
    while True:
      while p < len(s) and s[p] in " \t\n\r":
        if s[p] == '\n': newline_was_skipped = True
        p += 1
      if p < len(s) and s[p] == ';':
        while p < len(s) and s[p] != '\n': p += 1
        continue
      break
    start = p
    if implicit_parentheses and level == 1 and newline_was_skipped:
      assert level > 0
      level -= 1
      popped = stack.pop()
      (stack[-1] if len(stack) > 0 else stack).append(popped)
    elif p >= len(s): break
    elif (first_exp_in_line and s[p] != '(') or s[p] == '(':
      if s[p] == '(': p += 1
      else: implicit_parentheses = True
      level += 1
      stack.append(List())
    elif s[p] == ')':
      p += 1
      assert level > 0 and not (level == 1 and implicit_parentheses), "too many closing parentheses"
      level -= 1
      popped = stack.pop()
      (stack[-1] if len(stack) > 0 else stack).append(popped)
    elif s[p] == "'":
      p += 1
      exp, next_pos = parse(s, p, first_exp_in_line=False)
      p = next_pos
      L = List()
      L.append(Symbol("$codeof"))
      L.append(exp)
      (stack[-1] if len(stack) > 0 else stack).append(L)
    elif s[p].isdigit():
      while p < len(s) and s[p].isdigit(): p += 1
      (stack[-1] if len(stack) > 0 else stack).append(Integer(s[start:p]))
    else:
      while p < len(s) and (not s[p].isspace() and s[p] != ')'): p += 1
      (stack[-1] if len(stack) > 0 else stack).append(Symbol(s[start:p]))
    first_exp_in_line = False
    if level == 0: break
  assert level == 0
  assert len(stack) <= 1
  return stack.pop() if len(stack) > 0 else None, p

@dataclass
class Type_Integer:
  bits: int
  signed: bool

type_void = "void"
type_comptime_int = "comptime_int"

class Value:
  def __init__(self):
    self.type_ = None
    self.value = None
  def print(self, s: str):
    if isinstance(self.value, Exp): return self.value
    raise NotImplementedError(type(self.value))

value_void = Value()
value_void.type_ = type_void

class Env:
  def __init__(self):
    self.parent = None
    self.data = {}
  def find(self, x: Symbol) -> Value:
    if x in self.data: return self.data[x]
    if self.parent is not None: return self.parent.find(x)
    return None

def value_from_exp(x: Exp) -> Value:
  if isinstance(x, Integer):
    value = Value()
    value.type_ = type_comptime_int
    value.value = x
    return value
  raise NotImplementedError(type(x))

def cteval(x: Exp, env: Env, s: str) -> Value:
  if not isinstance(x, List):
    if isinstance(x, Symbol):
      value = env.find(x)
      assert value is not None, f"{x} not in env"
      return value
    else: return value_from_exp(x)
  op, *args = x
  if op == Symbol("$define"):
    name_exp, value_exp = args
    name = cteval(name_exp, env, s)
    assert isinstance(name, Symbol)
    assert name not in env.data
    env.data[name] = cteval(value_exp, env, s)
    return value_void
  elif op == Symbol("$codeof"):
    assert len(args) == 1
    return args[0]
  else:
    proc = cteval(op, env, s)
    pargs = [cteval(arg, env, s) for arg in args]
    return proc(*pargs)

import sys
if len(sys.argv) == 1:
  print(f"Please provide me a file to compile, like this: {sys.argv[0]} your_main_file.z")
  exit(1)
with open(sys.argv[1]) as f: src = f.read()
pos = 0
env = Env()
while True:
  exp, next_pos = parse(src, pos)
  if exp is None: break
  pos = next_pos
  print(exp)
  result = cteval(exp, env, src)
  if result != value_void: print(result)
for value in env.data: print(value + ":", env.data[value].print(src))
