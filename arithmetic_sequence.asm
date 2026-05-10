global arithmetic_sequence

arithmetic_sequence:
        ; Arithmetic sequence
        ; Author: Ignacy Pękała
        ;
        ; Calculates the k-th element of an arithmetic sequence a_k.
        ; Takes the first two elements of the sequence, a pointer to an allocated
        ; memory buffer for the 64*n least significant bits of the output, n - an
        ; unsigned number of limbs of a_0, a_1 and a_k, and k - the signed index of
        ; the desired element.
        ;
        ; Parameters:
        ; rdi - *a_0 (two's complement)
        ; rsi - *a_1 (two's complement)
        ; rdx - *a_k (no important input)
        ; rcx -  n (unsigned)
        ; r8  -  k (signed)
        ;
        ; Registers:
        ; r9, - current limb index (i)
        ; rcx - remaining limb counter (n - i)
        ; r10, r11, rax, rdx - math
        ;
        ; Note:
        ; The notation "(A:B:...)" is used to denote a concatenated
        ; number, where A is the most significant limb.
        ; Additionally array[i] is often used to denote accessing the ith element
        ; of an array i.e. the i-th limb.
        ;
        ; Return values
        ; (rdx:rax:[rdx]:[rdx + 8]:...:[rdx + 8 * n - 8]) = a_k
        ; Note: rdx above refers to its initial value - the pointer to an array for
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

        mov     r11, [rdi + rcx * 8 - 8]        ; The most significant limb of a_0.
        sar     r11, 63                         ; Sign-extend it.
        mov     r10, [rsi + rcx * 8 - 8]        ; The most significant limb of a_1.
        sar     r10, 63                         ; Sign-extend it.

        xor     r9, r9                          ; Reset r9 and flags.

;
; Registers:
;  - ([rsi]:[rsi + 8]:...) = a_1,
;  - ([rdi]:[rdi + 8]:...) = a_0,
;  - rdx holds *a_k
;  - r9  holds the limb index (0 -> n),
;  - rcx holds the remaining limb count (n -> 0).
;
; while (n > 0) { a_k[i] = a_1[i] - a_0[i] - borrow; i++; n--; }
;
.calculate_common_difference:
        mov     rax, [rsi + r9 * 8]             ; the i-th limb of a_1
        sbb     rax, [rdi + r9 * 8]             ; Subtract the i-th limb of a_0.
        mov     [rdx + r9 * 8], rax             ; Write the result to the i-th limb of a_k.

        inc     r9
        ; Although the loop instruction is much less performant than the (dec, jnz)
        ; equivalent it is used here for the sake of machine code size reduction.
        loop    .calculate_common_difference

        sbb     r10, r11                        ; Calculate the (n+1)-th limb with the correct sign.

        ;
        ; Now that the subtraction is complete:
        ; (r10:[rdx]:[rdx + 8]:...) = (a_1 - a_0)
        ;
        ; The number (a_1 - a_0) will now be multiplied by (k) using unsigned
        ; multiplication, while any introduced error will be subtracted in the process.
        ;
        ; The possible error stems from the fact that a negative n-limb integer x interpreted
        ; in natural binary code is (x + 2^(64 * N)).
        ; Therefore two, non-mutually-exclusive scenarios have to be taken into account:
        ; Let: D = (a_1 - a_0), M = k.
        ; - if D is negative:
        ;       (D + 2^(64 * n)) * M = D * M + 2^(64 * n) * M
        ;       then the result needs correction by 2^(64 * n) * M
        ; - if M is negative:
        ;       for each limb i:
        ;           D[i] * (M + 2^64) = D[i] * M + D[i] * 2^64
        ;           D[i] needs a correction by 2^64 * D[i]
        ;

        ; Discard *a_1 to hold *a_k (rdx will be used as an accumulator during multiplication).
        mov     rsi, rdx

        ; This approach is slower but results in a lower machine code size.
        xchg    r9, rcx                         ; Reset the iterators
        xor     r11, r11

;
; Registers:
;  - (r10:[rsx]:[rsx + 8]:...) = (a_1 - a_0),
;  - rax and rdx will be used as accumulators during multiplication,
;  - r8          holds the multiplier, index k,
;  - r11         will hold the carry between multiplications,
;  - r9          holds the limb index (0 -> n),
;  - rcx         holds the remaining limb count (n -> 0).
;
; while (n > 0) {
;   a_k[i] = (a_1 - a_0)[i] * (k) + carry;
;   if (k < 0) {
;     carry -= (a_1 - a_0)[i];
;   }
;   i++; n--;
;  }
;
.multiply_common_difference_by_index:
        mov     rax, [rsi + r9 * 8]             ; the i-th limb of (a_1 - a_0)
        mul     r8                              ; Multiply it by the index.

        ; Absorb the previous carry from multiplication.
        add     rax, r11
        adc     rdx, 0

        ; Due to the error-correction subtraction, the 64-bit carry from the
        ; previous limb may have been negative. For it to be correctly added to the 128-bit
        ; accumulator (rdx:rax), its sign extension must be added to the older limb.
        sar     r11, 63
        add     rdx, r11

        ; Although less efficient than its branchless  alternative (sign-extension mask), 
        ; this approach to error correction reduces the numbmer of necessary registers.

        ; If the index k is negative:
        test    r8, r8
        jns     .skip_loop_negative_index_correction

        sub     rdx, [rsi + r9 * 8]             ; Subtract the i-th limb of (a_1-a_0) from the carry.

.skip_loop_negative_index_correction:

        mov     [rsi + r9 * 8], rax             ; Save the lower limb.
        mov     r11, rdx                        ; Pass the carry for the next iteration.

        inc     r9
        loop    .multiply_common_difference_by_index

        ; Multiply the current most significant limb ((n + 1)-st).

        mov     rax, r10                        ; the (n + 1)-st limb
        mul     r8                              ; Multiply it by the index.

        ; Absorb the previous carry from multiplication.
        add     rax, r11
        adc     rdx, 0

        ; Handle negative carry.
        sar     r11, 63
        add     rdx, r11

        ; Subtract the error if the multiplier was negative.
        test    r8, r8
        jns     .skip_final_negative_index_correction

        sub     rdx, r10

.skip_final_negative_index_correction:

        ; Correct the result if the common difference was negative.
        test    r10, r10
        jns     .skip_negative_common_difference_correction

        sub     rdx, r8                         ; Subtract the multiplier from the (n + 1)-st limb.

.skip_negative_common_difference_correction:

        ;
        ; The multiplication is complete, the result will be increased
        ; by a_0 to calculate the final a_k.
        ;

        mov     r11, [rdi + r9 * 8 - 8]         ; the most significant limb of a_0
        sar     r11, 63                         ; Sign-extend it.

        xchg    r9, rcx                         ; Reset the iterators.
        clc
;
; Registers:
;  - (rdx:rax:[rsi]:[rsi + 8]:...) = (a_1 - a_0) * (k),
;  - rdi holds the pointer to a_0,
;  - r9  holds the remaining limb count (n -> 0),
;  - rcx holds the limb index (0 -> n).
;
; while (n > 0) {
;   a_k[i] += a_1[i] + carry;
;   i++;
;   n--;
; }
.add_a0_to_result:
        mov     r8, [rdi + r9 * 8]              ; the i-th limb of a_0
        adc     [rsi + r9 * 8], r8              ; Add it to a_k[i].

        inc     r9
        loop    .add_a0_to_result

        ; Absorb the carry from the last addition
        adc     rax, r11
        adc     rdx, r11

        ret
