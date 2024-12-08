
run: fact.com
	stat fact.com
	dosbox fact.com

fact.com: factorial.asm
	nasm -f bin factorial.asm -o fact.com

disas: fact.com
	objdump -D -b binary -m i8086 -M intel fact.com

.PHONY: run disas
