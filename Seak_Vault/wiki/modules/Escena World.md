---
type: module
path: "Scenes/World.tscn"
status: active
language: tscn
purpose: "Escena principal: luz, cielo, plataforma, jugador, agua y balsa"
depends_on: ["Scripts/Player.gd", "Scenes/Water.gd", "Scenes/Cube.gd", "Shaders/Water2.tres"]
used_by: []
tags: [module, scene]
created: 2026-07-11
updated: 2026-07-11
---

# Escena World

Escena principal (`run/main_scene`). Proyecto configurado con **Godot 4.6**, features `GL Compatibility`, física **Jolt Physics**.

## Árbol de nodos

```
World (Node3D)
├── DirectionalLight3D (sombras activas)
├── WorldEnvironment (ProceduralSky, tonemap filmic)
├── CSGBox3D (plataforma 11×0.48×16, con colisión)
├── Player (CharacterBody3D) → Scripts/Player.gd
│   ├── MeshInstance3D (cápsula)
│   ├── CollisionShape3D (ConvexPolygonShape3D)
│   └── Head → Camera3D
├── Water (MeshInstance3D, y=-0.43) → Scenes/Water.gd
│   └── PlaneMesh 200×200, 200 subdivisiones, material Water2.tres
└── Cube (RigidBody3D, masa 5, float_force 5) → Scenes/Cube.gd
    ├── MeshInstance3D (BoxMesh unitario)
    ├── CollisionShape3D (BoxShape3D unitario)
    └── ProbeContainer → Probe..Probe9 (Marker3D, cara inferior)
```

## Detalle crítico (pre-refactor)

El nodo `Cube` lleva la escala de la balsa **en el transform del RigidBody3D**: basis `(6.3657, 0, 0 / 0, 0.4967, 0 / 0, 0, 7.1852)`. Las 9 sondas están en coordenadas locales unitarias (±0.5) que la escala expande. Esto rompe la física en Jolt — ver [[Cube Flotante]] y [[Físicas de Flotabilidad]].

Módulos: [[Player Controller]], [[Sistema de Agua]], [[Cube Flotante]].
