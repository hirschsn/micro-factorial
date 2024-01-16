;;; Bigint factorial in 100 Bytes.
;;; DOS program
;;; Copyright 2023 Steffen Hirschmann
;;;
;;; How to set a different input:
;;; =============================
;;; Adapt the line following "ax := n" below to set the number.
;;; To increse the number of possible output digits, change "num_len" at the end of the file.
;;;
;;; Build:
;;; ======
;;; nasm -f bin factorial.asm -o fact.com
;;;
;;; Run:
;;; ====
;;; dosbox fact.com
;;;
;;;
;;; This program requires SS, DS, ES to be set up properly (DOS takes care of that).
;;;
;;; The algorithm is very inefficient, since it always multiplies all "num_len" digits of the current accumulator (most of the time 0*0=0).
	bits 16
	org 0x100

start:
	cld
	;; num and num2 are consecutive in memory
	;; Initialize num := 1, num2 := 0
	mov di, num
	push di
	mov BYTE [di], 1
	inc di
	xor al, al
	mov cx, 2*num_len-1
	rep stosb

	;; si := num2
	;; di := num
	mov si, num2
	pop di

	;; factorial(n), n > 0
	;; ax := n
	mov ax, 100
factorial_loop:
	;; Current partial result in si. di is used as scratch buffer for multiplication.
	;; To avoid copying, the underlying buffers are switched every iteration.
	xchg si, di
	mov cx, num_len
	pusha

;;; INLINED
;;; Parameters:
;;; * si: Address of least sig. digit of source BCD number
;;; * di: Address of least sig. digit of dest BCD number (not preserved)
;;; * cx: Length of BCD number in digits (not preserved)
;;; * ax: Number to multiply with (not preserved)
;;; Clobbered:
;;; * dx
;;; * bx
;;;
;;; Performs the operation: D = S * ax, for BCD numbers D and S, addresses in di and si
multiply_accumulate_with_num:
	;; Zero out destination
	pusha
	xor al, al
	rep stosb
	popa

.macc_num_loop:
	xor dx, dx
	mov bx, 10
	div bx
	;; AX := DX:AX / 10
	;; DX := DX:AX % 10
	pusha

;;; INLINED
;;; Parameters:
;;; * si: Address of least sig. digit of source BCD number (not preserved)
;;; * di: Address of least sig. digit of dest BCD number (not preserved)
;;; * cx: Length of BCD number in digits (not preserved)
;;; * dl: Digit to multiply with
;;; Clobbered:
;;; * bl
;;; * ax
;;;
;;; Performs the operation: D = D + S * dl, for BCD numbers D and S, addresses in di and si
.multiply_accumulate_with_digit:
	xor bl, bl
.macc_digit_loop:
	lodsb
	mul dl
	add al, bl		; Add carry
	add al, BYTE [di]	; Accumulation
	aam
	;; AL := AL % 10
	;; AH := AL / 10
	mov BYTE [di], al
	mov bl, ah		; Save carry (not a flag, can be larger than 1)
	inc di
	loop .macc_digit_loop
;;; End of multiply_accumulate_with_digit

	popa
	dec cx
	inc di
	test ax, ax
	jnz .macc_num_loop
;;; End of multiply_accumulate_with_num

	popa
	dec ax
	jnz factorial_loop


;;; INLINED
;;; Parameters:
;;; * di: Address of least sig. digit of BCD number (not preserved)
;;; * cx: Length of BCD number in digits (not preserved)
;;; Clobbered:
;;; * ax
;;; * DF
	add di, cx		; Advance to MSB
	dec di
printnum:
	;; Skip initial zeros
	std
	xor al, al
	repe scasb
	inc di			; Scasb iterates one past last zero
	inc cx

	mov bx, 0x000f
.printnum_loop:
	mov ax, 0x0e30		; AH = 0x0e, AL = 0x30 == '0'; AH does not need to be set inside the loop, but doing so saves 1 Byte
	add al, BYTE[di]
	int 0x10
	dec di
	loop .printnum_loop
;;; End of printnum

exit:
	int 0x20


	;; Data
num_len equ 17000
num	equ $			; Little-endian, i.e. BYTE [num] == least significant digit
				;                     BYTE [num+num_len-1] == most sig. digit
num2	equ $+num_len
