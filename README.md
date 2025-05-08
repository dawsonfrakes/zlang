# Z Programming Language

## Big Ideas™

- A statically typed Lisp-like systems programming language.
- One level of implicit parentheses per line.
- Small amount of builtins (they start with $).
- Code is data, Types are data: pass around, modify, pass back.
- Allow the user to create their own "standard library" without any external imports.
- All programs can/should be freestanding.
- Zero is initialization.
- The user will be given the path to the compiler at compile time.

## Compiling

```sh
odin run . -- your_main_file.z
```

## Example

```wisp
; note: stb-syntax module isn't special, you can write your own syntaxes using builtins
$define stb ($import "stb-syntax") ; using, ::, :, :=, [:], -, *, >=, proc, void, u8, *u8, []u8
using stb

:: intrinsics ($import "intrinsics")

:: WASM_PAGE_SIZE (* 64 1024)
:: TEMPORARY_STORAGE_SIZE (* 16 1024)

: permanent_storage []u8
: temporary_storage []u8

:: _start (proc () void #callconv 'C
  :: page_count 128
  := previous_page_count (intrinsics.wasm-memory-grow 0 page_count)
  assert (>= previous_page_count 0)
  := memory ([:] (cast *u8 (* previous_page_count WASM_PAGE_SIZE)) 0 (* page_count WASM_PAGE_SIZE))

  := inflection (- (* page_count WASM_PAGE_SIZE) TEMPORARY_STORAGE_SIZE)
  = permanent_storage ([:] memory 0 inflection)
  = temporary_storage ([:] memory inflection)
)
```

## Builtins

```wisp
; Implemented
$codeof exp ; alias: 'exp
$if test conseq [alt]

; Partially Implemented
$define name exp [#flags ('PUBLIC | 'HOISTED)]
$insert string ... [#flags ('HOISTED)]
$operator op ... ; op = "==", "<=", ">=", "&&", "||", "<<", ">>", ">>>", or in "+-*/%~&|^!.=<>"

; Coming Soon
$proc name params return [#callconv 'DEFAULT] [#flags ('PUBLIC | 'HOISTED | 'ENTRY | 'EXPORT | 'VARARGS)] ...body
$block [#label exp] ...body
$rest
$compiles exp
$type kind [initializer]
$cast type value
$typeof exp
$loop condition ... [#label exp]
$break [#label exp] [#result exp] [#kind ('BREAK | 'CONTINUE | 'RETURN)]
$import string [#kind ('MODULE | 'FILE)]
$compiler ; compiler info struct (path, build target, command line, module paths, etc.)
```
