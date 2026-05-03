#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SIZE(x) (sizeof x / sizeof x[0])

// Definiujemy typ wyniku testowanej funkcji.
typedef struct {
    uint64_t lo;
    int64_t hi;
} int128_t;

// Deklarujemy testowaną funkcję.
int128_t arithmetic_sequence(uint64_t const* A0, uint64_t const* A1,
        uint64_t* Ak, size_t n, int64_t k);

// To jest struktura przechowująca dane do testów.
typedef struct {
    uint64_t *A0, *A1; // wskaźniki na zawartości tablic A0 i A1 przekazywane do funkcji
    uint64_t* Ak; // wskaźnik na oczekiwaną zawartość tablicy Ak po wykonaniu funkcji
    size_t n; // rozmiar tablic A0, A1, Ak przekazywany do funkcji
    int64_t k; // wartość parametru k przekazywana do funkcji
    int128_t result; // oczekiwany wynik funkcji
} test_data_t;

// Plik test_data.c zawiera tablicę test_data_table z danymi do testów.
#include "test_data.c"

int main()
{
    int return_code = 0;

    for (size_t i = 0; i < SIZE(test_data_table); ++i) {
        test_data_t const* const t = &test_data_table[i];
        const size_t n = t->n;

        printf("n  = %zu\nk  = %016" PRIx64 " (%" PRId64 ")\nA0 = ", n, (uint64_t)t->k, t->k);
        for (size_t i = n; i-- > 0;)
            printf("%016" PRIx64 " ", t->A0[i]);
        printf("\nA1 = ");
        for (size_t i = n; i-- > 0;)
            printf("%016" PRIx64 " ", t->A1[i]);
        printf("\nAk = %016" PRIx64 " %016" PRIx64 " ", t->result.hi, t->result.lo);
        for (size_t i = n; i-- > 0;)
            printf("%016" PRIx64 " ", t->Ak[i]);
        printf("\n");

        uint64_t* A0 = calloc(n, sizeof(uint64_t));
        uint64_t* A1 = calloc(n, sizeof(uint64_t));
        uint64_t* Ak = calloc(n, sizeof(uint64_t));
        assert(A0 != nullptr && A1 != nullptr && Ak != nullptr);

        memcpy(A0, t->A0, n * sizeof(uint64_t));
        memcpy(A1, t->A1, n * sizeof(uint64_t));

        int128_t result = arithmetic_sequence(A0, A1, Ak, n, t->k);

        bool pass = true;
        if (result.lo != t->result.lo || result.hi != t->result.hi) {
            pass = false;
        } else {
            for (size_t j = 0; j < n; ++j) {
                if (Ak[j] != t->Ak[j]) {
                    pass = false;
                    break;
                }
            }
        }

        if (pass) {
            printf("PASS\n");
        } else {
            printf("FAIL %016" PRIx64  " %016" PRIx64 " ", result.hi, result.lo);
            for (size_t i = n; i-- > 0;)
                printf("%016" PRIx64 " ", Ak[i]);
            printf("\n");
            return_code = 1;
        }

        free(A0);
        free(A1);
        free(Ak);
    }

    return return_code;
}
