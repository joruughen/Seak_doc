# SeaK Wiki: LLM Wiki

Mode: B (GitHub / Repository)
Purpose: Documentar la arquitectura, físicas y shaders del juego SeaK (Godot 4.6) — simulación de océano con flotabilidad, shaders de agua y controlador en primera persona.
Owner: Jorge Melgarejo
Created: 2026-07-11

## Codebase

Ruta del proyecto Godot: `F:\Claude_Vaults\Seak_doc\seak`

## Structure

```
Seak_Vault/
├── .raw/              # exports de código, logs, dumps (inmutables)
├── wiki/
│   ├── index.md       # catálogo maestro
│   ├── log.md         # registro cronológico (append-only, entradas nuevas arriba)
│   ├── hot.md         # hot cache (~500 palabras de contexto reciente)
│   ├── overview.md    # resumen ejecutivo de la arquitectura
│   ├── modules/       # una nota por script/escena mayor (Player, Cube, Water)
│   ├── concepts/      # conceptos técnicos (flotabilidad, shaders, sync CPU-GPU)
│   ├── decisions/     # decisiones de arquitectura y fixes aplicados (ADRs)
│   ├── design/        # diseño del juego: análisis técnico, roadmap por fases
│   └── flows/         # flujos: física por frame, pipeline de render del agua
└── CLAUDE.md
```

## Conventions

- Todas las notas usan frontmatter YAML: type, status, created, updated, tags (mínimo)
- Wikilinks en formato [[Nombre de Nota]]: los nombres de archivo son únicos, sin rutas
- .raw/ contiene fuentes: nunca modificarlas
- wiki/index.md es el catálogo maestro: actualizar en cada ingesta
- wiki/log.md es append-only: nunca editar entradas pasadas; las nuevas van ARRIBA

## Operations

- Ingest: Soltar fuente en .raw/, actualizar el grafo localmente desde PowerShell con `python -m graphify .`, y notificar a Claude.
- Query: Preguntar lo que sea — Claude DEBE leer primero los datos estructurados en `graphify-out/graph.json` para obtener el plano del proyecto. Queda prohibido ejecutar comandos automáticos de re-extracción (`/graphify` o similares) en la terminal.
- Lint: Decir "lint the wiki" para un health check de los wikilinks y el frontmatter.
