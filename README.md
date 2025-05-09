# Z Programming Language

## Big Ideas™

- A statically typed Lisp-like systems programming language.
- One level of implicit parentheses per line.
- Indentation-aware parsing reduces grouping parentheses.
- Small amount of builtins (they start with $).
- Code is data, Types are data: pass around, modify, pass back.
- Allow the user to create their own "standard library" without any external imports.
- All programs can/should be freestanding.
- Zero is initialization.
- The user will be given the path to the compiler at compile time.

## Example

```
$let jai ($import "jai")
jai.using jai

proc _start () void #callconv 'C
  print "The answer to the ultimate question is %.\n" 42

(import "compiler").create-pe-executable #arch 'AMD64 #subsystem 'WINDOWS #entry _start
```
