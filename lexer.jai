Token :: struct {
  Kind :: enum u8 {
    END_OF_INPUT :: 128;
    SYNTAX_ERROR :: 129;
    INDENT :: 130;

    IDENTIFIER :: 131;
    INTEGER :: 132;

    KEYWORD_PROC :: 148;

    OPERATOR_ARROW :: 192;
    OPERATOR_CAST :: 193;
  }

  offset: u32;
  length: u16;
  kind: Kind;
}

token_at :: (s: string, p: u32) -> Token {
  start := p;
  while true {
    while p < s.count && is_space(s[p]) p += 1;
    if p < s.count && s[p] == #char ";" {
      while p < s.count && s[p] != #char "\n" p += 1;
      start = p;
      continue;
    }
    break;
  }
  skipped_whitepace := start != p;
  start = p;
  if skipped_whitepace && (s[p - 1] == #char " " || s[p - 1] == #char "\t") {
    while p > 0 && (s[p - 1] == #char " " || s[p - 1] == #char "\t") p -= 1;
    if s[p - 1] == #char "\n" return .{kind = .INDENT, offset = p, length = cast(u16) (start - p)};
    p = start;
  }
  if p >= s.count return .{kind = .END_OF_INPUT, offset = p};
  if is_alpha(s[p]) || s[p] == #char "_" {
    while p < s.count && (is_alnum(s[p]) || s[p] == #char "_") p += 1;
    ident := string.{count = p - start, data = s.data + start};
    if ident == "proc" return .{kind = .KEYWORD_PROC, offset = start, length = cast(u16) (p - start)};
    else return .{kind = .IDENTIFIER, offset = start, length = cast(u16) (p - start)};
  } else if is_digit(s[p]) {
    while p < s.count && is_digit(s[p]) p += 1;
    return .{kind = .INTEGER, offset = start, length = cast(u16) (p - start)};
  } else if s[p] == #char ":" || s[p] == #char "(" || s[p] == #char ")" || s[p] == #char "[" || s[p] == #char "]" || s[p] == #char "#" || s[p] == #char "," || s[p] == #char "^" {
    p += 1;
    return .{kind = cast(Token.Kind) s[p - 1], offset = start, length = 1};
  } else if s[p] == #char "." {
    p += 1;
    if p < s.count && s[p] == #char "(" {
      p += 1;
      return .{kind = .OPERATOR_CAST, offset = start, length = cast(u16) (p - start)};
    }
    return .{kind = #char ".", offset = start, length = 1};
  } else if s[p] == #char "=" {
    p += 1;
    return .{kind = #char "=", offset = start, length = 1};
  } else if s[p] == #char "+" {
    p += 1;
    return .{kind = #char "+", offset = start, length = 1};
  } else if s[p] == #char "-" {
    p += 1;
    if p < s.count && s[p] == #char ">" {
      p += 1;
      return .{kind = .OPERATOR_ARROW, offset = start, length = cast(u16) (p - start)};
    }
    return .{kind = #char "-", offset = start, length = 1};
  } else if s[p] == #char "*" {
    p += 1;
    return .{kind = #char "*", offset = start, length = 1};
  }
  assert(false, "'%' is not implemented", string.{count = 1, data = s.data + p});
  return .{};
}

print_all_tokens :: (s: string) {
  p: u32 = 0;
  while true {
    token := token_at(s, p);
    if token.kind == .END_OF_INPUT break;
    p = token.offset + token.length;
    print("%: %\n", token.kind, string.{count = token.length, data = s.data + token.offset});
  }
}
