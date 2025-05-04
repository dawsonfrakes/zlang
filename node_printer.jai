print_node :: (node: *AST.Node, s: string, level := 0) {
  for 0..level-1 print("  ");
  if #complete node.kind == {
    case .NODE; print("<Node>");
    case .MODULE;
      module := cast(*AST.Module) node;
      for module.decls print_node(it, s);
    case .DECLARATION;
      decl := cast(*AST.Declaration) node;
      print("%", string.{count = decl.identifier.length, data = s.data + decl.identifier.offset});
      if decl.type_expr {
        print(": ");
        print_node(decl.type_expr, s);
      } else {
        print(" :");
      }
      if decl.value_expr {
        if decl.type_expr print(" ");
        print("% ", ifx decl.constant ":" else "=");
        print_node(decl.value_expr, s);
      }
      print("\n");
    case .LITERAL;
      literal := cast(*AST.Literal) node;
      print("%", string.{count = literal.token.length, data = s.data + literal.token.offset});
    case .BINARY_OPERATOR;
      binary_operator := cast(*AST.Binary_Operator) node;
      print("(");
      print_node(binary_operator.left, s);
      print(" % ", string.{count = binary_operator.operator_.length, data = s.data + binary_operator.operator_.offset});
      print_node(binary_operator.right, s);
      print(")");
    case .TYPE_INSTANTIATION;
      type_inst := cast(*AST.Type_Instantiation) node;
      print_type(type_inst.result);
    case .VARIABLE;
      variable := cast(*AST.Variable) node;
      print("%", string.{count = variable.identifier.length, data = s.data + variable.identifier.offset});
  }
}
