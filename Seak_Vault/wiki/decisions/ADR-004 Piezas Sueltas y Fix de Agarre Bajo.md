---
type: decision
status: done
date: 2026-07-12
owner: Claude + Jorge
context: "Fase 2 Grupo 1 del roadmap (datos base: PieceData + LoosePiece) y fix reportado por el usuario: piezas bajas/planas difíciles de agarrar"
tags: [decision, gameplay, physics, player, prototype, fase2]
created: 2026-07-12
updated: 2026-07-12
---

# ADR-004 — Piezas Sueltas (Fase 2 Grupo 1) y Fix de Agarre Bajo

## Fase 2 Grupo 1 — Datos base

Implementa el primer grupo de tareas de [[Roadmap Prototipo SeaK]] Fase 2: datos puros, sin lógica de física nueva (boyancia por pieza llega en Fase 3, soldadura en Grupo 2).

**`PieceData` (`Scripts/PieceData.gd`, `Resource`)**: `mass`, `buoyancy_factor`, `hp`, `flags` (bitmask vía `@export_flags("walkable","grabbable_edge","storage","bumper","armor")`) y `storage_slots`. Se usa bitmask en vez de 5 bools sueltos porque el diseño en [[Análisis Técnico Prototipo SeaK]] §6 ya describe las piezas por combinaciones de flags, y un enum de flags de Godot da esa tabla gratis en el inspector.

**`LoosePiece` (`Scenes/LoosePiece.gd` + `Scenes/LoosePiece.tscn`)**: escena base reutilizable, `RigidBody3D` + `MeshInstance3D`/`CollisionShape3D` placeholder + `@export piece_data: PieceData`. En `_ready()` sincroniza `mass` del RigidBody desde el resource. Se instancia 7 veces en `World.tscn`, cada instancia sobreescribiendo mesh/shape (Box o Cylinder, como pide el diseño) y `piece_data` vía los overrides de nodo hijo de Godot (sin escenas heredadas ni "editable children").

**Los 7 objetos de prueba** (`Resources/Pieces/*.tres`), valores tomados literalmente de la tabla de [[Análisis Técnico Prototipo SeaK]] §6: Barril (8kg, buoy 2.5), Puerta (15kg, `grabbable_edge+walkable`), Palé (12kg, `walkable`), Nevera (10kg, `storage` 4 slots), Chapa (25kg, `armor`), Neumático (9kg, `bumper`), Tubo PVC (4kg, sin flags). El `Barrel` de prueba de la Fase 1 se convirtió en la instancia `LoosePiece` de Barril (mismo mesh/shape/transform) en vez de duplicar un segundo barril — `Player.gd` interactúa por raycast genérico, no por nombre de nodo, así que no rompe el pickup ya validado.

**Validado**: script headless que instancia `World.tscn`, recorre las 7 piezas y confirma tipo `LoosePiece`, `piece_data` asignado y masa sincronizada. Sin lógica de física nueva, tal como pedía el grupo.

## Fix: piezas bajas/planas difíciles de agarrar

Reportado por el usuario tras ver las 7 piezas en juego: varias (Palé, Chapa, Puerta si cae) terminan asentadas casi al ras del suelo por su propia física (son `RigidBody3D` bajo gravedad — la altura de spawn no importa, caen y se asientan en su altura real). Confirmado con un test headless: tras dejarlas caer, **Palé se asienta a y≈0.034 y Chapa a y≈0.002** — prácticamente pegadas al piso.

**Causa raíz**: el pitch de la cámara (`Player.gd:_unhandled_input`) estaba clampeado a `[-40°, 60°]`. Revisé el grafo/wiki (`graphify query`) y ningún ADR ni el roadmap menciona ese límite como decisión de diseño — es un valor por defecto del template original nunca reconsiderado, no algo "no implementado a propósito". A -40° el raycast de `_handle_interaction` (rango 2.5m) no llega a apuntar a un objeto casi a ras de suelo estando de pie cerca; el jugador tampoco tenía forma de agachar la cámara para compensar.

**Fix**:
1. **Pitch ampliado a `[-80°, 60°]`** — casi vertical hacia abajo, suficiente para apuntar a cualquier objeto en el suelo a distancia de agarre.
2. **Agachado nuevo** (no existía, tampoco estaba planeado en ningún documento): nueva acción de input `crouch` (Ctrl) en `project.godot`. `Player._update_crouch()` baja la cámara (`head.position.y`) `crouch_camera_drop=0.55` m con una transición suave (`lerp`, `crouch_transition_speed=8.0`) mientras se mantiene presionada, parado y en estado `NORMAL`; también reduce la velocidad a `CROUCH_SPEED=2.5`. No se tocó el `CollisionShape3D` de la cápsula (se evita la complejidad de resize de colisión en tiempo real) — el agachado es solo cámara+velocidad, suficiente para el propósito (apuntar mejor a objetos bajos), no un sigilo/cobertura real.

**Validado**: headless — pitch efectivo `-79.99°` alcanzado sin clamping extra; con `crouch` mantenido 1s simulado, la cámara baja de `y=0.765` a `y=0.215` (`CROUCH_OK`, cae más de los 0.3m de umbral de la prueba). Import completo sin errores.

## Fix 2: la Chapa metálica no se podía agarrar ni agachado

Reportado tras el fix anterior: seguía sin poder agarrarse la Chapa, incluso con cámara y agachado ya arreglados. **No era un bug de colisión/cámara** — `_handle_interaction` en `Player.gd` gatea el agarre por masa:

```gdscript
if Input.is_action_just_pressed("interact") and body.mass <= carry_max_mass:
    _grab(body)
elif Input.is_action_pressed("interact") and body.mass > carry_max_mass:
    _push_held(body, delta)  # nunca levanta, solo empuja
```

`carry_max_mass = 15.0` se fijó en la Fase 1 para distinguir el Barril de prueba (8 kg, agarrable) del Cube (200 kg, solo empujable) — un mundo de 2 objetos. La Chapa (25 kg, la más pesada de las 7 piezas de [[Análisis Técnico Prototipo SeaK]] §6 por diseño) cae por encima de ese umbral: `interact` nunca dispara `_grab`, solo el empuje sostenido — que además no levanta una pieza plana del suelo. El umbral nunca se revisó al incorporar el roster real de piezas en el Grupo 1.

**Fix**: `carry_max_mass` subido de `15.0` a `30.0` — deja agarrables las 7 piezas del prototipo (máx. Chapa, 25 kg) y mantiene el Cube (200 kg) como el único cuerpo de solo-empuje. Validado con `--headless --import`: sin errores de sintaxis; `25 ≤ 30` confirma el nuevo umbral cubre el caso.

## Fix 3: piezas planas (Chapa, Puerta) atraviesan la isla al lanzarlas

Reportado: al lanzar/empujar con fuerza una pieza plana, esta atraviesa el `CSGBox3D` que sirve de isla de prueba, en vez de rebotar en su superficie.

**Causa**: `CSGBox3D.use_collision = true` genera una colisión **cóncava** (trimesh derivado de la malla CSG), no un `BoxShape3D` convexo — aunque visualmente sea un simple rectángulo. Los colliders cóncavos son notoriamente más propensos a tunneling con cuerpos rápidos/delgados: a la velocidad que alcanza una pieza lanzada con fuerza, el desplazamiento por paso de física puede saltarse la detección de colisión discreta contra un trimesh, algo que no ocurría con una simple caída por gravedad (velocidad baja) — por eso el fix anterior (Fase 2 Grupo 1) no lo mostró, solo apareció al lanzar/empujar.

**Fix (dos partes)**:
1. `Scenes/World.tscn`: `CSGBox3D.use_collision` pasa a `false` (queda solo como visual); se agrega un `IslandFloor` (`StaticBody3D` + `BoxShape3D` convexo, mismo transform/tamaño que el CSGBox3D) como la colisión real de la isla.
2. `Scenes/LoosePiece.tscn`: `continuous_cd = true` en el nodo raíz — Continuous Collision Detection para las 7 piezas, refuerzo adicional contra tunneling en objetos delgados que se mueven rápido (lanzados/empujados).

**Validado**: script headless que lanza la Chapa desde 5m de altura a -40 m/s (simulando un lanzamiento fuerte) con rotación — aterriza limpiamente en `y≈0` (superficie de la isla), sin pasar de `floor_bottom_y=-0.5`. `NO_TUNNEL` confirmado.

Relacionado: [[Roadmap Prototipo SeaK]], [[Análisis Técnico Prototipo SeaK]], [[Player Controller]], [[ADR-003 Sistema de Nado, Estamina e Interacción]].
