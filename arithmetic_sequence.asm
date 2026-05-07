global arithmetic_sequence

arithmetic_sequence:
    ; Author: Ignacy Pękała
    ; Calculates the k-th element of an arithmetic sequence a_n.
    ; Takes the first two elements of the sequence, space for the 64*n least
    ; significant bits of the output, n - an unsigned number of limbs of a_0,
    ; a_1 and a_k, and k - the signed index of the desired element.
    ;
    ; Parameters:
    ; rdi - *a_0 (two's complement)
    ; rsi - *a_1 (two's complement)
    ; rdx - *a_k (no important input)
    ; rcx -  n (unsigned)
    ; r8  -  k (signed)
    ;
    ; Registers:
    ; r9, rcx - current limb index (i) and remaining limb counter
    ;           (roles alternate per loop)
    ; r10, r11, r12, r13, rax, rdx - math
    ; 
    ; Note: 
    ; The notation "(A:B:...)" is used to denote a concatenated
    ; number, where A is the most significant limb. 
    ; Additionally array[i] is often used to denote accessing the ith element
    ; of an array i.e. the i-th limb.
    ;
    ; Return values
    ; (rdx:rax:[rdx]:[rdx + 8]:...) = a_k
    ; Note: rdx above refers to the initial value - the pointer to an array for
    ; a_k's n least significant limbs.
    ;

    ;
    ; Calculate the common difference of the arithmetic sequence by
    ; performing limb-by-limb subtraction (a_1 - a_0). The n least significant
    ; limbs are kept in the memory for a_k, while the additional (n + 1)-th limb
    ; is stored in the r10 register.
    ;
    ; Because the subtraction of signed integers (a_1 - a_0) can spill out into
    ; the (n + 1)-th limb, the register r10 has to be filled with 0s or 1s
    ; depending on the sign of the difference.
    ;

    mov r11, [rdi + rcx * 8 - 8]       ; The most significant bit of a_0.
    sar r11, 63                        ; Extend the sign bit across the entire register.
    mov r10, [rsi + rcx * 8 - 8]       ; Take the most significant bit of a_1.
    sar r10, 63                        ; Extend the sign bit across the entire register.

    xor r9, r9                         ; Reset r9 and flags so that sbb starts with no borrow.

;
; Registers:
;  - ([rsi]:[rsi + 8]:...) = a_1,
;  - ([rdi]:[rdi + 8]:...) = a_0,
;  - r9  holds the limb index (0 -> n),
;  - rdx holds *a_k
;  - rcx holds the remaining limb count (n -> 0).
;
; while (n > 0) { a_k[i] = a_1[i] - a_0[i] - borrow; i++; n--; }
;
.calculate_common_difference:
    mov rax, [rsi + r9 * 8]            ; Take i-th limb of a_1.
    sbb rax, [rdi + r9 * 8]            ; Subtract the i-th limb of a_0.
    mov [rdx + r9 * 8], rax            ; Write the result to the i-th limb of a_k.

    ; This approach to iteration eliminates the need for cmp which would overwrite CF.
    inc r9
    dec rcx
    jnz .calculate_common_difference

    sbb r10, r11                       ; Propagate the borrow from the final iteration into the sign-extended (n+1)-th limb.

    ;
    ; Now that the subtraction is complete:
    ; (r10:[rdx]:[rdx + 8]:...) = (a_1 - a_0)
    ;
    ; The number (a_1 - a_0) will now be multiplied by (k) using unsigned
    ; multiplication, while any introduced error will be subtracted in the process.
    ; 
    ; The possible error stems from the fact that a negative x interpreted as
    ; an unsigned integer equals to (x + 2^(64 * N)), where N is x's number of limbs. 
    ; Therefore two, non-mutually-exclusive scenarios have to be taken into account:
    ; Let: D = (a_1 - a_0), M = k.
    ; - D is negative:
    ;       (D + 2^(64 * n)) * M = D * M + 2^(64 * n) * M
    ;       and the result needs correction by 2^(64 * n) * M
    ; - M is negative:
    ;       for each limb i: 
    ;           D[i] * (M + 2^64) = D[i] * M + D[i] * 2^64
    ;           D[i] needs a correction by 2^64 * a_k[i]
    ;

    mov rsi, rdx                       ; Discard a_1 to hold *a_k.

    xor r11, r11                       ; Clear the flags and r11 for multiplication.

;
; Registers:
;  - rax and rdx will be used as accumulators during multiplication,
;  - r8          holds the multiplier (k),
;  - rsi         holds *a_k,
;  - r11         will hold the carry between multiplications,
;  - rcx         holds the limb index (0 -> n),
;  - r9          holds the remaining limb count (n -> 0).
; 
; while (n > 0) {
;   a_k[i] = (a_1 - a_0)[i] * (k) + carry;
;   if ((a_1 - a_0) < 0) {
;     carry -= (a_1 - a_0)[i];
;   }
;   i++; n--;
;  }
;
.multiply_common_difference_by_index_offset:
    mov rax, [rsi + rcx * 8]           ; Take the i-th limb of (a_1 - a_0).
    mul r8                             ; Multiply it by the index offset.

    add rax, r11                       ; Absorb the previous carry from multiplication.
    adc rdx, 0

    ; Due to the error-correction subtraction, the 64-bit carry from the
    ; previous limb may have been negative. For it to be correctly added to the 128-bit 
    ; accumulator (rdx:rax), its sign extension must be added to the older limb.
    sar r11, 63
    add rdx, r11 
    
    ; Although less efficient, than its branchless alternative, this approach
    ; to error correction eliminates the need for a separate register for the
    ; sign-extension mask.
    test r8, r8
    jns .skip_loop_negative_index_offset_correction    
    sub rdx, [rsi + rcx * 8]           ; Subtract the correction from the carry.

.skip_loop_negative_index_offset_correction:

    mov [rsi + rcx * 8], rax           ; Save the lower limb.
    mov r11, rdx                       ; Pass the carry for the next iteration.

    inc rcx
    dec r9
    jnz .multiply_common_difference_by_index_offset

    ; The current most significant limb ((n + 1)-st) will now be multiplied manually.

    mov rax, r10                       ; Take the (n + 1)-st limb.
    mul r8                             ; Multiply it by the index offset.

    add rax, r11                       ; Absorb the previous carry from multiplication.
    adc rdx, 0

    ; Just as in the last loop, the incoming 64-bit carry may have been
    ; negative. We apply the same 128-bit adapter pattern here to safely absorb it.
    sar r11, 63
    add rdx, r11

    ; Subtract the error if the multiplier was negative.
    test r8, r8
    jns .skip_final_negative_index_offset_correction
    sub rdx, r10

.skip_final_negative_index_offset_correction:

    ; Now the result will be corrected if the common difference was negative.
    
    test r10, r10
    jns .skip_negative_common_difference_correction
    sub rdx, r8                        ; Subtract it from the (n + 1)-th limb.

.skip_negative_common_difference_correction:

    ;
    ; The multiplication is complete and the result can
    ; be increased by a_1 to calculate the final a_k.
    ; 
    
    mov r11, [rdi + rcx * 8 - 8]
    sar r11, 63

    xor r8, r8                         ; Clear the flags before addition.

;
; Registers:
;  - (rdx:rax:[rsi]:[rsi + 8]:...) = (a_1 - a_0)(k),
;  - rsi holds the pointer to a_1,
;  - rcx holds the remaining limb count (n -> 0),
;  - r9  holds the limb index (0 -> n).
;
; while (n > 0) {
;   a_k[i] += a_1[i] + carry;
;   i++;
;   n--;
; }
.add_a0_to_result:
    mov r8, [rsi + r9 * 8]             ; Take the i-th limb of a_k.
    adc r8, [rdi + r9 * 8]             ; Add the i-th limb of a_0 with carry.
    mov [rsi + r9 * 8], r8             ; Save the result to a_k[i].

    inc r9
    dec rcx
    jnz .add_a0_to_result

    adc rax, r11                         ; Absorb the carry from the last addition
    adc rdx, r11                         ; Absorb the carry from the previous addition

    ret
