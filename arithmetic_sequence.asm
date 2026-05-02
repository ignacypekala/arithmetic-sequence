global arithmetic_sequence

arithmetic_sequence:
    ; Parameters:
    ; rdi - a_0
    ; rsi - a_1
    ; rdx - a_k 
    ; rcx - n
    ; r8 - k

    ; Calculate the arithmetic sequence difference
    mov r9, [rsi]
    sub r9, [rdi]

    sub rcx, 1

    mov [rdx], r9
    mov rdx, rcx
    mov rax, 0
    ; Return values
    ; rax - lo
    ; rdx - hi
    ; [rdx] - a_k
    ret
