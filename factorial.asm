	bits 16
	org 0x100

;;; Multiplication with number <= 28 in BL (BL * 9 must fit into AL)
start:				; Todo: setup for boot sector (cld, ds, es, etc.)
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

	;; factorial(n)
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
.multiply_accumulate_with_digit:
	xor bl, bl
.macc_digit_loop:
	mov al, BYTE [si]
	mul dl
	add al, bl		; Add carry
	add al, BYTE [di]	; Accumulation
	aam
	mov BYTE [di], al
	mov bl, ah		; Save carry
	inc si
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

	;; Print result
	;; * di: result
	;; * cx: length
	add di, cx		; Advance to MSB
	dec di
printnum:
	;; Skip initial zeros
	std
	xor al, al
	repe scasb
	;; scasb iterates one past first non-zero element
	inc di
	inc cx

	mov ah, 0x0e
	mov bx, 0x000f
.printnum_loop:
	mov al, BYTE[di]
	add al, '0'
	int 0x10
	dec di
	loop .printnum_loop
exit:
	int 0x20



	;; Data
num_len equ 10000
num	equ $			; Little-endian, i.e. BYTE [num] == least significant digit
				;                     BYTE [num+num_len-1] == most sig. digit
num2	equ $+num_len
