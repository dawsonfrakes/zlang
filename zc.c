#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>

typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef size_t usize;

typedef struct {
  usize count;
  u8* data;
} slice_u8;

typedef slice_u8 string;

slice_u8 permanent_storage;
usize permanent_storage_used;

#define New(T) ((T*) push_(sizeof(T)))
#define Make(N, T) ((T*) push_(sizeof(T) * (N)))
void* push_(size_t size) {
  u8* result = permanent_storage.data + permanent_storage_used;
  permanent_storage_used += size + 15;
  permanent_storage_used &= ~0xF;
  return result;
}

void die(char* msg, ...) {
  va_list ap;
  va_start(ap, msg);
  vfprintf(stderr, msg, ap);
  va_end(ap);
  exit(EXIT_FAILURE);
}

typedef enum Exp_Kind {
  EXP_IDENTIFIER,
  EXP_KEYWORD,
  EXP_INTEGER,
  EXP_FLOAT,
  EXP_STRING,
  EXP_ARRAY,
} Exp_Kind;

typedef struct slice_ExpPtr {
  usize count;
  struct Exp** data;
} slice_ExpPtr;

typedef struct Exp {
  usize loc;
  Exp_Kind kind;
  union {
    string as_atom;
    slice_ExpPtr as_array;
  } u;
} Exp;

#define stack_push(X, Y) { (X)->data[(X)->count++] = (Y); }
#define stack_pop(X) ((X)->data[--(X)->count])
Exp* parse_exp(string s, u32 p, u32* next_p, bool first_exp_in_line) {
  u32 level = 0;
  static slice_ExpPtr stack;
  stack.count = 0;
  if (stack.data == NULL) stack.data = Make(64, Exp*);
  bool implicit_parentheses = false;
  bool is_quoting = false;
  for (;;) {
    bool newline_was_skipped = false;
    for (;;) {
      while (p < s.count && isspace(s.data[p])) {
        if (s.data[p] == '\n') newline_was_skipped = true;
        p += 1;
      }
      if (p < s.count && s.data[p] == ';') {
        while (p < s.count && s.data[p] != '\n') p += 1;
        continue;
      }
      break;
    }
    u32 start = p;
    if (implicit_parentheses && level == 1 && newline_was_skipped) {
      level -= 1;
    } else if (p >= s.count) {
      break;
    } else if ((first_exp_in_line && level == 0) || s.data[p] == '(') {
      if (s.data[p] == '(') p += 1;
      else implicit_parentheses = true;
      level += 1;
      Exp* array = New(Exp);
      array->loc = start;
      array->kind = EXP_ARRAY;
      array->u.as_array.data = Make(64, Exp*); // TODO(dfra): wow be smarter than this please
      stack_push(&stack, array);
    } else if (s.data[p] == ')') {
      p += 1;
      if (level < 1) die("%d: Unmatched )\n", p);
      level -= 1;
      assert(stack.count > 0);
      Exp* popped = stack_pop(&stack);
      stack_push(stack.count > 0 ? &stack.data[stack.count - 1]->u.as_array : &stack, popped);
    } else if (s.data[p] == '\'') {
      is_quoting = true;
      p += 1;
      level += 1;
      Exp* array = New(Exp);
      array->loc = start;
      array->kind = EXP_ARRAY;
      array->u.as_array.count = 0;
      array->u.as_array.data = Make(64, Exp*);
      Exp* identifier = New(Exp);
      identifier->loc = start;
      identifier->kind = EXP_IDENTIFIER;
      identifier->u.as_atom.count = 7;
      identifier->u.as_atom.data = "$codeof";
      stack_push(&array->u.as_array, identifier);
      stack_push(&stack, array);
      continue;
    } else if (isdigit(s.data[p])) {
      while (p < s.count && isdigit(s.data[p])) p += 1;
      Exp* identifier = New(Exp);
      identifier->loc = start;
      identifier->kind = EXP_INTEGER;
      identifier->u.as_atom.data = s.data + start;
      identifier->u.as_atom.count = p - start;
      stack_push(stack.count > 0 ? &stack.data[stack.count - 1]->u.as_array : &stack, identifier);
    } else {
      while (p < s.count && (!isspace(s.data[p]) && s.data[p] != ')')) p += 1;
      Exp* identifier = New(Exp);
      identifier->loc = start;
      identifier->kind = EXP_IDENTIFIER;
      identifier->u.as_atom.data = s.data + start;
      identifier->u.as_atom.count = p - start;
      stack_push(stack.count > 0 ? &stack.data[stack.count - 1]->u.as_array : &stack, identifier);
    }
    first_exp_in_line = false;
    if (is_quoting) {
      level -= 1;
      Exp* popped = stack_pop(&stack);
      stack_push(stack.count > 0 ? &stack.data[stack.count - 1]->u.as_array : &stack, popped);
      is_quoting = false;
    }
    if (level == 0) break;
  }
  if (level != 0) die("%d: Unmatched (\n", p);
  assert(stack.count <= 1);
  *next_p = p;
  return stack.count > 0 ? stack.data[stack.count - 1] : NULL;
}

void print_exp(Exp* x, string s, u32 level, bool show_kinds) {
  if (show_kinds) printf("%d[", x->kind);
  switch (x->kind) {
    case EXP_IDENTIFIER:
    case EXP_KEYWORD:
    case EXP_INTEGER:
    case EXP_FLOAT:
    case EXP_STRING:
      printf("%.*s", (int) x->u.as_atom.count, x->u.as_atom.data);
      break;
    case EXP_ARRAY:
      printf("(");
      for (usize i = 0; i < x->u.as_array.count; i += 1) {
        Exp* child = x->u.as_array.data[i];
        assert(child != NULL);
        print_exp(child, s, level + 1, show_kinds);
        if (i != x->u.as_array.count - 1) printf(" ");
      }
      printf(")");
      break;
  }
  if (show_kinds) printf("]");
  if (level == 0) printf("\n");
}

typedef struct Type_Integer {
  u8 bits;
  bool is_signed;
} Type_Integer;

typedef enum Type_Pointer_Kind {
  POINTER_SINGLE,
  POINTER_MANY,
  POINTER_SLICE,
} Type_Pointer_Kind;

typedef struct Type_Pointer {
  Type_Pointer_Kind kind;
  struct Type* child;
} Type_Pointer;

typedef enum Type_Kind {
  TYPE_TYPE,
  TYPE_CODE,
  TYPE_VOID,
  TYPE_BOOL,
  TYPE_COMPTIME_INT,
  TYPE_COMPTIME_FLOAT,
  TYPE_INTEGER,
  TYPE_POINTER,
  TYPE_PROCEDURE,
} Type_Kind;

typedef struct Type {
  Type_Kind kind;
  union {
    Type_Integer as_integer;
    Type_Pointer as_pointer;
  } u;
} Type;

Type* type_code;
Type* type_void;
Type* type_comptime_int;
Type* type_comptime_float;
Type* type_u8;
Type* type_slice_u8;

typedef enum Value_Kind {
  VALUE_EXP,
  VALUE_TYPE,
  VALUE_PROCEDURE,
  VALUE_VOID,
} Value_Kind;

typedef struct Value {
  Type* type;
  Value_Kind kind;
  union {
    Exp* as_exp;
    Type* as_type;
  } u;
} Value;

Value* value_void;

typedef struct Env_Entry {
  bool constant;
  bool public;
  string key;
  Value* value;
} Env_Entry;

typedef struct slice_Env_EntryPtr {
  usize count;
  Env_Entry** data;
} slice_Env_EntryPtr;

typedef struct Env {
  struct Env* parent;
  slice_Env_EntryPtr table;
} Env;

#define string_equal_literal(A, B) string_equal((A), ((string){.count = sizeof(B) - 1, .data = (B)}))
bool string_equal(string a, string b) {
  if (a.count != b.count) return false;
  if (strncmp(a.data, b.data, a.count) != 0) return false;
  return true;
}

Env_Entry* table_find_pointer(slice_Env_EntryPtr* table, string key) {
  if (key.count == 0) return NULL;
  for (Env_Entry** entry = table->data; entry < table->data + table->count; entry += 1) {
    if (string_equal(key, (*entry)->key)) {
      return *entry;
    }
  }
  return NULL;
}

Env_Entry* env_find(Env* env, string identifier) {
  Env_Entry* entry = table_find_pointer(&env->table, identifier);
  if (entry != NULL) return entry;
  if (env->parent != NULL) return env_find(env->parent, identifier);
  return NULL;
}

void env_add(Env* env, string key, Value* value, bool constant, bool public) {
  Env_Entry* entry = New(Env_Entry);
  entry->constant = constant;
  entry->public = public;
  entry->key = key;
  entry->value = value;
  env->table.data[env->table.count++] = entry;
}

Value* eval_exp(Exp* x, Env* env, string s) {
  switch (x->kind) {
    case EXP_IDENTIFIER: {
      Env_Entry* entry = env_find(env, x->u.as_atom);
      if (entry == NULL) die("%zu: I failed to find %.*s in the current environment.\n", x->loc, (int) x->u.as_atom.count, x->u.as_atom.data);
      return entry->value;
    }
    case EXP_KEYWORD: {
      Value* value = New(Value);
      value->type = type_code;
      value->kind = VALUE_EXP;
      value->u.as_exp = x;
      return value;
    }
    case EXP_INTEGER: {
      Value* value = New(Value);
      value->type = type_comptime_int;
      value->kind = VALUE_EXP;
      value->u.as_exp = x;
      return value;
    }
    case EXP_FLOAT: {
      Value* value = New(Value);
      value->type = type_comptime_float;
      value->kind = VALUE_EXP;
      value->u.as_exp = x;
      return value;
    }
    case EXP_STRING: {
      Value* value = New(Value);
      value->type = type_slice_u8;
      value->kind = VALUE_EXP;
      value->u.as_exp = x;
      return value;
    }
    case EXP_ARRAY: {
      slice_ExpPtr* array = &x->u.as_array;
      if (array->count == 0) die("%zu: You tried to a call a procedure but didn't specify its name.\n", x->loc);

      Exp* op_exp = array->data[0];
      if (string_equal_literal(op_exp->u.as_atom, "$codeof")) {
        if (array->count != 2) die("%zu: $codeof expects exactly one argument.\n", x->loc);
        Value* value = New(Value);
        value->type = type_code;
        value->kind = VALUE_EXP;
        value->u.as_exp = array->data[1];
        return value;
      } else if (string_equal_literal(op_exp->u.as_atom, "$insert")) {
        if (array->count != 2) die("%zu: $insert expects exactly one argument (for now).\n", x->loc);
        return eval_exp(array->data[1], env, s);
      } else if (string_equal_literal(op_exp->u.as_atom, "$define")) {
        if (array->count != 3) die("%zu: $define expects exactly two arguments (for now).\n", x->loc);
        Exp* key_exp = array->data[1];
        Value* key = eval_exp(key_exp, env, s);
        if (key->kind != VALUE_EXP || key->u.as_exp->kind != EXP_IDENTIFIER) die("%zu: $define expects an identifier as its first argument.\n", x->loc);
        env_add(env, key->u.as_exp->u.as_atom, eval_exp(array->data[2], env, s), true, false);
        return value_void;
      } else {
        Value* maybe_procedure = eval_exp(op_exp, env, s);
        if (maybe_procedure->type->kind != TYPE_PROCEDURE) die("%zu: You tried to call something that wasn't a procedure.\n", op_exp->loc);
        assert(false); // unimplmented
        return NULL;
      }
    }
  }
}

void print_type(Type* type) {
  switch (type->kind) {
    case TYPE_TYPE: printf("($type 'TYPE)"); break;
    case TYPE_CODE: printf("($type 'CODE)"); break;
    case TYPE_VOID: printf("($type 'VOID)"); break;
    case TYPE_BOOL: printf("($type 'BOOL)"); break;
    case TYPE_COMPTIME_INT: printf("($type 'COMPTIME_INT)"); break;
    case TYPE_COMPTIME_FLOAT: printf("($type 'COMPTIME_FLOAT)"); break;
    case TYPE_INTEGER: printf("($type 'INTEGER '(#bits %d #signed ($cast ($type 'BOOL) %d)))", type->u.as_integer.bits, type->u.as_integer.is_signed); break;
    case TYPE_POINTER: printf("($type 'POINTER '(#kind %s #child ", type->u.as_pointer.kind == POINTER_SINGLE ? "'SINGLE" : type->u.as_pointer.kind == POINTER_MANY ? "'MANY" : "'SLICE"); print_type(type->u.as_pointer.child); printf("))"); break;
    case TYPE_PROCEDURE: printf("not implemented"); break;
  }
}

void print_value(Value* value, string s) {
  switch (value->kind) {
    case VALUE_VOID: printf("($cast ($type .VOID) 0)\n"); break;
    case VALUE_TYPE: print_type(value->u.as_type); printf("\n"); break;
    case VALUE_EXP: print_exp(value->u.as_exp, s, 0, false); break;
    case VALUE_PROCEDURE: printf("proc unimplemented\n"); break;
  }
}

string read_entire_file(char* filepath) {
  string result = {0};
  FILE* f = fopen(filepath, "rb");
  if (f) {
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    rewind(f);
    u8* buf = permanent_storage.data + permanent_storage_used;
    fread(buf, 1, len, f);
    buf[len] = 0;
    permanent_storage_used += len + 1;
    fclose(f);
    result.data = buf;
    result.count = len;
  }
  return result;
}

int main(int argc, char** argv) {
  permanent_storage.count = 1 * 1024 * 1024 * 1024;
  permanent_storage.data = calloc(permanent_storage.count, 1);
  assert(permanent_storage.data != NULL);

  if (argc == 0) die("I received no arguments from the command line.\n");
  if (argc == 1) die("Please provide me a file to compile, like this: `%s your_main_file.z`\n", argv[0]);

  type_code = &(Type){.kind = TYPE_CODE};
  type_void = &(Type){.kind = TYPE_VOID};
  type_comptime_int = &(Type){.kind = TYPE_COMPTIME_INT};
  type_comptime_float = &(Type){.kind = TYPE_COMPTIME_FLOAT};
  type_u8 = &(Type){.kind = TYPE_INTEGER, .u.as_integer = {.bits = 8, .is_signed = false}};
  type_slice_u8 = &(Type){.kind = TYPE_POINTER, .u.as_pointer = {.kind = POINTER_SLICE, .child = type_u8}};

  value_void = &(Value){.kind = VALUE_VOID, .type = type_void};

  string src = read_entire_file(argv[1]);
  // printf("%.*s", (int) src.count, src.data);
  u32 pos = 0;
  Env env = {0};
  env.table.data = Make(512, Env_Entry*);
  for (;;) {
    u32 next_pos;
    Exp* exp = parse_exp(src, pos, &next_pos, true);
    if (exp == NULL) break;
    pos = next_pos;
    print_exp(exp, src, 0, false);
    Value* value = eval_exp(exp, &env, src);
    if (value != value_void) print_value(value, src);
  }
  for (Env_Entry** entry = env.table.data; entry < env.table.data + env.table.count; entry += 1) {
    printf("%.*s: ", (int) (*entry)->key.count, (*entry)->key.data);
    print_value((*entry)->value, src);
  }

  return EXIT_SUCCESS;
}
