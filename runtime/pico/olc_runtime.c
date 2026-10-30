#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

/* ARM Cortex-M0+: ABI entero i32, compatible con la declaracion LLVM. */
void print_i32(int32_t valor)
{
    printf("%" PRId32 "\r\n", valor);
    fflush(stdout);
}

/* La firma es double (64 bits); no hay conversion implicita a float. */
void print_f64(double valor)
{
    printf("%.17g\r\n", valor);
    fflush(stdout);
}