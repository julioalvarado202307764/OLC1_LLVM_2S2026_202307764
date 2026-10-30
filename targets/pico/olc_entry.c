#include "pico/stdlib.h"
#if OLC_USB_STDIO
#include "pico/stdio_usb.h"
#endif

extern int olc_program(void);

int main(void)
{
    stdio_init_all();  /* UART o USB CDC, segun el modo de CMake. */

#if defined(PICO_DEFAULT_LED_PIN)
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
    gpio_put(PICO_DEFAULT_LED_PIN, 1);
#endif

#if OLC_USB_STDIO
    /* Esperar a que la terminal USB CDC se abra (DTR activo).
       Mientras tanto, el LED permanece encendido como indicador de arranque. */
    while (!stdio_usb_connected()) {
        sleep_ms(50);
    }
    sleep_ms(300); /* Reducir riesgo de perder el primer mensaje. */
#endif
    (void)olc_program();

    /* Parpadea una vez por segundo al regresar del programa compilado. */
    while (true) {
#if defined(PICO_DEFAULT_LED_PIN)
        gpio_put(PICO_DEFAULT_LED_PIN, 1);
#endif
        sleep_ms(250);
#if defined(PICO_DEFAULT_LED_PIN)
        gpio_put(PICO_DEFAULT_LED_PIN, 0);
#endif
        sleep_ms(750);
    }
}