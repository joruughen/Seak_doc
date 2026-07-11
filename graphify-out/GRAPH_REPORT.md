# Graph Report - F:/Claude_Vaults/Seak_doc/Seak_Vault  (2026-07-11)

## Corpus Check
- Corpus is ~4,726 words - fits in a single context window. You may not need a graph.

## Summary
- 26 nodes · 91 edges · 7 communities (6 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 90,835 output

## Community Hubs (Navigation)
- Decisiones y Meta del Wiki
- Fisicas y Shader de Agua
- Modulos del Juego
- Character-RigidBody Controller
- Arquitectura y Motor Godot
- Nota de Bienvenida

## God Nodes (most connected - your core abstractions)
1. `SeaK — Resumen de Arquitectura` - 16 edges
2. `Índice Maestro — SeaK Wiki` - 14 edges
3. `Hot Cache` - 13 edges
4. `Log de Operaciones` - 13 edges
5. `Físicas de Flotabilidad` - 12 edges
6. `Cube Flotante (Scenes/Cube.gd)` - 12 edges
7. `CharacterController` - 11 edges
8. `ADR-002 — Estabilización Player-Cube` - 11 edges
9. `Sistema de Agua (Scenes/Water.gd + Shaders)` - 11 edges
10. `Shader de Agua` - 10 edges

## Surprising Connections (you probably didn't know these)
- `SeaK Wiki — CLAUDE.md (Vault Config)` --references--> `Hot Cache`  [EXTRACTED]
  CLAUDE.md → wiki/hot.md
- `SeaK Wiki — CLAUDE.md (Vault Config)` --references--> `SeaK — Resumen de Arquitectura`  [EXTRACTED]
  CLAUDE.md → wiki/overview.md
- `SeaK Wiki — CLAUDE.md (Vault Config)` --references--> `Índice Maestro — SeaK Wiki`  [EXTRACTED]
  CLAUDE.md → wiki/index.md
- `SeaK Wiki — CLAUDE.md (Vault Config)` --references--> `Log de Operaciones`  [EXTRACTED]
  CLAUDE.md → wiki/log.md
- `Índice de Conceptos` --references--> `CharacterController`  [EXTRACTED]
  wiki/concepts/_index.md → wiki/concepts/CharacterController.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **SeaK Wave Height Pipeline (GPU display to CPU buoyancy)** — wiki_concepts_shader_de_agua, wiki_modules_sistema_de_agua, wiki_concepts_sincronizaci_n_cpu_gpu_de_olas, wiki_modules_cube_flotante, wiki_concepts_f_sicas_de_flotabilidad [EXTRACTED 1.00]
- **Player-Cube Stabilization Fix (ADR-002)** — wiki_concepts_charactercontroller, wiki_concepts_f_sicas_de_flotabilidad, wiki_decisions_adr_002_estabilizaci_n_player_cube, wiki_modules_player_controller, wiki_modules_cube_flotante [EXTRACTED 1.00]
- **Water Shader Refactor (ADR-001)** — wiki_decisions_adr_001_refactor_del_shader_de_agua, wiki_concepts_shader_de_agua, wiki_modules_sistema_de_agua, wiki_concepts_sincronizaci_n_cpu_gpu_de_olas [EXTRACTED 1.00]

## Communities (7 total, 1 thin omitted)

### Community 0 - "Decisiones y Meta del Wiki"
Cohesion: 0.67
Nodes (6): SeaK Wiki — CLAUDE.md (Vault Config), Índice de Decisiones, ADR-001 — Refactor del Shader de Agua, ADR-002 — Estabilización Player-Cube, Índice Maestro — SeaK Wiki, Log de Operaciones

### Community 1 - "Fisicas y Shader de Agua"
Cohesion: 0.47
Nodes (6): Índice de Conceptos, Físicas de Flotabilidad, Shader de Agua, Fresnel, Ley de Beer (Beer's Law), Sincronización CPU-GPU de Olas

### Community 2 - "Modulos del Juego"
Cohesion: 0.87
Nodes (6): Hot Cache, Índice de Módulos, Cube Flotante (Scenes/Cube.gd), Escena World (Scenes/World.tscn), Player Controller (Scripts/Player.gd), Sistema de Agua (Scenes/Water.gd + Shaders)

### Community 3 - "Character-RigidBody Controller"
Cohesion: 0.67
Nodes (3): CharacterController, CharacterBody3D, RigidBody3D

### Community 4 - "Arquitectura y Motor Godot"
Cohesion: 0.67
Nodes (3): SeaK — Resumen de Arquitectura, Godot 4.6, Jolt Physics

## Knowledge Gaps
- **7 isolated node(s):** `Welcome (Obsidian Default Note)`, `CharacterBody3D`, `RigidBody3D`, `Ley de Beer (Beer's Law)`, `Fresnel` (+2 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SeaK — Resumen de Arquitectura` connect `Arquitectura y Motor Godot` to `Decisiones y Meta del Wiki`, `Fisicas y Shader de Agua`, `Modulos del Juego`, `Character-RigidBody Controller`?**
  _High betweenness centrality (0.184) - this node is a cross-community bridge._
- **Why does `CharacterController` connect `Character-RigidBody Controller` to `Decisiones y Meta del Wiki`, `Fisicas y Shader de Agua`, `Modulos del Juego`, `Arquitectura y Motor Godot`?**
  _High betweenness centrality (0.155) - this node is a cross-community bridge._
- **Why does `Shader de Agua` connect `Fisicas y Shader de Agua` to `Decisiones y Meta del Wiki`, `Modulos del Juego`, `Arquitectura y Motor Godot`?**
  _High betweenness centrality (0.153) - this node is a cross-community bridge._
- **What connects `Welcome (Obsidian Default Note)`, `CharacterBody3D`, `RigidBody3D` to the rest of the system?**
  _7 weakly-connected nodes found - possible documentation gaps or missing edges._