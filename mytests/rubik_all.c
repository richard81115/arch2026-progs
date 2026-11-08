/* Local measurement, not part of the graded harness: solve every state at
 * distance 11 and report the most expensive call. */
#include "bench.h"
#include "print.h"
#include "src/rubik/rubik.h"

#include "d11_states.h"

typedef int (*solve_fn)(const char *, char *, size_t);

static char buf[64];

static void scan(const char *name, solve_fn solve)
{
    uint64_t a = get_instret(), b = get_instret();
    uint64_t overhead = b - a, worst = 0, total = 0;
    unsigned worst_i = 0, over = 0, wrong = 0;
    for (unsigned i = 0; i < D11_COUNT; i++) {
        uint64_t t0 = get_instret();
        int n = solve(d11[i], buf, sizeof buf);
        uint64_t used = get_instret() - t0 - overhead;
        if (n != 11)
            wrong++;
        if (used > 7500000u)
            over++;
        total += used;
        if (used > worst) {
            worst = used;
            worst_i = i;
        }
    }
    bm_printf(
        "%s: worst %llu at %s, total %llu over %u states, "
        "%u above 7.5M, %u wrong lengths\n",
        name, worst, d11[worst_i], total, D11_COUNT, over, wrong);
}

int main(void)
{
    scan("c", rubik_solve);
    scan("asm", rubik_solve_asm);
    return 0;
}
