#include <boost/multiprecision/gmp.hpp>
#include <cassert>
#include <chrono>
#include <cinttypes>
#include <print>

// Do testowania rozwiązania używamy arytmetyki dowolnej precyzji.
using big_int_t = boost::multiprecision::mpz_int;

// Definiujemy typ wyniku testowanej funkcji.
typedef struct {
    uint64_t lo;
    int64_t hi;
} int128_t;

// Deklarujemy testowaną funkcję, aby mogła być wołana zarówno z C, jak i z C++.
extern "C" int128_t arithmetic_sequence(uint64_t const* A0, uint64_t const* A1,
        uint64_t* Ak, size_t n, int64_t k);

namespace {
    // Funkcje konwertujące są jawnie podane, aby pokazać,
    // jakiego kodowania liczb wymaga funkcja arithmetic_sequence.

    template <typename T>
        void convert2bin(T in, uint64_t* out, size_t n) {
            for (size_t i = 0; i < n; ++i) {
                out[i] = (uint64_t)(in & UINT64_MAX);
                in >>= 64;
            }
        }

    template <typename T>
        void convert2boost(T& out, uint64_t const* in, size_t n, int128_t r) {
            out = r.hi;
            out <<= 64;
            out += r.lo;
            for (size_t i = n; i-- > 0;) {
                out <<= 64;
                out += in[i];
            }
        }
}

int main(int argc, char* args[]) {
    if (argc != 5) {
        std::print("Usage:\n{} A0 A1 n k\n", args[0]);
        return 1;
    }

    unsigned long long arg_n = std::stoull(args[3]);
    long long arg_k = std::stoll(args[4]);
    assert(arg_n >= 1 && arg_n <= SIZE_MAX - 2);
    assert(arg_k >= INT64_MIN && arg_k <= INT64_MAX);
    size_t n = arg_n;
    int64_t k = arg_k;
    big_int_t A0(args[1]);
    big_int_t A1(args[2]);
    big_int_t Ak;
    big_int_t Ak_expected = (A1 - A0) * k + A0;

    uint64_t *a0 = new uint64_t[n], *a1 = new uint64_t[n],
             *ak = new uint64_t[n], *ak_expected = new uint64_t[n + 2];

    convert2bin(A0, a0, n);
    convert2bin(A1, a1, n);
    convert2bin(Ak_expected, ak_expected, n + 2);

    std::print("n  = {}\nk  = {:016x} ({})\nA0 = ", n, (uint64_t)k, k);
    for (size_t i = n; i-- > 0;)
        std::print("{:016x}", a0[i]);
    std::print("\nA1 = ");
    for (size_t i = n; i-- > 0;)
        std::print("{:016x}", a1[i]);
    std::print("\nAk = ");
    for (size_t i = n + 2; i-- > 0;)
        std::print("{:016x}", ak_expected[i]);
    std::print("\n");

    auto begin = std::chrono::system_clock::now();

    int128_t result = arithmetic_sequence(a0, a1, ak, n, k);

    auto end = std::chrono::system_clock::now();

    convert2boost(Ak, ak, n, result);

    int return_code;
    if (Ak == Ak_expected) {
        std::print("PASS\n");
        return_code = 0;
    } else {
        std::print("FAIL {:016x}{:016x}", (uint64_t)result.hi, result.lo);
        for (size_t i = n; i-- > 0;)
            std::print("{:016x}", ak[i]);
        std::print("\n");
        return_code = 1;
    }
    std::print("time {} µs\n", duration_cast<std::chrono::microseconds>(end - begin).count());

    delete[] a0;
    delete[] a1;
    delete[] ak;
    delete[] ak_expected;

    return return_code;
}
