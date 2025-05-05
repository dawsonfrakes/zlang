print_node :: (node: *AST.Node, s: string, level := 0) {
  if #complete node.kind == {
    case .NODE; print("<Node>");
    case .MODULE;
      module := cast(*AST.Module) node;
      for module.decls print_node(it, s, level);
    case .DECLARATION;
      decl := cast(*AST.Declaration) node;
      print("%", string.{count = decl.identifier.length, data = s.data + decl.identifier.offset});
      if decl.type_expr {
        print(": ");
        print_node(decl.type_expr, s, level);
      } else {
        print(" :");
      }
      if decl.value_expr {
        if decl.type_expr print(" ");
        print("% ", ifx decl.constant ":" else "=");
        print_node(decl.value_expr, s, level);
      }
      if level == 0 print("\n");
    case .LITERAL;
      literal := cast(*AST.Literal) node;
      print("%", string.{count = literal.token.length, data = s.data + literal.token.offset});
    case .BINARY_OPERATOR;
      binary_operator := cast(*AST.Binary_Operator) node;
      print("(");
      print_node(binary_operator.left, s, level);
      print(" % ", string.{count = binary_operator.operator_.length, data = s.data + binary_operator.operator_.offset});
      print_node(binary_operator.right, s, level);
      print(")");
    case .TYPE_INSTANTIATION;
      type_inst := cast(*AST.Type_Instantiation) node;
      print_type(type_inst.result);
    case .VARIABLE;
      variable := cast(*AST.Variable) node;
      print("%", string.{count = variable.identifier.length, data = s.data + variable.identifier.offset});
    case .PROCEDURE_CALL;
      call := cast(*AST.Procedure_Call) node;
      print_node(call.procedure_expr, s, level);
      print("(");
      for call.arguments {
        print_node(it, s, level);
        if it_index != call.arguments.count - 1 print(", ");
      }
      print(")");
    case .PROCEDURE;
      proc := cast(*AST.Procedure) node;
      print("(");
      for proc.parameter_types {
        print("%: ", proc.parameter_names[it_index]);
        print_node(it, s, level);
        if it_index != proc.parameter_types.count - 1 print(", ");
      }
      print(")");
      if proc.return_type {
        print(" -> ");
        print_node(proc.return_type, s, level);
      }
      print(" #(callconv=");
      if proc.callconv print_node(proc.callconv, s, level); else print(".DEFAULT");
      print(", export=");
      if proc.export print_node(proc.export, s, level); else print("false");
      print(")");
      if proc.block print_node(proc.block, s, level + 1);
    case .ENUM_LITERAL;
      enum_literal := cast(*AST.Enum_Literal) node;
      print(".%", string.{count = enum_literal.identifier.length, data = s.data + enum_literal.identifier.offset});
    case .BLOCK;
      block := cast(*AST.Block) node;
      for block.child_nodes {
        if it.kind != .BLOCK {
          print("\n");
          for 0..level-1 print("  ");
        }
        print_node(it, s, level + 1);
      }
    case .SLICE_OPERATOR;
      slice := cast(*AST.Slice_Operator) node;
      print_node(slice.left, s, level);
      print("[");
      if slice.start print_node(slice.start, s, level);
      print(":");
      if slice.end print_node(slice.end, s, level);
      print("]");
  }
}
