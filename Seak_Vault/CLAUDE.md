# SeaK Wiki: LLM Wiki

Mode: B (GitHub / Repository)
Purpose: Documentar la arquitectura, físicas y shaders del juego SeaK (Godot 4.6) — simulación de océano con flotabilidad, shaders de agua y controlador en primera persona.
Owner: Jorge Melgarejo
Created: 2026-07-11

## Codebase

Ruta del proyecto Godot: `C:\Users\jotit\OneDrive\Documentos\GitHub\SeaK\seak`

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

- Ingest: soltar fuente en .raw/, decir "ingest [archivo]"
- Query: preguntar lo que sea — Claude lee hot.md, luego index.md, luego páginas
- Lint: decir "lint the wiki" para un health check
