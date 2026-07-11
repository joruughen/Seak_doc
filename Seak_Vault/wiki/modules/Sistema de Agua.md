---
type: module
path: "Scenes/Water.gd + Shaders/Water2.gdshader + Shaders/Water2.tres"
status: active
language: gdscript, gdshader
purpose: "Plano de agua: desplazamiento de olas en GPU + consulta de altura en CPU para la física"
depends_on: []
used_by: ["Scenes/Cube.gd", "Scenes/World.tscn"]
tags: [module, water, shader, noise]
created: 2026-07-11
updated: 2026-07-11
---

# Sistema de Agua

`MeshInstance3D` con `PlaneMesh` de 200×200 unidades y 200×200 subdivisiones (~80k vértices), material `Water2.tres`, script `Water.gd`.

## Dos mitades del sistema

1. **GPU (shader)**: `vertex()` desplaza `VERTEX.y` muestreando una `NoiseTexture2D` (FastNoiseLite, seamless). `fragment()` hace color por profundidad (ley de Beer), espuma en bordes por depth-texture, fresnel y normal maps animados. Ver [[Shader de Agua]].
2. **CPU (`Water.gd`)**: en `_ready()` extrae la imagen seamless 512×512 del ruido y los parámetros del material; `get_height(world_pos)` replica la fórmula del vertex shader con `Image.get_pixelv()`. Es la API que consume [[Cube Flotante]] para la boyancia. Ver [[Sincronización CPU-GPU de Olas]].

## Hallazgo clave (2026-07-11)

> [!key-insight] El material no usa el archivo .gdshader
> `Water2.tres` incrusta un **shader antiguo como sub-recurso** (con uniforms `wave_time`/`wave_speed` que `Water.gd` sí usa). El archivo `Shaders/Water2.gdshader` es una versión más nueva (fix de depth para GL Compatibility) pero está **huérfano**: usa `TIME` de GPU y no tiene `wave_speed`, así que si se conectara tal cual, `Water.gd` fallaría al leer parámetros y la boyancia quedaría desincronizada.

## Parámetros relevantes (en `Water2.tres`)

| Uniform | Valor | Rol |
|---|---|---|
| `noise_scale` | 10.0 | escala XZ del ruido |
| `height_scale` | 0.2 | amplitud de ola |
| `wave_speed` | 7.0 | velocidad de scroll del ruido |
| `wave_time` | actualizado por CPU | reloj compartido CPU-GPU |

Relacionado: [[Escena World]], [[Físicas de Flotabilidad]].
