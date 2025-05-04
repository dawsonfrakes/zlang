Typespec :: struct {
  Kind :: enum {
    TYPE :: 0;
    INTEGER :: 1;
    POINTER :: 2;
  }

  Type_ :: struct {
    kind := Kind.TYPE;
  }

  Integer :: struct {
    #as using base: Type_;
    kind = .INTEGER;
    bits: u8;
    signed: bool;
  }

  Pointer :: struct {
    Kind :: enum {
      SINGLE;
      MANY;
      SLICE;
    }

    #as using base: Type_;
    kind = .POINTER;
    pointer_kind: Kind;
    pointer_child: *Typespec.Type_;
  }
}

print_type :: (T: *Typespec.Type_) {
  if #complete T.kind == {
    case .TYPE; print("type");
    case .INTEGER;
      type_integer := cast(*Typespec.Integer) T;
      print("%", ifx type_integer.signed "s" else "u");
      print("%", type_integer.bits);
    case .POINTER;
      type_pointer := cast(*Typespec.Pointer) T;
      if #complete type_pointer.pointer_kind == {
        case .SINGLE; print("^");
        case .MANY; print("[^]");
        case .SLICE; print("[]");
      }
      print_type(type_pointer.pointer_child);
  }
}
