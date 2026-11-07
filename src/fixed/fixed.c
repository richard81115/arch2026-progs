#include <stdint.h>
#include <stdio.h>
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;
    while (b != 0) {
        uint32_t c = (a & b) << 1;
        a = a ^ b;
        b = c;
        passes += 1;
    }
    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a, ub = (uint32_t) b;
    uint32_t ah = ua >> 16, bh = ub >> 16;
    uint32_t al = ua & 0xFFFF, bl = ub & 0xFFFF;

    uint64_t p = ((uint64_t) (ah * bh) << 32) +
                 (((uint64_t) (ah * bl) + (uint64_t) (al * bh)) << 16) +
                 (uint64_t) (al * bl);

    if (a < 0) {
        p -= (uint64_t) ub << 32;
    }
    if (b < 0) {
        p -= (uint64_t) ua << 32;
    }

    p += 1u << 19;

    return (int32_t) (uint32_t) (p >> 20);
}
