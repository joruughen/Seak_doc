---
type: meta
title: "Log de Operaciones"
created: 2026-07-11
updated: 2026-07-11
tags: [log]
---

# Log

<!-- append-only: entradas nuevas ARRIBA -->

## 2026-07-11 — Refactor: shader de agua + estabilización física
- `Water2.gdshader` reescrito: 2 octavas de ruido cruzadas, crestas con `pow`, normales por diferencias finitas, espuma en crestas, reloj `wave_time` compartido con CPU. `Water2.tres` ahora referencia el archivo (shader incrustado eliminado).
- `Water.gd`: `_wave_height()` gemelo del shader + muestreo bilineal.
- `Cube.gd`: boyancia normalizada por masa con amortiguación vertical por sonda.
- `Player.gd`: transferencia de peso (`player_mass`) y empuje lateral acotado (`push_force`) contra RigidBody3D.
- `World.tscn`: escala no uniforme movida del RigidBody a las shapes; masa 5→200 kg; 9 sondas reposicionadas.
- Validación: `--check-only` OK en los 3 scripts, import headless sin errores, 120 frames de runtime limpios.
- Creadas: [[ADR-001 Refactor del Shader de Agua]], [[ADR-002 Estabilización Player-Cube]].

## 2026-07-11 — Scaffold + ingesta inicial del proyecto SeaK
- Scaffold del wiki (Modo B: Repositorio) en Seak_Vault.
- Ingesta del código fuente de `C:\Users\jotit\OneDrive\Documentos\GitHub\SeaK\seak`: `Player.gd`, `Cube.gd`, `Water.gd`, `Water2.gdshader`, `Water2.tres`, `World.tscn`, `project.godot`.
- Creadas: [[overview]], [[Player Controller]], [[Cube Flotante]], [[Sistema de Agua]], [[Escena World]], [[Físicas de Flotabilidad]], [[Shader de Agua]], [[Sincronización CPU-GPU de Olas]], [[CharacterController]].
- Flags: material `.tres` no usa `Water2.gdshader` (shader duplicado); escala no uniforme en RigidBody3D del Cube; boyancia sin amortiguación; desync de reloj CPU/GPU en olas.
