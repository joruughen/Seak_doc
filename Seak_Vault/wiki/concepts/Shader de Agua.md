---
type: concept
status: developing
purpose: "Técnicas del shader de agua: desplazamiento por ruido, ley de Beer, espuma por depth, fresnel"
tags: [concept, shader, water, glsl]
created: 2026-07-11
updated: 2026-07-11
---

# Shader de Agua

Shader `spatial` sobre un `PlaneMesh` subdividido. Técnicas presentes en `Water2.gdshader`:

## Vertex — desplazamiento de olas

Pre-refactor: **una sola muestra** de `NoiseTexture2D` scrolleada en una dirección:

```glsl
height = texture(wave, world_pos.xz / noise_scale + TIME * time_scale).r;
VERTEX.y += height * height_scale;
```

Limitaciones visuales: la superficie entera "se desliza" rígidamente en una dirección (patrón evidente), sin interferencia entre frentes de ola ni variación de frecuencia → aspecto artificial.

Mejora estándar: **sumar 2+ octavas de ruido** scrolleadas en direcciones y escalas distintas (interferencia), afilar crestas con `pow()`, y recalcular la normal del vértice por diferencias finitas. Requisito duro de SeaK: la fórmula debe ser **replicable en CPU** por `Water.gd.get_height()` ([[Sincronización CPU-GPU de Olas]]) — eso descarta técnicas solo-GPU como FFT o domain warping con derivadas analíticas.

## Fragment

- **Profundidad lineal** desde `hint_depth_texture`, con conversión `raw_depth * 2 − 1` para el renderer GL Compatibility (OpenGL usa NDC −1..1 en Z).
- **Ley de Beer**: `depth_blend = exp(−depth_diff · beers_law)` mezcla `color_deep` ↔ `color_shallow` y sus alphas.
- **Espuma de borde**: `1 − smoothstep(0, edge_scale, depth_diff)` pinta blanco donde el agua toca geometría.
- **Fresnel** (potencia 5) mezcla albedo interior ↔ color de superficie/cielo.
- **Normal maps duales** scrolleados en direcciones distintas y mezclados 50/50 para el detalle fino.

## Estado del recurso

> [!contradiction] Duplicación de shaders
> `Water2.tres` incrusta una versión antigua del shader; `Water2.gdshader` (archivo) tiene el fix de depth pero está huérfano y usa `TIME` en el vertex. Consolidar en el archivo y drivearlo con `wave_time` (uniform CPU) es parte del refactor.

Relacionado: [[Sistema de Agua]], [[Sincronización CPU-GPU de Olas]].
