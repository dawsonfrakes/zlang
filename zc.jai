#import "Basic";
#import "Compiler";
#import "File";
#import "String";

#load "parser.jai";
#load "printer.jai";

args: [] string;

do_compile :: () {
  if args.count == 0 {
    cmdline := get_toplevel_command_line();
    print("Please provide me the path to a file to compile. Like this: % % - your_main_file.z\n", path_filename(cmdline[0]), path_filename(cmdline[1]));
    exit(1);
  }

  src, success := read_entire_file(args[0]);
  if !success {
    print("Failed to load % from your drive.\n", args[0]);
    exit(1);
  }

  parser: Parser;
  parser.src = src;
  if true {
    decls := parse_module(*parser);
    for decls print_node(parser.src, it);
  } else {
    print_all_tokens(parser.src);
  }
}

#run {
  set_build_options_dc(.{do_output=false});
  args = get_build_options().compile_time_command_line;
  do_compile();
}
