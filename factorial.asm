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

	;; si := num
	;; di := num2
	pop si
	mov di, num2

	;; factorial(n)
	;; ax := n
	mov ax, 20
factorial_loop:
	mov cx, num_len
	pusha
	call multiply_accumulate_with_num
	popa
	xchg si, di
	dec ax
	test ax, ax
	jnz factorial_loop

	;; Print result
	xchg di, si		; Put result in di
	add di, cx		; Advance di to MSB
	call printnum

exit:	int 0x20
	

	;; Parameters:
	;; * si: Address of least sig. digit of source BCD number
	;; * di: Address of least sig. digit of dest BCD number (not preserved)
	;; * cx: Length of BCD number in digits (not preserved)
	;; * ax: Number to multiply with (not preserved)
	;; Clobbered:
	;; * dx
	;; * bx
multiply_accumulate_with_num:
	pusha
	;; Zero out di
	xor al, al
	rep stosb
	popa

macc_num_loop:
	xor dx, dx
	mov bx, 10
	div bx
	;; AX := DX:AX / 10
	;; DX := DX:AX % 10
	pusha
	mov bx, dx		; Remainder
	call multiply_accumulate_with_digit
	popa
	dec cx
	inc di
	test ax, ax
	jnz macc_num_loop	
	ret

	;; Parameters:
	;; * si: Address of least sig. digit of source BCD number (not preserved)
	;; * di: Address of least sig. digit of dest BCD number (not preserved)
	;; * cx: Length of BCD number in digits
	;; * bl: Digit to multiply with
	;; Clobbered:
	;; * dl
	;; * ax
multiply_accumulate_with_digit:
	xor dl, dl
mul_loop:
	xor ah, ah
	mov al, BYTE [si]
	mul bl
	add al, dl		; Add carry
	add al, BYTE [di]	; Accumulation
	aam

	mov BYTE [di], al
	mov dl, ah		; BCD Carry
	inc si
	inc di
	loop mul_loop
	ret

	;; Parameters:
	;; * di: address of MSD (not preserved)
	;; * cx: len (not preserved)
	;; Clobbered:
	;; * DF
	;;
	;; Number must not be zero-length and must be greater than 0
printnum:
	push ax
	;; Skip initial zeros
	std
	xor al, al
	repe scasb
	;; scasb iterates one past first non-zero element
	inc di
	inc cx

	mov ah, 0x0e
	mov bx, 0x000f
printnum_loop:
	mov al, BYTE[di]
	add al, '0'
	int 0x10
	dec di
	loop printnum_loop
	pop ax
	ret

	;; Data
num_len:	equ 100
num:	equ $			; Little-endian, i.e. BYTE [num] == least significant digit
				;                     BYTE [num+num_len-1] == most sig. digit
num2:	equ $+num_len
