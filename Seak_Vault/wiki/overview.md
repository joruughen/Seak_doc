---
type: meta
title: "SeaK — Resumen de Arquitectura"
status: active
created: 2026-07-11
updated: 2026-07-11
tags: [overview, godot, architecture]
---

# SeaK — Resumen de Arquitectura

SeaK es un juego en **Godot 4.6** (renderer GL Compatibility, motor de física **Jolt**) centrado en una simulación de océano: un plano de agua con oleaje procedural por shader, un cubo/balsa flotante con física de boyancia por sondas, y un jugador en primera persona.

## Componentes principales

| Componente | Nodo | Script | Nota |
|---|---|---|---|
| Jugador | `CharacterBody3D` | `Scripts/Player.gd` | [[Player Controller]] |
| Agua (visual + altura) | `MeshInstance3D` (PlaneMesh 200×200, 200 subdivisiones) | `Scenes/Water.gd` + `Shaders/Water2.gdshader` | [[Sistema de Agua]] |
| Balsa flotante | `RigidBody3D` (masa 5, 9 sondas) | `Scenes/Cube.gd` | [[Cube Flotante]] |
| Mundo | `Node3D` raíz | `Scenes/World.tscn` | [[Escena World]] |

## Cómo se conecta todo

1. El shader del agua desplaza vértices en GPU usando una textura de ruido (FastNoiseLite seamless): [[Shader de Agua]].
2. `Water.gd` replica esa misma fórmula en CPU (`get_height()`) muestreando la misma imagen de ruido: [[Sincronización CPU-GPU de Olas]].
3. `Cube.gd` consulta `get_height()` en 9 sondas (`Marker3D`) y aplica fuerza de boyancia proporcional a la profundidad: [[Físicas de Flotabilidad]].
4. El Player camina/salta sobre la balsa: interacción `CharacterBody3D` ↔ `RigidBody3D`: [[CharacterController]].

## Estado (actualizado 2026-07-11)

> [!key-insight] Refactor completado
> Los 5 problemas detectados en el análisis inicial fueron corregidos y validados con Godot 4.6 headless (check de scripts + import + 120 frames de runtime):
> 1. ~~El material `Water2.tres` NO usa `Water2.gdshader`~~ → consolidado, ver [[ADR-001 Refactor del Shader de Agua]].
> 2. ~~Desincronización CPU-GPU~~ → reloj `wave_time` compartido, ver [[Sincronización CPU-GPU de Olas]].
> 3. ~~Escala no uniforme en RigidBody3D~~ → escala movida a las shapes, ver [[ADR-002 Estabilización Player-Cube]].
> 4. ~~Boyancia sin amortiguación~~ → resorte-amortiguador por sonda, ver [[Físicas de Flotabilidad]].
> 5. ~~Player↔Cube sin gestión de masas~~ → transferencia de peso + empuje acotado, ver [[CharacterController]].

Pendiente: prueba visual/manual del usuario en el editor de Godot. Detalle completo en [[ADR-001 Refactor del Shader de Agua]] y [[ADR-002 Estabilización Player-Cube]].
