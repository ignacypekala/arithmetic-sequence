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

    ; Zeroing r10 for iteration clears the CF flag, which prevents sbb from
    ; including any borrow in the first iteration.

    ; r10 - limb index for the .compute_common_difference loop (i)
    xor r10, r10

; Perform subtraction (a_1 - a_0) limb by limb. The output is written into a_k.
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


; Now multiply


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
