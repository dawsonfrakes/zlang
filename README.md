# Z Programming Language

## Compiling

```sh
# coming soon.
```

## Example

```scheme
($const WASM_PAGE_SIZE (* 64 1024))
($print "Hello, %. Did you know WASM's page size is % bytes?\n" "friend" WASM_PAGE_SIZE)
```

## Big Ideas™

- A statically typed Lisp-like systems programming language.
- Small amount of builtins (they start with $).
- Code is data, Types are data: pass around, modify, pass back.
- Infer types everywhere that makes sense.
