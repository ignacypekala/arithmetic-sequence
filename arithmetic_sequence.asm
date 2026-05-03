global arithmetic_sequence

; 
.compute_step:
    
        

arithmetic_sequence:
    ; Parameters:
    ; rdi - *a_0
    ; rsi - *a_1
    ; rdx - *a_k 
    ; rcx - n
    ; r8 - k

    ; Zeroing r10 for iteration clearing the CF flag, which causes sbb to act
    ; as sub on first iteration.
    xor r10, r10

.compute_common_difference:
    ; a_k[i] <-- a_1[i] - a_0[i]
    mov r9, [rsi + r10 * 8]
    sbb r9,[rdi + r10 * 8]
    mov [rdx + r10 * 8], r9

    ; Double iterators eliminate the need for cmp, which would 
    ; overwrite the CF flag.
    inc r10
    dec rcx
    jnz .compute_common_difference

    mov rdx, 0
    mov rax, 0
    ; Return values
    ; rax - lo
    ; rdx - hi
    ; [rdx] - a_k
    ret
