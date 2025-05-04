print_node :: (s: string, node: *ast.Node, level := 0) {
  if !node {
    print("(null)");
  } else if #complete node.kind == {
    case .NODE;
      print("Node(%)", node.*);
    case .DECLARATION;
      decl := cast(*ast.Declaration) node;
      print("Declaration(");
      print("%, ", string.{count = decl.identifier.length, data = s.data + decl.identifier.offset});
      print("constant=%, type_expr=", decl.constant);
      print_node(s, decl.type_expr, level + 1);
      print(", value_expr=");
      print_node(s, decl.value_expr, level + 1);
      print(")");
    case .BINARY_OPERATOR;
      binary_operator := cast(*ast.Binary_Operator) node;
      print("Binary_Operator(");
      print_node(s, binary_operator.lhs, level + 1);
      print(" % ", string.{count = binary_operator.operator_.length, data = s.data + binary_operator.operator_.offset});
      print_node(s, binary_operator.rhs, level + 1);
      print(")");
    case .LITERAL;
      literal := cast(*ast.Literal) node;
      print("%", string.{count = literal.token.length, data = s.data + literal.token.offset});
  }
  if level == 0 print("\n");
}
