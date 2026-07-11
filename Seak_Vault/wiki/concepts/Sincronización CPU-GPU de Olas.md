---
type: concept
status: developing
purpose: "Patrón: la física necesita leer la misma altura de ola que la GPU dibuja"
tags: [concept, physics, shader, sync]
created: 2026-07-11
updated: 2026-07-11
---

# Sincronización CPU-GPU de Olas

La GPU desplaza los vértices del agua, pero la física (boyancia de [[Cube Flotante]]) corre en CPU y necesita saber la altura de la ola en cualquier punto XZ. El patrón de SeaK:

1. El ruido es una `NoiseTexture2D` **seamless**; `Water.gd` extrae la misma imagen con `noise.get_seamless_image(512, 512)`.
2. `get_height(world_pos)` reconstruye la UV exacta del vertex shader (`wrapf` para el tiling) y lee el píxel con `Image.get_pixelv()`.
3. **El reloj debe ser compartido**: la CPU acumula `time` y lo sube como uniform `wave_time`; el shader debe usar `wave_time`, **no** `TIME` (el reloj interno de GPU arranca con el engine, no con la escena, y no es consultable desde GDScript).

## Regla de oro

> [!key-insight]
> Cada término de la fórmula de desplazamiento del vertex shader debe tener su gemelo exacto en `get_height()`: misma UV, mismo scroll, mismas octavas, misma no-linealidad (`pow`), mismo `height_scale`. Un solo término desincronizado = balsa flotando sobre una ola invisible.

## Bug pre-refactor

`Water2.gdshader` usaba `TIME * time_scale` mientras `Water.gd` usaba `time * wave_speed` con su propio acumulador → offset y velocidad distintos. Además `Water.gd` leía `wave_speed`, uniform que solo existía en el shader viejo incrustado en `Water2.tres`.

Relacionado: [[Shader de Agua]], [[Sistema de Agua]], [[Físicas de Flotabilidad]].
