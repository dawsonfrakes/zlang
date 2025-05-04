Parser :: struct {
  src: string;
  pos: u32;
}

peek :: (p: *Parser, n := 1) -> Token {
  token: Token = ---;
  pos := p.pos;
  for 0..n-1 {
    token = token_at(p.src, pos);
    pos = token.offset + token.length;
  }
  return token;
}

eat :: (p: *Parser, expect: Token.Kind) -> Token {
  token := token_at(p.src, p.pos);
  assert(expect == token.kind, "Expected %, got %", expect, token.kind);
  p.pos = token.offset + token.length;
  return token;
}

Calling_Convention :: enum {
  DEFAULT :: 0;
  Z :: 1;
  C :: 2;
}

AST :: struct {
  Node :: struct {
    Kind :: enum {
      NODE :: 0;
      MODULE :: 1;
      DECLARATION :: 2;
      LITERAL :: 3;
      BINARY_OPERATOR :: 4;
      TYPE_INSTANTIATION :: 5;
      VARIABLE :: 6;
      PROCEDURE_CALL :: 7;
      PROCEDURE :: 8;
      ENUM_LITERAL :: 9;
    }

    kind := Kind.NODE;
    type: *Typespec.Type_;
  }

  Module :: struct {
    #as using base: Node;
    kind = .MODULE;
    name: string;
    decls: [..]*Declaration;
  }

  Declaration :: struct {
    #as using base: Node;
    kind = .DECLARATION;
    identifier: Token;
    constant: bool;
    type_expr: *Node;
    value_expr: *Node;
  }

  Literal :: struct {
    #as using base: Node;
    kind = .LITERAL;
    token: Token;
  }

  Binary_Operator :: struct {
    #as using base: Node;
    kind = .BINARY_OPERATOR;
    left: *Node;
    operator_: Token;
    right: *Node;
  }

  Type_Instantiation :: struct {
    #as using base: Node;
    kind = .TYPE_INSTANTIATION;
    result: *Typespec.Type_;
  }

  Variable :: struct {
    #as using base: Node;
    kind = .VARIABLE;
    identifier: Token;
  }

  Procedure_Call :: struct {
    #as using base: Node;
    kind = .PROCEDURE_CALL;
    procedure_expr: *Node;
    arguments: [..]*Node;
  }

  Procedure :: struct {
    #as using base: Node;
    kind = .PROCEDURE;
    parameter_names: [..]Token;
    parameter_types: [..]*Node;
    return_type: *Node;
    callconv: *Node;
    export: *Node;
    body: [..]*Node;
  }

  Enum_Literal :: struct {
    #as using base: Node;
    kind = .ENUM_LITERAL;
    identifier: Token;
  }
}

parse_primary :: (p: *Parser) -> *AST.Node {
  if peek(p).kind == .INTEGER {
    literal := New(AST.Literal);
    literal.token = eat(p, .INTEGER);
    return literal;
  } else if peek(p).kind == #char "[" {
    eat(p, #char "[");
    eat(p, #char "]");
    eat(p, .IDENTIFIER); // u8 assumed for now.
    type_inst := New(AST.Type_Instantiation);
    type_inst.result = type_slice_u8;
    return type_inst;
  } else if peek(p).kind == .IDENTIFIER {
    variable := New(AST.Variable);
    variable.identifier = eat(p, .IDENTIFIER);
    return variable;
  } else if peek(p).kind == #char "." {
    eat(p, #char ".");
    enum_literal := New(AST.Enum_Literal);
    enum_literal.identifier = eat(p, .IDENTIFIER);
    return enum_literal;
  }
  assert(false, "% is not implemented", peek(p).kind);
  return null;
}

parse_factor :: (p: *Parser) -> *AST.Node {
  if peek(p).kind == #char "(" {
    eat(p, #char "(");
    expression := parse_expression(p);
    eat(p, #char ")");
    return expression;
  } else {
    primary := parse_primary(p);
    while peek(p).kind == #char "(" {
      eat(p, #char "(");
      call := New(AST.Procedure_Call);
      call.procedure_expr = primary;
      primary = call;
      while peek(p).kind != #char ")" array_add(*call.arguments, parse_expression(p));
      eat(p, #char ")");
    }
    return primary;
  }
}

parse_term :: (p: *Parser) -> *AST.Node {
  left := parse_factor(p);
  while peek(p).kind == #char "*" || peek(p).kind == #char "/" {
    binary_operator := New(AST.Binary_Operator);
    binary_operator.left = left;
    binary_operator.operator_ = eat(p, peek(p).kind);
    binary_operator.right = parse_factor(p);
    left = binary_operator;
  }
  return left;
}

parse_expression :: (p: *Parser) -> *AST.Node {
  left := parse_term(p);
  while peek(p).kind == #char "+" || peek(p).kind == #char "-" {
    binary_operator := New(AST.Binary_Operator);
    binary_operator.left = left;
    binary_operator.operator_ = eat(p, peek(p).kind);
    binary_operator.right = parse_term(p);
    left = binary_operator;
  }
  return left;
}

parse_declaration_or_expression :: (p: *Parser) -> *AST.Node {
  if peek(p, 2).kind == #char ":" return parse_declaration(p);
  else return parse_expression(p);
}

parse_procedure :: (p: *Parser) -> *AST.Node {
  proc := New(AST.Procedure);
  eat(p, .KEYWORD_PROC);
  eat(p, #char "(");
  eat(p, #char ")");
  if peek(p).kind == .OPERATOR_ARROW {
    eat(p, .OPERATOR_ARROW);
    proc.return_type = parse_expression(p);
  }
  if peek(p).kind == #char "#" {
    eat(p, #char "#");
    eat(p, #char "(");
    while peek(p).kind != #char ")" {
      if peek(p, 2).kind == #char "=" {
        ident := eat(p, .IDENTIFIER);
        eat(p, #char "=");
        expr := parse_expression(p);
        ident_str := string.{count = ident.length, data = p.src.data + ident.offset};
        if ident_str == "callconv" proc.callconv = expr;
        if ident_str == "export" proc.export = expr;
      } else {
        assert(false, "You can't do this here.");
        expr := parse_expression(p);
      }
      if peek(p).kind != #char "," break;
      eat(p, #char ",");
    }
    eat(p, #char ")");
  }
  indent: int;
  while peek(p).kind == .INDENT {
    new_indent := eat(p, .INDENT).length;
    defer indent = new_indent;
    if new_indent < indent break;
    array_add(*proc.body, parse_declaration_or_expression(p));
  }
  return proc;
}

parse_rhs_expression :: (p: *Parser) -> *AST.Node {
  if peek(p).kind == .KEYWORD_PROC return parse_procedure(p);
  return parse_expression(p);
}

parse_declaration :: (p: *Parser) -> *AST.Declaration {
  decl := New(AST.Declaration);
  decl.identifier = eat(p, .IDENTIFIER);
  eat(p, #char ":");
  if peek(p).kind != #char ":" && peek(p).kind != #char "=" {
    decl.type_expr = parse_expression(p);
  }
  if peek(p).kind == #char ":" || peek(p).kind == #char "=" {
    decl.constant = eat(p, peek(p).kind).kind == #char ":";
    decl.value_expr = parse_rhs_expression(p);
  }
  assert(decl.type_expr || decl.value_expr);
  return decl;
}

parse_module :: (p: *Parser, name: string) -> *AST.Module {
  module := New(AST.Module);
  module.name = name;
  while peek(p).kind != .END_OF_INPUT array_add(*module.decls, parse_declaration(p));
  return module;
}
