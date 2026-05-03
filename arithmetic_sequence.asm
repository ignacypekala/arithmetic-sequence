global arithmetic_sequence

arithmetic_sequence:
    ; Parameters:
    ; rdi - *a_0 (unsigned)
    ; rsi - *a_1 (unsigned)
    ; rdx - *a_k (unsigned) (no important input)
    ; rcx - n (unsigned)
    ; r8 - k (signed)

    ; a_0 and a_1 are signed integers (two's complement). 
    ; Their difference can cause a signed overflow, requiring an extra (n+1)-th limb.
    ; We compute this virtual limb by sign-extending the highest limbs of A0 and A1
    ; and subtracting them (with borrow) to prepend the correct sign mask 
    ; (0x0000000000000000 or 0xffffffffffffffff) before multiplying.
    mov r11, [rdi + rcx * 8 - 8]
    mov rax, [rsi + rcx * 8 - 8]
    sar r11, 63
    sar rax, 63

    ; Zeroing r10 for iteration clears the CF flag, which prevents sbb from
    ; including any borrow in the first iteration.
    xor r10, r10

; while (rcx > 0) { ...; i++; rcx--; }
.compute_common_difference:
    ; a_k[i] <-- a_1[i] - a_0[i]
    mov r9, [rsi + r10 * 8]
    sbb r9,[rdi + r10 * 8]
    mov [rdx + r10 * 8], r9
    ; Doubled iterators eliminate the need for cmp, which would 
    ; overwrite the CF flag.
    inc r10
    dec rcx
    jnz .compute_common_difference

    ; Subtract the sign-extensions with borrow from the last iteration.
    sbb rax, r11

    sub rcx, 1

    mov rdx, 0
    ; mov rax, 0
    ; Return values
    ; rax - lo
    ; rdx - hi
    ; [rdx] - a_k
    ret
