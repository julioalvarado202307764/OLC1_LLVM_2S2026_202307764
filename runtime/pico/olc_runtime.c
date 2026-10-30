#include "pico/stdlib.h"
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
/* Implementa la instruccion fuente "blink;" para la Pico original.
   ABI: void olc_led_blink(void), sin argumentos ni conversiones. */
#ifndef PICO_DEFAULT_LED_PIN
#error "Se requiere una placa con PICO_DEFAULT_LED_PIN"
#endif
void olc_led_blink(void)
{
    const uint pin = PICO_DEFAULT_LED_PIN;
    gpio_init(pin);
    gpio_set_dir(pin, GPIO_OUT);
    for (;;) {
        gpio_put(pin, true);
        sleep_ms(250);
        gpio_put(pin, false);
        sleep_ms(750);
    }
}