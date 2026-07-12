# Graph Report - F:/Claude_Vaults/Seak_doc/Seak_Vault  (2026-07-11)

## Corpus Check
- Corpus is ~8,312 words - fits in a single context window. You may not need a graph.

## Summary
- 39 nodes · 147 edges · 8 communities (7 shown, 1 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.75)
- Token cost: 0 input · 90,236 output

## Community Hubs (Navigation)
- Modulos del Juego y Motor
- Meta del Wiki y Decisiones
- Arquitectura del Bote Modular
- Supervivencia y Navegacion
- Shader y Olas
- Character-RigidBody Controller
- Nota de Bienvenida

## God Nodes (most connected - your core abstractions)
1. `Análisis Técnico Prototipo SeaK` - 23 edges
2. `Roadmap Prototipo SeaK` - 21 edges
3. `SeaK — Resumen de Arquitectura` - 17 edges
4. `Índice Maestro — SeaK Wiki` - 17 edges
5. `Log de Operaciones` - 17 edges
6. `Físicas de Flotabilidad` - 14 edges
7. `ADR-002 — Estabilización Player-Cube` - 14 edges
8. `Cube Flotante (Scenes/Cube.gd)` - 14 edges
9. `CharacterController` - 13 edges
10. `Sincronización CPU-GPU de Olas` - 12 edges

## Surprising Connections (you probably didn't know these)
- `CLAUDE.md — SeaK Wiki Config` --references--> `SeaK — Resumen de Arquitectura`  [EXTRACTED]
  CLAUDE.md → wiki/overview.md
- `CLAUDE.md — SeaK Wiki Config` --references--> `Hot Cache`  [EXTRACTED]
  CLAUDE.md → wiki/hot.md
- `CLAUDE.md — SeaK Wiki Config` --references--> `Índice Maestro — SeaK Wiki`  [EXTRACTED]
  CLAUDE.md → wiki/index.md
- `CLAUDE.md — SeaK Wiki Config` --references--> `Log de Operaciones`  [EXTRACTED]
  CLAUDE.md → wiki/log.md
- `Índice de Conceptos` --references--> `CharacterController`  [EXTRACTED]
  wiki/concepts/_index.md → wiki/concepts/CharacterController.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Water Shader Refactor (ADR-001)** — wiki_decisions_adr_001_refactor_del_shader_de_agua, wiki_concepts_shader_de_agua, wiki_modules_sistema_de_agua, wiki_concepts_sincronizaci_n_cpu_gpu_de_olas [EXTRACTED 1.00]
- **Player-Cube Stabilization Fix (ADR-002)** — wiki_concepts_charactercontroller, wiki_concepts_f_sicas_de_flotabilidad, wiki_decisions_adr_002_estabilizaci_n_player_cube, wiki_modules_player_controller, wiki_modules_cube_flotante [EXTRACTED 1.00]
- **SeaK Wave Height Pipeline (GPU display to CPU buoyancy)** — wiki_concepts_shader_de_agua, wiki_modules_sistema_de_agua, wiki_concepts_sincronizaci_n_cpu_gpu_de_olas, wiki_modules_cube_flotante, wiki_concepts_f_sicas_de_flotabilidad [EXTRACTED 1.00]
- **Pipeline del Bote Modular (dato → física → rotura)** — wiki_design_an_lisis_t_cnico_prototipo_seak_boatmanager, wiki_design_an_lisis_t_cnico_prototipo_seak_connectiongraph, wiki_design_an_lisis_t_cnico_prototipo_seak_flotabilidad_modular, wiki_design_an_lisis_t_cnico_prototipo_seak_fragmentaci_n_bfs, wiki_design_an_lisis_t_cnico_prototipo_seak_loosepiece_attachedpiece [EXTRACTED 1.00]
- **Loop de Supervivencia y Muerte Asimétrica** — wiki_design_an_lisis_t_cnico_prototipo_seak_playerstats, wiki_design_an_lisis_t_cnico_prototipo_seak_n_ufrago_cr_tico, wiki_design_an_lisis_t_cnico_prototipo_seak_estatua_de_resurrecci_n [EXTRACTED 1.00]
- **Propulsión Emergente por apply_force(F, offset)** — wiki_design_an_lisis_t_cnico_prototipo_seak_rowingstation, wiki_design_an_lisis_t_cnico_prototipo_seak_pataleo_clinging, wiki_design_an_lisis_t_cnico_prototipo_seak_flotabilidad_modular, wiki_design_an_lisis_t_cnico_prototipo_seak_playerstats [INFERRED 0.85]

## Communities (8 total, 1 thin omitted)

### Community 0 - "Modulos del Juego y Motor"
Cohesion: 0.56
Nodes (9): Físicas de Flotabilidad, Índice de Módulos, Cube Flotante (Scenes/Cube.gd), Escena World (Scenes/World.tscn), Player Controller (Scripts/Player.gd), Sistema de Agua (Scenes/Water.gd + Shaders), SeaK — Resumen de Arquitectura, Godot 4.6 (+1 more)

### Community 1 - "Meta del Wiki y Decisiones"
Cohesion: 0.64
Nodes (8): CLAUDE.md — SeaK Wiki Config, Índice de Decisiones, ADR-001 — Refactor del Shader de Agua, ADR-002 — Estabilización Player-Cube, Índice de Diseño, Hot Cache, Índice Maestro — SeaK Wiki, Log de Operaciones

### Community 2 - "Arquitectura del Bote Modular"
Cohesion: 0.80
Nodes (6): Análisis Técnico Prototipo SeaK, BoatManager, ConnectionGraph, Flotabilidad Modular, Fragmentación por Componentes Conexas (BFS), LoosePiece / AttachedPiece

### Community 3 - "Supervivencia y Navegacion"
Cohesion: 0.67
Nodes (6): Estatua de Resurrección, Náufrago Crítico, Pataleo / Clinging, PlayerStats, RowingStation, Roadmap Prototipo SeaK

### Community 4 - "Shader y Olas"
Cohesion: 0.50
Nodes (5): Índice de Conceptos, Shader de Agua, Fresnel, Ley de Beer (Beer's Law), Sincronización CPU-GPU de Olas

### Community 5 - "Character-RigidBody Controller"
Cohesion: 0.67
Nodes (3): CharacterController, CharacterBody3D, RigidBody3D

## Knowledge Gaps
- **7 isolated node(s):** `Welcome (Obsidian Default Note)`, `CharacterBody3D`, `RigidBody3D`, `Ley de Beer (Beer's Law)`, `Fresnel` (+2 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Análisis Técnico Prototipo SeaK` connect `Arquitectura del Bote Modular` to `Modulos del Juego y Motor`, `Meta del Wiki y Decisiones`, `Supervivencia y Navegacion`, `Shader y Olas`, `Character-RigidBody Controller`?**
  _High betweenness centrality (0.189) - this node is a cross-community bridge._
- **Why does `Roadmap Prototipo SeaK` connect `Supervivencia y Navegacion` to `Modulos del Juego y Motor`, `Meta del Wiki y Decisiones`, `Arquitectura del Bote Modular`, `Shader y Olas`, `Character-RigidBody Controller`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Why does `SeaK — Resumen de Arquitectura` connect `Modulos del Juego y Motor` to `Meta del Wiki y Decisiones`, `Arquitectura del Bote Modular`, `Supervivencia y Navegacion`, `Shader y Olas`, `Character-RigidBody Controller`?**
  _High betweenness centrality (0.137) - this node is a cross-community bridge._
- **What connects `Welcome (Obsidian Default Note)`, `CharacterBody3D`, `RigidBody3D` to the rest of the system?**
  _7 weakly-connected nodes found - possible documentation gaps or missing edges._