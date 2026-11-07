#include "bf16.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exp = (f32bits >> 23) & 0xFF;
    if (exp == 0xFF)
        return (uint16_t) (f32bits >> 16);

    uint32_t lsb = (f32bits >> 16) & 1;
    f32bits += 0x7FFF + lsb;

    return (uint16_t) (f32bits >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sign = (a ^ b) & 0x8000;
    uint32_t ea = (a >> 7) & 0xFF, eb = (b >> 7) & 0xFF;
    uint32_t ma = a & 0x7F, mb = b & 0x7F;

    if (ea == 0xFF) {
        if (ma != 0)
            return a;
        if ((b & 0x7FFF) == 0)
            return 0x7FC0;
        else
            return sign | 0x7F80;
    }
    if (eb == 0xFF) {
        if (mb != 0)
            return b;
        if ((a & 0x7FFF) == 0)
            return 0x7FC0;
        else
            return sign | 0x7F80;
    }
    if ((a & 0x7FFF) == 0 || (b & 0x7FFF) == 0)
        return sign;

    int32_t adj = 0;
    if (ea == 0) {
        while ((ma & 0x80) == 0) {
            ma <<= 1;
            adj -= 1;
        }
        ea = 1;
    } else {
        ma |= 0x80;
    }
    if (eb == 0) {
        while ((mb & 0x80) == 0) {
            mb <<= 1;
            adj -= 1;
        }
        eb = 1;
    } else {
        mb |= 0x80;
    }

    uint32_t prod = ma * mb;
    int32_t e = (int32_t) ea + (int32_t) eb - 127 + adj;
    uint32_t mant;
    if ((prod & 0x8000) != 0) {
        mant = (prod >> 8) & 0x7F;
        e += 1;
    } else {
        mant = (prod >> 7) & 0x7F;
    }

    if (e >= 0xFF)
        return sign | 0x7F80;

    if (e <= 0) {
        if (e < -6)
            return sign;
        mant >>= (1 - e);
        e = 0;
    }

    return sign | (e << 7) | mant;
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t sign = (a >> 15) & 1, exp = (a >> 7) & 0xFF, mant = a & 0x7F;

    if (exp == 0xFF) {
        if (mant != 0)
            return a;
        if (sign)
            return 0x7FC0;
        else
            return a;
    }
    if (exp == 0 && mant == 0)
        return 0x0000;
    if (sign)
        return 0x7FC0;
    if (exp == 0)
        return 0x0000;

    int32_t e = (int32_t) exp - 127;
    uint32_t m = 0x80 | mant;

    int32_t new_exp;
    if ((e & 1) != 0) {
        m <<= 1;
        new_exp = (e >> 1) + 127;
    } else {
        new_exp = (e >> 1) + 127;
    }

    uint32_t low = 90, high = 256, result = 128;
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        if (((mid * mid) / 128) <= m) {
            result = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (result >= 256) {
        result >>= 1;
        new_exp += 1;
    } else if (result < 128) {
        while (result < 128 && new_exp > 1) {
            result <<= 1;
            new_exp -= 1;
        }
    }

    if (new_exp >= 0xFF)
        return 0x7F80;
    if (new_exp <= 0)
        return 0x0000;
    return (new_exp << 7) | (result & 0x7F);
}
