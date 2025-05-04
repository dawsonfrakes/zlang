INTERPRETER :: true;

#import "Basic";
#import "Compiler";
#import "File";
#import "Hash_Table";
#import "String";

#load "lexer.jai";
#load "parser.jai";
#load "typer.jai";
#load "node_printer.jai";
#load "codegen_c.jai";

type_u8: *Typespec.Type_;
type_slice_u8: *Typespec.Type_;

args: []string;

compile :: () {
  type_u8 = *(Typespec.Integer.{bits = 8, signed = false});
  type_slice_u8 = *(Typespec.Pointer.{pointer_kind = .SLICE, pointer_child = type_u8});

  if args.count == 1 {
    print("Grrr! Provide me a file to compile! Like this: % your_main_file.z\n", ifx INTERPRETER "jai zc.jai -" else path_filename(args[0]));
    exit(1);
  }

  src, success := read_entire_file(args[1]);
  if !success {
    print("I couldn't find \"%\" on your drive. Maybe you meant to wrap your path in quotes?\n", args[1]);
    exit(1);
  }

  parser: Parser;
  parser.src = src;
  // print_all_tokens(src);
  module := parse_module(*parser, args[1]);
  print_node(module, src);
}

#if !INTERPRETER {
  main :: () {
    args = get_command_line_arguments();
    compile();
  }
} else #run {
  set_build_options_dc(.{do_output=false});
  temp_args: [..] string;
  array_add(*temp_args, get_toplevel_command_line()[0]);
  array_add(*temp_args, ..get_build_options().compile_time_command_line);
  args = temp_args;
  compile();
}
