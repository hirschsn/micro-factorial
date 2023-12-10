	bits 16
	org 0x100

	%macro BZERO 2
	mov cx, %2
	mov di, %1
	xor al, al
	rep stosb
	%endmacro
	
;;; Multiplication with number <= 28 in BL (BL * 9 must fit into AL)
start:				; Todo: setup for boot sector (cld, ds, es, etc.)
	cld
	;; num and num2 are consecutive in memory
	;; Initialize number to 1
	;; mov cx, num_len
	;; mov di, num
	;; xor al, al
	;; rep stosb
	BZERO num, 2*num_len
	mov BYTE [num], 1

	mov ax, 20

	mov si, num
	mov di, num2
for_i:
	mov cx, num_len
	pusha
	call multiply_accumulate_with_num
	popa
	xchg si, di
	dec ax
	test ax, ax
	jnz for_i

	;; Print result
	xchg di, si		; Put result in di
	add di, num_len
	call printnum
	call newline

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
	push si
	push di			; Modified on stack
	push cx 		; Modified on stack
	push ax
	;; Zero out di
	xor al, al
	rep stosb
	pop ax

macc_num_loop:
	xor dx, dx
	mov bx, 10
	div bx
	;; AX := DX:AX / 10
	;; DX := DX:AX % 10
	push ax

	mov bx, sp
	mov si, WORD [bx+6]
	mov di, WORD [bx+4]
	mov cx, WORD [bx+2]
	mov bx, dx		; Remainder
	call multiply_accumulate_with_digit
	mov bx, sp
	dec WORD [bx+2]
	inc WORD [bx+4]
	pop ax
	test ax, ax
	jnz macc_num_loop
	
	pop cx
	pop di
	pop si
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

putchar:
        pusha
        mov ah, 0x0e
        mov bx, 0x000f
        int 0x10
        popa
        ret

newline:
        push ax
        mov al, 0x0a
        call putchar
        mov al, 0x0d
        call putchar
        pop ax
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
printnum_loop:
	mov al, BYTE[di]
	add al, '0'
	call putchar
	dec di
	loop printnum_loop
	pop ax
	ret

num_len:	equ 100
num:	equ $			; Little-endian, i.e. BYTE [num] == least significant digit
				;                     BYTE [num+num_len-1] == most sig. digit
num2:	equ $+num_len
