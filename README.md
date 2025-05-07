# Z Programming Language

## Big Ideas™

- A statically typed Lisp-like systems programming language.
- One level of implicit parentheses per line.
- Small amount of builtins (they start with $).
- Code is data, Types are data: pass around, modify, pass back.
- Allow the user to create their own "standard library" without any external imports.
- All programs can/should be freestanding.
- Zero is initialization.

## Compiling

```sh
python zc.py your_main_file.z
```

## Example

```wisp
; (note: stb-syntax module isn't special, you can write your own syntaxes using builtins)
$using ($import "stb-syntax") ; ::, :, :=, [:], -, *, >=, proc, void, u8, *u8, []u8

:: intrinsics ($import "intrinsics")

:: WASM_PAGE_SIZE (* 64 1024)
:: TEMPORARY_STORAGE_SIZE (* 16 1024)

: permanent_storage []u8
: temporary_storage []u8

:: _start (proc () void #callconv .C
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
; implemented
$define name exp [#kind (.CONSTANT | .VARIABLE | .COMPILE_TIME)] [#flags (.HOISTED | .UNINITIALIZED | .ZEROED)]
$codeof exp

; coming soon
$proc name (...) return [#callconv .DEFAULT] [#flags (.ENTRY | .EXPORT)] ...body
$operator op ... ; op = "&&", "||", "<<", ">>", ">>>", or in "+-*/%~&|^!"
$import string [#kind (.MODULE | .FILE)] [#lookup (.MODULES | .RELATIVE)]
$type kind [initializer]
$cast type value
$typeof
$using exp
$insert string ...
$rest
$spread
$return
$for
$if
$switch
$case
$continue
$break
```
