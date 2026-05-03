global arithmetic_sequence

arithmetic_sequence:
    ; Parameters:
    ; rdi - *a_0 (2s complement)
    ; rsi - *a_1 (2s complement)
    ; rdx - *a_k (no important input)
    ; rcx - n (unsigned)
    ; r8 - k (signed)
    ; Registers:
    ; r10/rcx - iteration
    ; r9, r11, r12, rax, rdx - math
    
    push r12

    ; The difference (a_1 - a_0) can cause an overflow, requiring an extra
    ; (n+1)-th limb. We compute this virtual limb by sign-extending the highest
    ; limbs of A0 and A1 and subtracting them (with borrow) to prepend the 
    ; correct sign mask (0x0000000000000000 or 0xffffffffffffffff) 
    ; before multiplying.

    ; r11, r9 - masks for the virtual limb of a_0 and a_1 respectively
    mov r11, [rdi + rcx * 8 - 8]
    mov r9, [rsi + rcx * 8 - 8]
    sar r11, 63
    sar r9, 63

    ; r10 - limb index for the .compute_common_difference loop (i)
    ; Zeroing r10 for iteration clears the CF flag, which prevents sbb from
    ; including any borrow in the first iteration.
    xor r10, r10

; Performs subtraction (a_1 - a_0) limb by limb. The output is written into a_k.
; while (rcx > 0) { ...; i++; rcx--; }
.compute_common_difference:
    ; a_k[i] <-- a_1[i] - a_0[i]
    ; rax - used for subtraction
    mov rax, [rsi + r10 * 8]
    sbb rax, [rdi + r10 * 8]
    mov [rdx + r10 * 8], rax
    ; This approach eliminates the need for cmp which would overwrite CF.
    inc r10
    dec rcx
    jnz .compute_common_difference

    ; r9 now holds the most-significant limb of a_k.
    sbb r9, r11 

    ; r10 == n, rcx == 0, {r9, ...r_k} == (a_1 - a_0)

    ; [REDACT] We will now turn a_k into its absolute value so that multiplying becomes easier.
    ; r12 - a mask for negating a_k
    mov r12, [rdx + r10 * 8 - 8]
    sar r12, 63
    
; Applies the mask to the n-1 least significant limbs of a_k to extract the absolute value.
; for (int i = 0; i < n; i++) {a_k[i] <-- |a_k[i]|}
.turn_ak_absolute:
    xor [rdx + rcx * 8], r12
    inc rcx
    dec r10
    jnz .turn_ak_absolute

    ; Add 1 if a_k was negative
    neg r12
    add [rdx], r12

    ; rcx == n, r10 == 0, {r9, ...r_k} == |a_1 - a_0|

    sub r8, 1

    ; rdi - holds the pointer to a_k (a_0 is discarded)
    ; r11 - holds the carry for multiplication
    mov rdi, rdx
    xor r11, r11

; Calculate |a_1 - a_0| * (k - 1) for the n - 1 least significant limbs
; for ( i = 0; i < n; i++) {...}
.multiply_common_difference_absolute:
    mov rax, [rdi + r10 * 8]
    mul r8
    ; Add previous limb's carry to the lower half and absorb 
    ; any overflow into the upper half.
    add rax, r11
    adc rdx, 0
    mov [rdi + r10 * 8], rax
    mov r11, rdx

    inc r10
    dec rcx
    jnz .multiply_common_difference_absolute

    ; Add the final carry absorbing its potential overflow into rdx
    xor rdx, rdx
    add r9, r11
    adc rdx, 0

; Reapply the sign    
; r12 equals 1 if a_1 - a_0 was negative or 0 othwerise
; rdi - holds the pointer to a_k
; r10 == n, rcx == 0, {r9, ...r_k} = (k - 1) * |a_1 - a_0|
.revert_absolute:
    xor [rdi + rcx * 8], r12
    inc rcx
    dec r10
    jnz .revert_absolute
    
    neg r12
    add [rdi], r12
    

    ; Clear the flags before addition
    xor rdx, rdx

; Finally add a_1
; rdi - holds the pointer to a_k
; rsi - holds the pointer to a_1
; rax - used during addition
; r10 == 0, rcx == n, {r9, ...r_k} = (k - 1) * |a_1 - a_0|
.add_a1_to_result:
    mov rax, [rdi + r10 * 8]
    adc rax, [rsi + r10 * 8]
    mov [rdi + r10 * 8], rax
    inc r10
    dec rcx
    jnz .add_a1_to_result

    adc r9, 0

    
    ; mov rax, 0
    ; Return values
    ; rax - lo
    ; rdx - hi
    ; [rdi] - a_k
    mov rdx, 0
    mov rax, r9 

    pop r12

    ret
