# Z Programming Language

```
Big Ideas™
|- A statically typed Lisp-like systems programming language.
|- One level of implicit parentheses per line.
|- Indentation-aware parsing reduces grouping parentheses.
|- Small amount of builtins (they start with $).
|- Code is data, Types are data: pass around, modify, pass back.
|- Allow the user to create their own "standard library" without any external imports.
|- All programs can/should be freestanding.
|- Zero is initialization.
|- The user will be given the path to the compiler at compile time.

; Description

"It's like you took Zig's type system, Jai's compile-time execution and macro system, fasm's interpreter engine, and Python's off-side rule, then jammed it into Lisp/Scheme syntax but removed the most recognizable part."

; Syntax/AST
Code
|- Atom
|-- Identifier
|-- Keyword
|-- Integer
|-- Float
|-- String
|- Array

; Syntactic sugar
'code => ($code code)

; Types
Type_Kind
|- Type
|- Code
|- Noreturn
|- Void
|- Bool
|- Comptime_Integer
|- Comptime_Float
|- Type_of_Null
|- Integer
|- Float
|- Optional
|- Pointer
|- Array
|- Struct
|- Union
|- Enum
|- Enum_Flags
|- Procedure

; Builtins
$define name value [#kind 'CONSTANT | 'VARIABLE] [#flags 'PUBLIC | 'HOISTED]
$declare name type #kind ['ZEROED | 'UNINITIALIZED] [#flags 'PUBLIC | 'HOISTED]
$assign name value
$cast type value
$type kind [initializer]
$type-of value
$code code
$code-of value
$meta-of code

; Example
$define 'x 5 #kind 'VARIABLE ##editor "some useful data"
; $define is a builtin.
;  it defines identifier 'x' to be value 5.
;  it signifies it is modifiable using a named parameter.
;  and it tags it with a metavariable 'editor',
;  which can later be retrieved with $meta-of.
```
