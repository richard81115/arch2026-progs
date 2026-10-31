#include "gcd.h"
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    uint32_t k = 0;

    while (a != 0 && b != 0) {
        if ((a & 1) == 0 && (b & 1) == 0) {
            a >>= 1;
            b >>= 1;
            k += 1;
            continue;
        } else if ((a & 1) == 1 && (b & 1) == 0) {
            b >>= 1;
            continue;
        } else if ((a & 1) == 0 && (b & 1) == 1) {
            a >>= 1;
            continue;
        } else {
            if (a > b)
                a -= b;
            else
                b -= a;
        }
    }

    if (a == 0)
        return (uint32_t) (b << k);
    else
        return (uint32_t) (a << k);
}
