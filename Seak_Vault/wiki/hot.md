---
type: meta
title: "Hot Cache"
updated: 2026-07-12T22:00:00
---

# Recent Context

## Last Updated
2026-07-12. Proyecto movido a `F:\Claude_Vaults\Seak_doc\seak`. Fase 2 Grupo 1 completado (PieceData + LoosePiece + 7 objetos de prueba). Tres fixes de agarre/física encima: (1) pitch de cámara -80° + agachado nuevo, (2) `carry_max_mass` 15→30 (Chapa 25kg nunca pasaba el umbral), (3) piezas planas atravesaban la isla al lanzarlas — colisión cóncava del CSGBox3D reemplazada por BoxShape3D convexo + CCD en las piezas. Sigue diferido (sin cambios) el riesgo bloqueante de físicas Player↔Cube para Fase 2/3.

## Key Recent Facts
- **Ruta del proyecto Godot: `F:\Claude_Vaults\Seak_doc\seak`** (ya no en OneDrive/C:).
- **Fase 0 ✅, Fase 1 ✅, Fase 2 Grupo 1 ✅ (datos base).** Próximo: Fase 2 Grupo 2 (núcleo de soldadura — BoatManager, ConnectionGraph, masa/COM).
- Fase 2 Grupo 1 ([[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]]): `PieceData` (Resource, flags bitmask), `LoosePiece` (RigidBody3D+PieceData), 7 `.tres` con los valores exactos de [[Análisis Técnico Prototipo SeaK]] §6, instanciados en `World.tscn`.
- **Fix de cámara/agachado** (mismo ADR): pitch `[-80°,60°]` (antes `[-40°,60°]`, no era una decisión de diseño, solo el valor del template nunca reconsiderado) + agachado nuevo (`crouch`, Ctrl) que baja la cámara 0.55m. Sin esto, Palé (y≈0.034 en reposo) y Chapa (y≈0.002) eran casi imposibles de apuntar con el raycast de agarre.
- **Fix 2, mismo ADR**: aun con cámara/agachado arreglados, la Chapa (25 kg) seguía sin poder agarrarse — no era colisión, era el umbral `carry_max_mass` (Fase 1, tuneado solo para Barril/Cube). Subido de 15 a 30: las 7 piezas del prototipo quedan agarrables, el Cube (200) sigue push-only.
- **Fix 3, mismo ADR**: piezas planas (Chapa, Puerta) atravesaban la isla de prueba al lanzarlas con fuerza. Causa: `CSGBox3D.use_collision` genera colisión cóncava (trimesh), propensa a tunneling con cuerpos rápidos/delgados. Fix: `IslandFloor` nuevo (`StaticBody3D`+`BoxShape3D` convexo) reemplaza esa colisión; `continuous_cd=true` en `LoosePiece` como refuerzo.
- Fase 1 ([[ADR-003 Sistema de Nado, Estamina e Interacción]]): máquina de estados `NORMAL/SWIMMING/CLINGING`; `PlayerStats.gd` (hp/estamina/hambre, escalón hambre→estamina 100/80/50/30/10%); `DebugHUD.gd`; agarre por "mano cinemática" con excepción de colisión jugador↔objeto cargado; empuje sostenido activo; salto cuesta estamina.
- **⚠️ Riesgo bloqueante anotado (no resuelto)**: la colisión física nativa Godot/Jolt entre CharacterBody3D y un RigidBody3D forzado por boyancia (el Cube) es inestable bajo movimiento errático del jugador — confirmado con 3 tests aislados headless (ver [[Análisis Técnico Prototipo SeaK]] riesgo 5). El fix correcto (sistema propio de "montar plataforma" sin colisión física directa, raycast + tracking manual) se difiere a Fase 3, anotado como tarea explícita en [[Roadmap Prototipo SeaK]].
- Mejoras incrementales SÍ aplicadas y activas en `Player.gd` (ayudan pero no resuelven el caso adversarial de fondo): `weight_damping`, suavizado del punto de apoyo (`_weight_offsets`), remoción del gate por estado SWIMMING en `_interact_with_rigid_bodies` (evita resonancia con el propio rebote del bote), excepción de colisión jugador↔objeto cargado.
- **Fix aparte, ya resuelto**: el objeto cargado se quedaba atrás al caminar/girar la cámara rápido (`_update_held_body` dividía por `delta`, exigiendo velocidades enormes). Reemplazado por control proporcional (`to_target * carry_catch_up_rate`); rezago prácticamente eliminado, ver [[ADR-003 Sistema de Nado, Estamina e Interacción]].
- Arquitectura de diseño completa en [[Análisis Técnico Prototipo SeaK]]; fundaciones de físicas/shader en [[ADR-001 Refactor del Shader de Agua]] y [[ADR-002 Estabilización Player-Cube]].

## Recent Changes
- Created: [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]]
- Updated: [[Roadmap Prototipo SeaK]] (Grupo 1 de Fase 2 marcado), [[Player Controller]] (cámara/agachado), [[log]], [[hot]], `CLAUDE.md` (ruta del proyecto)
- Código: `Scripts/PieceData.gd` (nuevo), `Scenes/LoosePiece.gd`+`.tscn` (nuevo), `Resources/Pieces/*.tres` (7 nuevos), `Scenes/World.tscn` (7 piezas instanciadas), `Scripts/Player.gd` (pitch -80°, agachado), `project.godot` (acción `crouch`)

## Active Threads
- Siguiente paso normal: **Fase 2 Grupo 2 del [[Roadmap Prototipo SeaK]]** — núcleo de soldadura: `BoatManager`, `ConnectionGraph`, recalcular masa/COM (solo masa+COM custom, nunca inercia — godot#78750).
- **Antes o durante Fase 3**: resolver el riesgo bloqueante de colisión Player↔bote (sistema de montar plataforma) — no bloquea la Fase 2 (que se prueba en tierra, sin agua), pero sí bloquea probar navegación real con el jugador parado en un bote terminado.
- Pendiente de prueba manual del usuario en el editor: Fase 2 Grupo 1 + fix de cámara/agachado (todo lo demás ya se probó en sesiones previas).
- Grafo Graphify no re-corrido tras esta fase — pendiente si el usuario lo pide.
