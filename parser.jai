Token :: struct {
  Kind :: enum u8 {
    END_OF_INPUT :: 128;
    SYNTAX_ERROR :: 129;

    INDENT :: 130;

    IDENTIFIER :: 131;
    LITERAL :: 132;

    KEYWORD_struct :: 148;
  };

  offset: u32;
  length: u16;
  kind: Kind;
}

token_at :: (s: string, p: u32) -> Token {
  start := p;
  while true {
    start = p;
    while p < s.count && is_space(s[p]) p += 1;
    if p < s.count && s[p] == #char ";" {
      while p < s.count && s[p] != #char "\n" p += 1;
      continue;
    }
    break;
  }
  if p >= s.count return .{kind = .END_OF_INPUT, offset = p};
  skipped_spaces := start != p;
  start = p;
  if skipped_spaces {
    if p > 0 && (s[p - 1] == #char " " || s[p - 1] == #char "\t") {
      while p > 0 && (s[p - 1] == #char " " || s[p - 1] == #char "\t") p -= 1;
      if p == 0 || s[p - 1] == #char "\n" return .{kind = .INDENT, offset = p, length = cast(u16) (start - p)};
    }
    p = start;
  }
  if is_alpha(s[p]) || s[p] == #char "_" {
    while p < s.count && (is_alnum(s[p]) || s[p] == #char "_") p += 1;
    return .{kind = .IDENTIFIER, offset = start, length = cast(u16) (p - start)};
  } else if is_digit(s[p]) {
    while p < s.count && is_digit(s[p]) p += 1;
    return .{kind = .LITERAL, offset = start, length = cast(u16) (p - start)};
  } else if s[p] == #char ":" {
    p += 1;
    return .{kind = cast(Token.Kind) s[p - 1], offset = start, length = cast(u16) (p - start)};
  } else if s[p] == #char "*" {
    p += 1;
    return .{kind = cast(Token.Kind) s[p - 1], offset = start, length = cast(u16) (p - start)};
  }
  return .{kind = .SYNTAX_ERROR, offset = p, length = 1};
}

print_all_tokens :: (s: string) {
  p: u32 = 0;
  while true {
    token := token_at(s, p);
    if token.kind == .END_OF_INPUT break;
    p = token.offset + token.length;
    print("% %\n", token.kind, string.{count = token.length, data = s.data + token.offset});
  }
}

Parser :: struct {
  src: string;
  pos: u32;
}

peek :: (parser: *Parser, n := 1) -> Token {
  token: Token;
  p := parser.pos;
  for 0..n-1 {
    token = token_at(parser.src, p);
    p = token.offset + token.length;
  }
  return token;
}

eat :: (parser: *Parser, expect: Token.Kind) -> Token {
  token := token_at(parser.src, parser.pos);
  assert(token.kind == expect, "Expected %, got %.\n", expect, token.kind);
  parser.pos = token.offset + token.length;
  return token;
}

ast :: struct {
  Node :: struct {
    Kind :: enum {
      NODE :: 0;
      DECLARATION :: 1;
      LITERAL :: 2;
      BINARY_OPERATOR :: 3;
    }

    kind := Kind.NODE;
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
    lhs: *Node;
    operator_: Token;
    rhs: *Node;
  }
}

parse_Declaration :: (p: *Parser) -> *ast.Declaration {
  decl := New(ast.Declaration);
  decl.identifier = eat(p, .IDENTIFIER);
  eat(p, #char ":");
  if peek(p).kind != #char ":" && peek(p).kind != #char "=" {
    decl.type_expr = parse_expression(p);
  }
  if peek(p).kind == #char ":" || peek(p).kind == #char "=" {
    decl.constant = eat(p, peek(p).kind).kind == #char ":";
    decl.value_expr = parse_expression(p);
  }
  assert(decl.type_expr || decl.value_expr);
  return decl;
}

parse_factor :: (p: *Parser) -> *ast.Node {
  if peek(p).kind == .LITERAL {
    result := New(ast.Literal);
    result.token = eat(p, .LITERAL);
    return result;
  } else if peek(p).kind == #char "(" {
    eat(p, #char "(");
    result := parse_expression(p);
    eat(p, #char ")");
    return result;
  }
  assert(false, "How do I handle %?", peek(p).kind);
  return null;
}

parse_term :: (p: *Parser) -> *ast.Node {
  lhs := parse_factor(p);
  while peek(p).kind == #char "*" || peek(p).kind == #char "/" {
    new := New(ast.Binary_Operator);
    new.lhs = lhs;
    new.operator_ = eat(p, peek(p).kind);
    new.rhs = parse_factor(p);
    lhs = new;
  }
  return lhs;
}

parse_expression :: (p: *Parser) -> *ast.Node {
  lhs := parse_term(p);
  while peek(p).kind == #char "+" || peek(p).kind == #char "-" {
    new := New(ast.Binary_Operator);
    new.lhs = lhs;
    new.operator_ = eat(p, peek(p).kind);
    new.rhs = parse_term(p);
    lhs = new;
  }
  return lhs;
}

parse_module :: (p: *Parser) -> [..]*ast.Node {
  decls: [..]*ast.Node;
  while peek(p).kind != .END_OF_INPUT {
    array_add(*decls, parse_Declaration(p));
  }
  return decls;
}
