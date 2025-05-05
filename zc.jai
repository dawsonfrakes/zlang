#import "Basic";
#import "Compiler";
#import "File";
#import "Hash_Table";
#import "String";

args: []string;

do_compile :: () {
  if args.count == 1 {
    print("Grrr! I wanted you to give me a file to compile! Like this: jai zc.jai - your_main_file.z");
    exit(1);
  }

  src, success := read_entire_file(args[1]);
  if !success {
    print("I failed to find '%' on your drive. Maybe you need to quote the entire path?\n", args[1]);
    exit(1);
  }

  print("%", src);
}

#run {
  set_build_options_dc(.{do_output=false});
  temp_args: [..]string;
  array_add(*temp_args, "jai");
  array_add(*temp_args, ..get_build_options().compile_time_command_line);
  args = temp_args;
  do_compile();
}
