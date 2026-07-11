---
type: meta
title: "Hot Cache"
updated: 2026-07-11T14:15:00
---

# Recent Context

## Last Updated
2026-07-11. Refactor completo de shaders y físicas del proyecto Godot SeaK, validado con Godot 4.6 headless. Pendiente: correr Graphify sobre la bóveda.

## Key Recent Facts
- SeaK: Godot 4.6, GL Compatibility, Jolt Physics. Player (CharacterBody3D), Water (plano 200×200 con shader de olas), Cube (RigidBody3D balsa con 9 sondas de boyancia).
- **Resuelto** ([[ADR-001 Refactor del Shader de Agua]]): `Water2.gdshader` reescrito con 2 octavas de ruido cruzadas + crestas afiladas + normales por diferencias finitas; `Water2.tres` ahora referencia el archivo (ya no hay shader duplicado); reloj `wave_time` compartido CPU↔GPU.
- **Resuelto** ([[ADR-002 Estabilización Player-Cube]]): escala movida del RigidBody3D a las shapes; masa Cube 5→200 kg; boyancia normalizada por masa + amortiguada por sonda; Player transfiere peso/empuje explícito al RigidBody en vez de depenetración infinita.
- Validado: `--check-only` en los 3 scripts, import headless sin errores, 120 frames de runtime limpios.

## Recent Changes
- Created: [[overview]], [[Player Controller]], [[Cube Flotante]], [[Sistema de Agua]], [[Escena World]], [[Físicas de Flotabilidad]], [[Shader de Agua]], [[Sincronización CPU-GPU de Olas]], [[CharacterController]], [[ADR-001 Refactor del Shader de Agua]], [[ADR-002 Estabilización Player-Cube]]
- Updated: `Shaders/Water2.gdshader`, `Shaders/Water2.tres`, `Scenes/Water.gd`, `Scenes/Cube.gd`, `Scripts/Player.gd`, `Scenes/World.tscn` (código fuente del proyecto Godot, no la bóveda)

## Active Threads
- Falta correr Graphify sobre `Seak_Vault` para interconectar los conceptos nuevos (Físicas de Flotabilidad, Shaders de Agua, CharacterController) en el grafo de conocimiento.
- Pendiente de prueba manual del usuario en el editor de Godot (los cambios se validaron headless, no visualmente).
