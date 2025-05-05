from dataclasses import dataclass
from enum import IntEnum
import sys

if len(sys.argv) == 1:
	while True:
		i = input("> ")
		if i == "exit": break
		p = 0
		while True:
			exp, next_p = parse(i, p)
			if exp is None: break
			p = next_p
			result = cteval(exp)
			if result.type_.kind != Type_Kind.VOID:
				print('=>', result)
else:
	file = sys.argv[1]
	with open(file) as f: src = f.read()
	print(src)
