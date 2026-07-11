---
type: decision
status: done
date: 2026-07-11
owner: Claude + Jorge
context: "El material Water2.tres incrustaba un shader viejo; Water2.gdshader estaba huérfano; las olas se veían mecánicas (una sola octava scrolleada)"
tags: [decision, shader, water]
created: 2026-07-11
updated: 2026-07-11
---

# ADR-001 — Refactor del Shader de Agua

## Problema

1. **Shader duplicado**: `Water2.tres` incrustaba una versión antigua como sub-recurso; el archivo `Water2.gdshader` (con el fix de depth para GL Compatibility) estaba huérfano.
2. **Olas mecánicas**: una sola muestra de ruido scrolleada en una dirección — toda la superficie "se deslizaba" rígidamente, sin interferencia entre frentes.
3. **Reloj desincronizado**: el `.gdshader` usaba `TIME` (GPU) mientras `Water.gd` acumulaba su propio `time` (CPU) para la boyancia.

## Decisión

**Consolidar en `Water2.gdshader`** (el `.tres` ahora lo referencia como `ext_resource`) con un nuevo algoritmo de olas:

- **Dos octavas de ruido** con direcciones cruzadas (`(1, 0.35)` y `(-0.55, 1)`), escalas no múltiplos (`10.0` y `5.3`) y velocidades distintas (factor `1.31`) → interferencia orgánica sin patrones repetitivos.
- **Crestas afiladas**: `pow(h, wave_sharpness=1.6)` afila picos y aplana valles (perfil de ola real, no senoide).
- **Normales por diferencias finitas** en el vertex → la luz sigue la forma de la ola (antes la iluminación de la geometría era plana).
- **Espuma en crestas**: `smoothstep(0.82, 1.0, height)` suma espuma donde la ola es alta, además de la espuma de borde por depth.
- **Reloj compartido**: todo el desplazamiento usa el uniform `wave_time` (seteado por `Water.gd` cada frame). `TIME` solo queda para el scroll de normal maps (puramente visual).

En `Water.gd`: `_wave_height()` es el **gemelo exacto** de `wave_height()` del shader, y `_sample_noise()` hace **muestreo bilineal** con wrap (antes `get_pixelv` nearest → boyancia con escalones). Ver [[Sincronización CPU-GPU de Olas]].

## Consecuencias

- Un solo shader que mantener; el inspector de Godot muestra los nuevos parámetros (`wave_blend`, `wave_sharpness`, `noise_scale2`).
- Regla de mantenimiento: **cambiar la fórmula del shader exige cambiar `_wave_height()` en `Water.gd`** (comentado en ambos archivos).
- Validado: import headless de Godot 4.6 sin errores + 120 frames de runtime limpios.

Relacionado: [[Shader de Agua]], [[Sistema de Agua]], [[ADR-002 Estabilización Player-Cube]].
