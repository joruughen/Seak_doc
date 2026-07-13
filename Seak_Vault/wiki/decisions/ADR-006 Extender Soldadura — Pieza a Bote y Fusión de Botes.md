---
type: decision
status: done
date: 2026-07-13
owner: Claude + Jorge
context: "Fase 2 Grupo 3 del roadmap: extender la soldadura del Grupo 2 (solo génesis, 2 LoosePiece) a pieza→bote existente y bote→bote"
tags: [decision, gameplay, physics, prototype, fase2]
created: 2026-07-13
updated: 2026-07-13
---

# ADR-006 — Extender Soldadura: Pieza a Bote y Fusión de Botes (Fase 2 Grupo 3)

El Grupo 2 ([[ADR-005 BoatManager — Génesis de Botes]]) solo cubría la génesis: dos `LoosePiece` sueltas → un `BoatManager` nuevo. Con eso, el resultado de una soldadura no se podía volver a fusionar con nada más — exactamente la limitación que el usuario señaló antes de arrancar este grupo. Este ADR implementa los dos casos que faltaban, ya anotados en [[Análisis Técnico Prototipo SeaK]] §2: *"Pegar una pieza a un bote existente = solo pasos 2–4. Pegar dos botes = fusionar grafos y migrar todo al mayor."*

## Refactor previo: `_adopt_piece`

Antes de agregar los dos casos nuevos, se extrajo la lógica común de `_migrate_piece` (reparentar mesh+shape como hijos directos, preservando transform global) a un método interno `_adopt_piece(nodes: Array, piece_data: PieceData) -> int`. Es necesario porque fusionar dos botes no parte de una `LoosePiece` (con su mesh+shape ya agrupados bajo un `RigidBody3D` fácil de vaciar) sino de nodos que YA son hijos directos de otro `BoatManager` — se necesitaba una versión de la migración que aceptara nodos sueltos en vez de asumir un origen `LoosePiece`. `_migrate_piece(piece: LoosePiece)` ahora es solo un envoltorio: `_adopt_piece(piece.get_children(), piece.piece_data)` + `piece.queue_free()`.

También se agregó bookkeeping nuevo por pieza, necesario para los casos de este grupo:
- `_piece_nodes: Dictionary` (piece_id → sus nodos mesh+shape): para que la fusión bote→bote sepa qué reparentar de cada pieza del bote absorbido.
- `_shape_to_piece_id: Dictionary` (instance_id del `CollisionShape3D` → piece_id) + `piece_id_for_shape_index(shape_index)`: traduce el índice de shape que devuelve un raycast (`intersect_ray().shape`) a la pieza específica que el jugador apuntó dentro de un bote con varias piezas — necesario para saber a cuál conectar la nueva arista del grafo, no solo "en algún lugar del bote".
- `nearest_piece_id(global_pos)`: pieza de un bote más cercana (en espacio global) a una posición dada — usado como aproximación de "a qué pieza conectar" cuando el raycast no da esa información (ej. sosteniendo un bote y apuntando a una pieza suelta: el hit da la pieza suelta, no dice nada de qué pieza del bote sostenido es la más cercana).

## `weld_piece_to_boat(boat, piece, neighbor_piece_id)`

"Solo pasos 2–4" del análisis técnico: sin instanciar un `BoatManager` nuevo (el bote ya existe), se transfiere la velocidad promediada por masa (`boat` + `piece`, mismo criterio anti-tirón que la génesis), se migra la pieza (`_migrate_piece`, ahora vía `_adopt_piece`), se conecta al `neighbor_piece_id` indicado en el grafo, y se recalcula masa/COM.

## `weld_boats(boat_a, boat_b)` — fusión, migra al mayor

"Mayor" = el bote con más piezas (`_piece_data.size()`), no el de más masa — desempate arbitrario razonable sin especificación más fina en el diseño. El bote menor se vacía por completo (`_adopt_piece` de cada una de sus piezas hacia el mayor, con ids reasignados vía un mapa `old_to_new`) y se libera (`queue_free`). Las aristas internas del bote menor se reconstruyen con los ids nuevos; se agrega además un **puente** entre ambos grafos, ya que soldar dos ensambles completos no tiene una "arista natural" como pegar 2 piezas sueltas — se conecta la pieza del bote menor más cercana (geométricamente) a la pieza más cercana del bote mayor, usando `nearest_piece_id`. Es una aproximación deliberada: sin snap real todavía (Grupo 4), no hay forma de saber el punto de contacto exacto; cuando el modo construcción lo dé, este puente puede reemplazarse por la arista real.

## Disparador de prueba extendido

`Player._try_weld()` ahora despacha según el tipo de `held_body` y del `target` (cualquier combinación de `LoosePiece`/`BoatManager`):
- pieza + pieza → `weld_two_loose_pieces` (génesis, Grupo 2)
- pieza sostenida + bote apuntado → `weld_piece_to_boat(target, held, target.piece_id_for_shape_index(hit.shape))`
- bote sostenido + pieza apuntada → `weld_piece_to_boat(held, target, held.nearest_piece_id(target.global_position))`
- bote sostenido + bote apuntado → `weld_boats(held, target)`

Sigue siendo el disparador provisorio (tecla `weld`, G) hasta que el Grupo 4 lo reemplace por el modo construcción con ghost preview — documentado igual en [[ADR-005 BoatManager — Génesis de Botes]].

## Validación

Script headless, sin usar el trigger del jugador (llamadas directas a los métodos estáticos, más rápido y evita ruido de cámara/raycast):
1. Génesis: Barril(8)+Puerta(15) → mass=23, 2 piezas.
2. `weld_piece_to_boat`: + Palé(12) → mass=35, 3 piezas; grafo `{0:[1], 1:[0,2], 2:[1]}` (Palé se conectó a Puerta, la pieza más cercana — correcto).
3. Génesis aparte: Nevera(10)+TuboPVC(4) → bote2, mass=14, 2 piezas.
4. `weld_boats(bote1, bote2)`: bote1 (3 piezas) es el mayor, absorbe a bote2 → mass=49, 5 piezas; grafo fusionado con el puente correcto (Nevera conectada a Palé, la pieza de bote1 geométricamente más cercana); `bote2` queda inválido (liberado); 10 hijos en el árbol (5 piezas × mesh+shape).
5. 120 frames de física posteriores: sin tunneling ni explosión (velocidad máxima 6.64 m/s, razonable para una caída+asentamiento de un compuesto de 5 piezas asimétrico).

Relacionado: [[Roadmap Prototipo SeaK]], [[Análisis Técnico Prototipo SeaK]], [[ADR-005 BoatManager — Génesis de Botes]], [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]].
