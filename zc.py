from dataclasses import dataclass
from enum import IntEnum

class Token_Kind(IntEnum):
  END_OF_INPUT = 128
  SYNTAX_ERROR = 129

  INDENT = 130

  IDENTIFIER = 131
  INTEGER = 132
  FLOAT = 133
  STRING = 134

  KEYWORD_u8 = 148

  def as_str(kind, s: str) -> str:
    return Token_Kind(kind).name if kind in Token_Kind else f"'{chr(kind)}'"

@dataclass
class Token:
  kind: int
  offset: int
  length: int

  def as_str(self, s: str, show_kinds=False) -> str:
    return f"Token({Token_Kind.as_str(self.kind, s)}, {s[self.offset:][:self.length]})" if show_kinds else s[self.offset:][:self.length]

def token_at(s: str, p: int) -> Token:
  start = p
  while True:
    while p < len(s) and s[p].isspace(): p += 1
    if p < len(s) and s[p] == ';':
      while p < len(s) and s[p] != '\n': p += 1
      start = p
      continue
    break
  if p >= len(s): return Token(Token_Kind.END_OF_INPUT, p, 0)
  skipped_whitespace = start != p
  start = p
  if skipped_whitespace:
    if s[p - 1] in " \t":
      while p > 0 and s[p - 1] in " \t": p -= 1
      if s[p - 1] == '\n': return Token(Token_Kind.INDENT, p, start - p)
    p = start
  if s[p].isalpha() or s[p] == '_':
    while p < len(s) and (s[p].isalnum() or s[p] == '_'): p += 1
    if s[start:p] == "u8": return Token(Token_Kind.KEYWORD_u8, start, p - start)
    return Token(Token_Kind.IDENTIFIER, start, p - start)
  if s[p].isdigit():
    while p < len(s) and s[p].isdigit(): p += 1
    return Token(Token_Kind.INTEGER, start, p - start)
  if s[p] in "+-*/:=.,~^&*[]<>()": return Token(ord(s[p]), p, 1)
  raise NotImplementedError(s[p])

def print_all_tokens(s: str):
  pos = 0
  while True:
    token = token_at(s, pos)
    if token.kind == Token_Kind.END_OF_INPUT: break
    pos = token.offset + token.length
    print(token.as_str(s, show_kinds=True))

@dataclass
class Type: pass

@dataclass
class Type_Integer(Type):
  bits: int
  signed: bool

@dataclass
class Type_Pointer(Type):
  kind: str
  child: Type

@dataclass
class Node: pass

@dataclass
class Node_Declaration(Node):
  identifier: Token
  constant: bool
  type_expr: Node
  value_expr: Node

@dataclass
class Node_Literal(Node):
  token: Token

@dataclass
class Node_Variable(Node):
  identifier: Token

@dataclass
class Node_Module(Node):
  decls: list[Node_Declaration]

@dataclass
class Node_Binary_Operator(Node):
  lhs: Node
  op: Token
  rhs: Node

@dataclass
class Node_Type(Node):
  type_: Type

@dataclass
class Parser:
  s: str
  p: int = 0

  def peek(self, n: int = 1) -> Token:
    token = None
    pos = self.p
    for _ in range(n):
      token = token_at(self.s, pos)
      pos = token.offset + token.length
    return token

  def eat(self, expect: int) -> Token:
    token = token_at(self.s, self.p)
    assert token.kind == expect, f"Expected {Token_Kind.as_str(expect, self.s)}, got {Token_Kind.as_str(token.kind, self.s)}"
    self.p = token.offset + token.length
    return token

  def parse_factor(self) -> Node:
    if self.peek().kind == Token_Kind.INTEGER: return Node_Literal(token=self.eat(Token_Kind.INTEGER))
    elif self.peek().kind == Token_Kind.IDENTIFIER: return Node_Variable(identifier=self.eat(Token_Kind.IDENTIFIER))
    raise NotImplementedError(self.peek().kind)

  def parse_term(self) -> Node:
    lhs = self.parse_factor()
    while self.peek().kind in [ord('*'), ord('/')]:
      op = self.eat(self.peek().kind)
      rhs = self.parse_factor()
      lhs = Node_Binary_Operator(lhs=lhs, op=op, rhs=rhs)
    return lhs

  def parse_expression(self) -> Node:
    if self.peek().kind in [Token_Kind.KEYWORD_u8]: self.eat(Token_Kind.KEYWORD_u8); return Node_Type(type_=Type_Integer(8, False))
    elif self.peek().kind in [ord('^'), ord('[')]:
      is_slice = self.eat(self.peek().kind).kind == ord('[')
      is_many = self.peek().kind == ord('^')
      if is_many: self.eat(ord('^'))
      if is_slice: self.eat(ord(']'))
      child = self.parse_expression()
      assert isinstance(child, Node_Type), type(child)
      return Node_Type(type_=Type_Pointer(kind="MANY" if is_many else "SLICE" if is_slice else "SINGLE", child=child.type_))
    else:
      lhs = self.parse_term()
      while self.peek().kind in [ord('+'), ord('-')]:
        op = self.eat(self.peek().kind)
        rhs = self.parse_term()
        lhs = Node_Binary_Operator(lhs=lhs, op=op, rhs=rhs)
      return lhs

  def parse_declaration(self) -> Node_Declaration:
    identifier = self.eat(Token_Kind.IDENTIFIER)
    self.eat(ord(':'))
    type_expr = None
    if self.peek().kind not in [ord(':'), ord('=')]:
      type_expr = self.parse_expression()
    constant = False
    value_expr = None
    if self.peek().kind in [ord(':'), ord('=')]:
      constant = self.eat(self.peek().kind).kind == ord(':')
      value_expr = self.parse_expression()
    return Node_Declaration(identifier=identifier, constant=constant, type_expr=type_expr, value_expr=value_expr)

  def parse_module(self) -> Node_Module:
    decls = []
    while self.peek().kind != Token_Kind.END_OF_INPUT: decls.append(self.parse_declaration())
    return Node_Module(decls=decls)

def print_node(node: Node, s: str, level = 0, prefix = "  "):
  print(prefix * level, end="")
  if node is None: print("(null)", end="")
  elif isinstance(node, Node_Module):
    print("(module")
    for index, decl in enumerate(node.decls):
      print_node(decl, s, level + 1)
      if index != len(node.decls) - 1: print("")
    print(")", end="")
  elif isinstance(node, Node_Declaration):
    print(f"({"const" if node.constant else "let"} {s[node.identifier.offset:][:node.identifier.length]}")
    if node.type_expr is not None:
      print(prefix*(level+1)+":type ", end="")
      print_node(node.type_expr, s, level + 1, "")
      print("")
    if node.value_expr is not None:
      print(prefix*(level+1)+":value ", end="")
      print_node(node.value_expr, s, level + 1, "")
    print(")", end="")
  elif isinstance(node, Node_Binary_Operator):
    print(f"({s[node.op.offset:][:node.op.length]}", end="")
    print(" ", end="")
    print_node(node.lhs, s, level + 1, "")
    print(" ", end="")
    print_node(node.rhs, s, level + 1, "")
    print(")", end="")
  elif isinstance(node, Node_Literal):
    print(f"{s[node.token.offset:][:node.token.length]}", end="")
  else: raise NotImplementedError(node.kind)
  if level == 0: print("")

class CVisitor:
  def __init__(self):
    self.defines = []
    self.globals = []

  def format_type(self, type_: Type):
    if isinstance(type_, Type_Pointer):
      return self.format_type(type_.child) + "*"
    elif isinstance(type_, Type_Integer):
      return ("int" if type_.signed else "uint") + str(type_.bits) + "_t"
    raise NotImplementedError(type(type_))

  def print(self):
    print("// defines")
    for define in self.defines:
      print(f"#define {define[0]} {define[1]}")
    print("")
    print("// globals")
    for glob in self.globals:
      print(f"static {self.format_type(glob[1])} {glob[0]}{f" = {glob[2]}" if glob[2] is not None else ""};")

  def visit_Node_Module(self, node: Node_Module, s: str):
    for decl in node.decls:
      self.visit(decl, s)

  def visit_Node_Declaration(self, node: Node_Declaration, s: str):
    if node.constant:
      assert node.value_expr is not None
      self.defines.append([s[node.identifier.offset:][:node.identifier.length], self.visit(node.value_expr, s)])
    else:
      type_ = self.visit(node.type_expr, s)
      if node.value_expr is not None: value = self.visit(node.value_expr, s)
      else: value = None
      self.globals.append([s[node.identifier.offset:][:node.identifier.length] + "_data", type_, value])
      if type_.kind == "SLICE":
        self.globals.append([s[node.identifier.offset:][:node.identifier.length] + "_count", Type_Integer(64, False), None])

  def visit_Node_Binary_Operator(self, node: Node_Binary_Operator, s: str):
    return '(' + self.visit(node.lhs, s) + s[node.op.offset:][:node.op.length] + self.visit(node.rhs, s) + ')'

  def visit_Node_Type(self, node: Node_Type, s: str):
    return node.type_

  def visit_Node_Literal(self, node: Node_Literal, s: str):
    if node.token.kind == Token_Kind.INTEGER: return s[node.token.offset:][:node.token.length]
    raise NotImplementedError(node.token.kind)

  def visit(self, node: Node, s: str):
    return getattr(self, "visit_" + node.__class__.__name__)(node, s)

import sys

if len(sys.argv) == 1:
  print("Grrr! I want a file to compile! Like this: " + sys.argv[0] + " your_main_file.z")
  exit(1)
with open(sys.argv[1]) as f: src = f.read()
# print_all_tokens(src)
parser = Parser(src)
module = parser.parse_module()
# print_node(module, src)
cvisitor = CVisitor()
cvisitor.visit(module, src)
cvisitor.print()
