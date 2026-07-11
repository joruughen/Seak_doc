---
type: module
path: "Scenes/Cube.gd"
status: active
language: gdscript
purpose: "RigidBody3D balsa que flota sobre el agua usando 9 sondas de boyancia"
depends_on: ["Scenes/Water.gd"]
used_by: ["Scenes/World.tscn"]
tags: [module, physics, buoyancy, rigid-body]
created: 2026-07-11
updated: 2026-07-11
---

# Cube Flotante

`RigidBody3D` con forma de balsa. En `World.tscn` (pre-refactor): masa 5 kg, `float_force = 5.0`, y **escala no uniforme (6.37, 0.50, 7.19) aplicada directamente al cuerpo** sobre un `BoxShape3D` unitario.

## Algoritmo de boyancia (pre-refactor)

- 9 `Marker3D` en `ProbeContainer` distribuidos en la cara inferior (esquinas, bordes, centro).
- Cada frame físico, por sonda:
  - `depth = water.get_height(probe.global_position) - probe.global_position.y`
  - si `depth > 0`: `apply_force(UP * float_force * gravity * depth, offset_local)`
- En `_integrate_forces`: si está sumergido, multiplica `linear_velocity *= 1 - water_drag` (0.05) y lo mismo para angular.

Es un **resorte sin amortiguador**: la fuerza depende solo de la profundidad, no de la velocidad vertical en el punto. Ver [[Físicas de Flotabilidad]].

## Problemas conocidos (pre-refactor)

> [!contradiction] Causas de la inestabilidad
> 1. **Escala no uniforme en el RigidBody**: Jolt recalcula la forma escalada cada paso y los contactos se vuelven inestables. La escala debe vivir en `BoxShape3D.size` / `BoxMesh.size`, nunca en el transform del cuerpo.
> 2. **Resorte sin damping** → oscilación permanente que se amplifica con cualquier perturbación (ej. el Player aterrizando).
> 3. **Masa 5 kg** para una balsa de 6.4×0.5×7.2 m: cualquier impulso de contacto del Player (masa efectiva infinita del cuerpo cinemático) domina la dinámica.
> 4. Boyancia consulta `get_height()` desincronizado del shader → la balsa "flota" sobre una ola que no es la que se ve ([[Sincronización CPU-GPU de Olas]]).

Depende de [[Sistema de Agua]] para `get_height()`. Interactúa con [[Player Controller]].
