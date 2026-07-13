---
type: decision
status: done
date: 2026-07-13
owner: Claude + Jorge
context: "Fase 2 Grupo 2 del roadmap: núcleo de soldadura — génesis del BoatManager al pegar 2 piezas sueltas, ConnectionGraph, recálculo de masa/COM"
tags: [decision, gameplay, physics, prototype, fase2]
created: 2026-07-13
updated: 2026-07-13
---

# ADR-005 — BoatManager: Génesis de Botes (Fase 2 Grupo 2)

Implementa el núcleo de soldadura de [[Roadmap Prototipo SeaK]] Fase 2: **génesis** (soldar 2 `LoosePiece` sueltas, ninguna perteneciente aún a un bote). Soldar pieza→bote existente y bote→bote es Grupo 3, no implementado aquí. Diseño previo en [[Análisis Técnico Prototipo SeaK]] §2.

## `BoatManager` (`Scripts/BoatManager.gd`)

`static func weld_two_loose_pieces(a: LoosePiece, b: LoosePiece) -> BoatManager` crea el `RigidBody3D` en el centroide de ambas, transfiere `linear_velocity` promediada por masa (evita el "tirón" de arrancar con la velocidad de una sola pieza), migra mesh+shape de cada una, registra la arista en el `ConnectionGraph`, y recalcula masa/COM. Libera las dos `LoosePiece` originales (`queue_free()`).

## Bug: el árbol con un Node3D "AttachedPiece" por pieza dejaba el bote sin colisión

El diseño describe `AttachedPiece` como "`Node3D` + `CollisionShape3D` bajo el BoatBody", así que la primera implementación creaba un `Node3D` intermedio por pieza (agrupando su mesh+shape) como hijo del `BoatManager`. **Godot únicamente registra la colisión de un `CollisionShape3D` si su padre INMEDIATO es un `CollisionObject3D`** (no basta con ser descendiente) — con el `Node3D` de por medio, el shape no se registraba con ningún cuerpo físico. Resultado: el bote soldado (probado con Barril+Puerta) tenía masa/COM correctos pero **cero colisión real**, y caía atravesando el piso indefinidamente en la prueba headless (posición muy por debajo del suelo tras 2s, en vez de asentarse).

**Fix**: mesh y `CollisionShape3D` de cada pieza migran como hijos **directos** del `BoatManager`, sin ningún `Node3D` intermedio. Esto además cumple al pie de la letra lo que el propio análisis técnico pedía ("el scene tree bajo el BoatBody se mantiene plano... la topología vive solo en el grafo"): la agrupación por pieza vive en `ConnectionGraph`/`_piece_data`/`_piece_local_pos` (diccionarios, por `piece_id`), no en la jerarquía de nodos.

## Bug secundario: `global_position` fijado antes de entrar al árbol

`boat.global_position = ...` se llamaba antes de `parent.add_child(boat)`. Fijar la posición global de un `Node3D` sin padre revienta (`!is_inside_tree()`, devuelve `Transform3D()`) porque el cálculo necesita el transform del padre. Fix: reordenado — `add_child(boat)` primero, luego `global_position`/`linear_velocity`.

## `ConnectionGraph`

`Dictionary piece_id (int) → Array[int]` de vecinos soldados, mantenido por el propio `BoatManager` (`_connect`). Es la fuente de verdad estructural, consumida más adelante por la fragmentación (Fase 4) — no se deriva del scene tree.

## Masa y COM — nunca inercia custom

`_recalculate_mass_and_com()` suma `PieceData.mass` de todas las piezas soldadas y computa el centro de masa ponderado a partir de la posición local de cada `CollisionShape3D` migrado (aproximación válida: todas las shapes de [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]] están centradas en su propio origen). Se fija `center_of_mass_mode = CUSTOM` y `center_of_mass`, pero **`inertia_mode` se deja en su default (`AUTO`)** — nunca se toca `inertia` a mano, por la regla de godot#78750 (masa+COM custom junto con inercia custom da resultados físicos incorrectos), ya anotada como riesgo en [[Análisis Técnico Prototipo SeaK]].

## Anti-tunneling heredado

`boat.continuous_cd = true` en la génesis — mismo refuerzo que las `LoosePiece` (ver [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]] Fix 3): un bote hecho de piezas delgadas no debe perder la protección anti-tunneling que sus piezas sueltas ya tenían.

## Disparador de prueba (provisorio)

El modo construcción con `RayCast3D` + ghost preview es Grupo 4, no implementado todavía. Para poder probar la génesis ahora, `Player.gd` reutiliza el sistema de carga de la Fase 1: sosteniendo una `LoosePiece` (`held_body`), apuntar con la cámara a otra y presionar **`weld`** (tecla G) llama a `BoatManager.weld_two_loose_pieces`. `_raycast_interact()` ahora acepta una lista de exclusión adicional (`extra_exclude`) — sin excluir `held_body`, el rayo se pegaría contra la propia pieza sostenida (está justo en su trayectoria, frente a la cámara en el `HoldPoint`) en vez de llegar a la pieza objetivo. Este disparador se reemplaza en el Grupo 4 por el modo construcción real; no soldar a un bote existente (`target` no es `LoosePiece` tras el primer weld) es intencional — eso es Grupo 3.

## Validación

Script headless: suelda Barril (8 kg) + Puerta (15 kg) colocadas a mano cerca una de otra. Confirmado: `mass=23` (suma exacta), `center_of_mass=(0.152, 0, 0)` (coincide con el promedio ponderado calculado a mano), `connection_graph={0:[1], 1:[0]}`, 4 nodos migrados (2 `MeshInstance3D` + 2 `CollisionShape3D`) como hijos directos, las 2 `LoosePiece` originales quedan `null`/fuera del árbol. Sin tunneling ni explosión en 120 frames posteriores de física (velocidad máxima 3.97 m/s, razonable para una caída+asentamiento de un cuerpo compuesto asimétrico).

Relacionado: [[Roadmap Prototipo SeaK]], [[Análisis Técnico Prototipo SeaK]], [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]], [[Player Controller]].
