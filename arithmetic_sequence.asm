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


    ; Using unsigned multiplication to multiply (a_1 - a_0)*(k - 1).
    ; Because we're interpeting signed integers as unsigned there is a potential
    ; error but it will be nullified by further subtraction.

    dec r8 ; r8 == (k - 1)
    mov rdi, rax ; Discarding a_0 to hold *a_k
    ; Clears the flags and r11 for multiplication
    xor r11, r11 
    ; rax and rdx will be used during multiplication
    ; r8 holds the multiplier (k - 1)
    ; rdi holds *a_k
    ; r11 will hold the carry between multiplications

.multiply_common_difference_by_index:
    mov rax, [rdi + rcx * 8]
    mul r8
    add rax, r11
    ; Include the carry from the addition to the current multiplication carry.
    adc rdx, 0 
    mov [rdi + rcx * 8], rax
    mov r11, rdx
    inc rcx
    dec r10
    jnz .multiply_common_difference_by_index

    ; Manually multiply the most-significant limb stored in r9
    mov rax, r9
    mul r8
    ; Include the carry putting the output in rax (low) and rdx (high)
    add rax, r11
    adc rdx, 0

    ; Now (a_1 - a_0)*(k - 1) is stored across {rdx, rax, ...a_k}, provided
    ; that both (a_1 - a_0) and (k - 1) are positive.
    ; TODO Subtract the errors

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
