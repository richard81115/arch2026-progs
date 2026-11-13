/* Host tool: largest relative error of the BFloat16 routines against exact
 * arithmetic in double precision, over the positive normal operands.
 *
 *   gcc -O2 -Wall -o /tmp/bf16_err mytools/bf16_err.c src/bf16/bf16.c -lm
 */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../src/bf16/bf16.h"

static double val[65536]; /* value of every finite pattern */

static int is_normal(uint16_t b)
{
    int e = (b >> 7) & 0xFF;
    return e != 0 && e != 0xFF;
}

int main(void)
{
    for (uint32_t b = 0; b < 65536; b++) {
        int e = (b >> 7) & 0xFF, f = b & 0x7F;
        double v = e ? ldexp(128 + f, e - 134) : ldexp(f, -133);
        val[b] = (b & 0x8000) ? -v : v;
    }

    /* Conversion: every positive normal binary32 input, finite results. */
    double worst = 0;
    uint32_t at = 0;
    uint64_t n = 0;
    for (uint32_t bits = 0x00800000u; bits < 0x7F800000u; bits++) {
        uint16_t r = bf16_from_f32(bits);
        if (!is_normal(r))
            continue;
        float x;
        memcpy(&x, &bits, sizeof x);
        double err = fabs(val[r] - (double) x) / (double) x;
        n++;
        if (err > worst) {
            worst = err;
            at = bits;
        }
    }
    printf("conversion:  worst %.4f%% at 0x%08x -> 0x%04x, %llu inputs\n",
           worst * 100, at, bf16_from_f32(at), (unsigned long long) n);

    /* Multiply: every pair of positive normals with a normal result. */
    worst = 0;
    n = 0;
    uint64_t skipped = 0;
    uint16_t wa = 0, wb = 0;
    for (uint32_t a = 0x0080; a < 0x7F80; a++) {
        for (uint32_t b = 0x0080; b < 0x7F80; b++) {
            uint16_t r = bf16_mul((uint16_t) a, (uint16_t) b);
            if (!is_normal(r)) {
                skipped++;
                continue;
            }
            double exact = val[a] * val[b];
            double err = fabs(exact - val[r]) / exact;
            n++;
            if (err > worst) {
                worst = err;
                wa = (uint16_t) a;
                wb = (uint16_t) b;
            }
        }
    }
    printf(
        "multiply:    worst %.4f%% at 0x%04x * 0x%04x -> 0x%04x, "
        "%llu pairs, %llu skipped (overflow or underflow)\n",
        worst * 100, wa, wb, bf16_mul(wa, wb), (unsigned long long) n,
        (unsigned long long) skipped);

    /* Square root: every positive normal input. */
    double over = 0, under = 0;
    uint16_t at_over = 0, at_under = 0;
    n = 0;
    for (uint32_t a = 0x0080; a < 0x7F80; a++) {
        uint16_t r = bf16_sqrt((uint16_t) a);
        double exact = sqrt(val[a]);
        double err = (val[r] - exact) / exact;
        n++;
        if (err > over) {
            over = err;
            at_over = (uint16_t) a;
        }
        if (err < under) {
            under = err;
            at_under = (uint16_t) a;
        }
    }
    printf(
        "square root: worst above %.4f%% at 0x%04x, worst below %.4f%% "
        "at 0x%04x, %llu inputs\n",
        over * 100, at_over, -under * 100, at_under, (unsigned long long) n);
    return 0;
}
