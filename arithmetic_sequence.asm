global arithmetic_sequence

arithmetic_sequence:
    ; Parameters:
    ; rdi - *a_0 (unsigned)
    ; rsi - *a_1 (unsigned)
    ; rdx - *a_k (unsigned) (no important input)
    ; rcx - n (unsigned)
    ; r8 - k (signed)

    ; The difference (a_1 - a_0) can cause an overflow, requiring an extra
    ; (n+1)-th limb. We compute this virtual limb by sign-extending the highest
    ; limbs of A0 and A1 and subtracting them (with borrow) to prepend the 
    ; correct sign mask (0x0000000000000000 or 0xffffffffffffffff) before multiplying.
    mov r11, [rdi + rcx * 8 - 8]
    mov r9, [rsi + rcx * 8 - 8]
    sar r11, 63
    sar r9, 63

    ; Zeroing r10 for iteration clears the CF flag, which prevents sbb from
    ; including any borrow in the first iteration.
    xor r10, r10


; while (rcx > 0) { ...; i++; rcx--; }
.compute_common_difference:
    ; a_k[i] <-- a_1[i] - a_0[i]
    mov rax, [rsi + r10 * 8]
    sbb rax,[rdi + r10 * 8]
    mov [rdx + r10 * 8], rax
    ; This approach eliminates the need for cmp which would overwrite CF.
    inc r10
    dec rcx
    jnz .compute_common_difference

    ; Subtract the sign-extensions with borrow from the last iteration.
    sbb r9, r11

    ; r10 == n, rcx == 0, a_k = a_1 - a_0

    ; [REDACT] Now we will turn a_k into its absolute value so that multiplying becomes easier.
    ; Create a mask for negating.
    mov r11, [rdx + r10 * 8 - 8]
    sar r11, 63
    
; for (int i = 0; i < n; i++) {a_k[i] <-- |a_k[i]|}
.turn_ak_absolute:
    xor [rdx + r10 * 8 - 8], r11
    inc rcx
    dec r10
    jnz .turn_ak_absolute

    ; rcx == n, r10 == 0 

    ; Add 1 if a_k was negative
    neg r11
    add [rdx + rcx * 8 - 8], r11


    ; Now that a_k = |a_1 - a_0| we can do (n - 1) * |a_1 - a_0|

    sub rcx, 1

    ; a_0 is no longer needed but rdx will be used by imul.
    mov rdi, rdx
    xor r11, r11

; for ( i = 0; i < n - 1; i++) {...}
.multiply_common_difference_absolute:
    mov rax,[rdi + r10 * 8]
    mul rcx
    ; Add previous limb's carry to the lower half and absorb 
    ; any overflow into the upper half.
    add rax, r11
    adc rdx, 0
    mov [rdi + r10 * 8], rax
    mov r11, rdx
    
    inc r10
    cmp r10, rcx
    jl .multiply_common_difference_absolute

    mov rax,[rdi + rcx * 8]
    imul r10

    mov rdx, 0
    ; mov rax, 0
    ; Return values
    ; rax - lo
    ; rdx - hi
    ; [rdx] - a_k
    ret
