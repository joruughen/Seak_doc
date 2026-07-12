---
type: meta
title: "Hot Cache"
updated: 2026-07-12T18:00:00
---

# Recent Context

## Last Updated
2026-07-12. Fase 1 completada + varios fixes de estabilidad. Diagnosticado (no arreglado, diferido por decisión del usuario) un riesgo bloqueante de físicas Player↔Cube para Fase 2/3.

## Key Recent Facts
- **Fase 0 ✅ y Fase 1 ✅ completadas.** Próxima: Fase 2 (Unión Dinámica de Objetos — BoatManager, ConnectionGraph).
- Fase 1 ([[ADR-003 Sistema de Nado, Estamina e Interacción]]): máquina de estados `NORMAL/SWIMMING/CLINGING`; `PlayerStats.gd` (hp/estamina/hambre, escalón hambre→estamina 100/80/50/30/10%); `DebugHUD.gd`; agarre por "mano cinemática" con excepción de colisión jugador↔objeto cargado; empuje sostenido activo; salto cuesta estamina.
- **⚠️ Riesgo bloqueante anotado (no resuelto)**: la colisión física nativa Godot/Jolt entre CharacterBody3D y un RigidBody3D forzado por boyancia (el Cube) es inestable bajo movimiento errático del jugador — confirmado con 3 tests aislados headless (ver [[Análisis Técnico Prototipo SeaK]] riesgo 5). El fix correcto (sistema propio de "montar plataforma" sin colisión física directa, raycast + tracking manual) se difiere a Fase 3, anotado como tarea explícita en [[Roadmap Prototipo SeaK]].
- Mejoras incrementales SÍ aplicadas y activas en `Player.gd` (ayudan pero no resuelven el caso adversarial de fondo): `weight_damping`, suavizado del punto de apoyo (`_weight_offsets`), remoción del gate por estado SWIMMING en `_interact_with_rigid_bodies` (evita resonancia con el propio rebote del bote), excepción de colisión jugador↔objeto cargado.
- Arquitectura de diseño completa en [[Análisis Técnico Prototipo SeaK]]; fundaciones de físicas/shader en [[ADR-001 Refactor del Shader de Agua]] y [[ADR-002 Estabilización Player-Cube]].

## Recent Changes
- Created: [[ADR-003 Sistema de Nado, Estamina e Interacción]]
- Updated: [[Análisis Técnico Prototipo SeaK]] (riesgo 5 nuevo), [[Roadmap Prototipo SeaK]] (Fase 1 completa + tarea bloqueante en Fase 3), [[Player Controller]], [[index]], [[log]]
- Código: `Scripts/Player.gd` (nado/estamina/agarre + damping/smoothing de peso), `Scripts/PlayerStats.gd`, `Scripts/DebugHUD.gd`, `Scenes/World.tscn`, `project.godot`

## Active Threads
- Siguiente paso normal: **Fase 2 del [[Roadmap Prototipo SeaK]]** — `PieceData`, modo construcción FPS, génesis/fusión de `BoatManager`.
- **Antes o durante Fase 3**: resolver el riesgo bloqueante de colisión Player↔bote (sistema de montar plataforma) — no bloquea la Fase 2 (que se prueba en tierra, sin agua), pero sí bloquea probar navegación real con el jugador parado en un bote terminado.
- Pendiente de prueba manual del usuario en el editor: Fase 1 completa, refactor de Fase 0.
- Grafo Graphify no re-corrido tras esta fase — pendiente si el usuario lo pide.
