---
type: meta
title: "Log de Operaciones"
created: 2026-07-11
updated: 2026-07-11
tags: [log]
---

# Log

<!-- append-only: entradas nuevas ARRIBA -->

## 2026-07-13 — Fix real de los huecos: el jugador empujaba sin querer el objetivo al pararse cerca
- Con una segunda captura (ghost gigante verde) se separaron dos fenómenos: (1) el "ghost gigante" no era bug — escala exacta 1.0, posición al ras; era solo la cámara a ~0.5m del objetivo (perspectiva normal al acercarse mucho a un objetivo angosto). El usuario decidió no tocar esto. (2) El hueco real SÍ se reprodujo, con una causa nueva: el jugador empuja físicamente objetivos livianos (Tubo PVC, 4kg) al pararse cerca para apuntarlos, usando el mecanismo de empuje de la Fase 1 (`_interact_with_rigid_bodies`, 200N). El objetivo se corre entre el momento en que el ghost calcula la posición y el momento de confirmar.
- Reproducido headless: tubo asentado en el piso + jugador parado cerca 30 frames (0.5s) sin el fix → se corre varios centímetros; con el fix → deriva de solo 0.0015m.
- Fix: excepción de colisión temporal jugador↔objetivo mientras `_weld_target` sea válido (mismo mecanismo que ya existía para la pieza sostenida), actualizada en `_update_weld_preview` y limpiada en `_clear_weld_preview`.
- Actualizado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]] (nueva sección "Quinta ronda").

## 2026-07-13 — Fix: encogido perdido al sostener un bote + investigación de huecos con rotaciones (sin cerrar)
- Reportado con captura: (1) el sistema de soldadura seguía sin ser perfecto, sobre todo con rotaciones, quedaban huecos; (2) al sostener un bote ya soldado, se perdía el efecto de encogido visual y volvía a tapar la vista.
- (2) Fix aplicado (solución propuesta por el usuario): `_apply_held_view_scale` ahora, si lo sostenido es un `BoatManager`, usa el `held_view_scale` MÁS CHICO entre todas sus piezas y lo aplica a todas las mallas del bote. Validado headless: bote se encoge 0.5x al agarrar, restaura 1.0x exacto al soltar.
- (1) Investigado sin poder reproducirlo: stress test de las 64 combinaciones de rotación manual (yaw×pitch×roll) contra un objetivo fijo, y soldar contra una pieza YA rotada dentro de un bote existente — ambos dan 0.0 de hueco en todos los casos. La matemática del snap se sostiene. Queda pendiente conseguir la secuencia exacta de pasos que produjo la captura para reproducirlo puntualmente.
- Actualizado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]] (nueva sección "Cuarta ronda").

## 2026-07-13 — Fix: hueco visible entre piezas soldadas (Barril + Tubo PVC)
- Reportado con captura: Barril y Tubo PVC quedaban soldados con un hueco entre ambos en vez de tocarse.
- Reproducido headless: el offset "al ras" por tamaño real (fix anterior) calculaba la posición exacta de contacto, pero el redondeo a la rejilla de 0.25m que corría DESPUÉS movía los 3 ejes por igual, incluyendo el de contacto — 0.052m de hueco medido, sin ninguna rotación de por medio.
- Primer intento (insuficiente): dejar exacto solo el eje más alineado con la normal del impacto, redondeando los otros dos. El Tubo PVC es tan angosto (radio 0.05) que redondear los ejes tangenciales igual podía desplazar el contacto hasta 0.125m, más que su propio radio.
- Fix final: se quitó la rejilla de posición por completo (`snap_grid_size` eliminado) — sin una superficie de casco grande todavía donde alinear varios tablones en fila tenga sentido, no aporta nada y sí puede separar piezas angostas. `_compute_snap_transform` devuelve ahora la posición al ras exacta, sin redondeo.
- Validado headless: la reproducción exacta del bug da `0.0` de diferencia entre la posición calculada y la usada para soldar.
- Actualizado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]] (nueva sección "Tercera ronda").

## 2026-07-13 — 5 fixes de ergonomía en el modo construcción: tunneling, pitch, encogido customizable, capas de colisión
- Reportados por el usuario tras seguir probando: (1) piezas como el Tubo PVC se atravesaban al soldar; (2) mirando hacia arriba había mucha menos libertad de colocación que mirando hacia abajo, sospechaba del raycast; (3) difícil encajar piezas "perfectas" borde a borde; (4) la pieza sostenida seguía tapando mucha vista pese al HoldPoint más bajo; (5) preguntó qué pasaría si suelta una pieza atravesando el suelo, sin colisión activa.
- (2) Confirmado: pitch clampeado a `[-80°,60°]`, asimétrico desde ADR-004 (solo se amplió el límite de abajo). Fix: `[-80°,80°]`.
- (1)+(3) Causa: el snap empujaba la pieza un padding FIJO de 0.05m a lo largo de la normal del impacto, sin considerar el tamaño real de la pieza — el Tubo PVC acostado (radio 0.05, altura 1.5) puede tener hasta 0.75 de semi-extensión en esa dirección. Fix: `_held_half_extent_toward()` calcula la semi-extensión real (fórmula exacta de proyección para BoxShape3D/CylinderShape3D) según la rotación que la pieza va a tener, y el snap empuja esa distancia + 0.02, no 0.05 fijos.
- (4) Nuevo `PieceData.held_view_scale` (default 0.5, customizable por pieza como pidió el usuario): encoge solo la MALLA (no la colisión) de la pieza sostenida. El ghost sigue mostrando el tamaño real (`_build_ghost_for` usa la escala guardada antes de encoger, no la actual).
- (5) Se reemplazó "desactivar toda la colisión mientras se sostiene" por un esquema de **capas**: capa 1=entorno (sin cambios), capa 2=piezas/botes. Sosteniendo algo: `layer=0,mask=1` (solo entorno — nunca cae al vacío) en vez de `layer=2,mask=3` (normal, con otras piezas). Se restaura al soltar o justo antes de soldar/migrar. Si queda algo superpuesto al restaurar, el motor la empuja afuera suavemente (depenetración normal), no se traba ni cae.
- Validado headless: pitch ±80°; capas 2/3→0/1→2/3 en los 3 momentos; escala de malla se reduce y restaura exacta; `_held_half_extent_toward` da 0.75 para el Tubo PVC acostado (mitad exacta de 1.5) y el snap empuja esa distancia; soldadura final con masa correcta.
- Actualizado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]] (nueva sección), [[Player Controller]], `Scripts/PieceData.gd` (`held_view_scale`), `Scenes/LoosePiece.tscn` (capas), `Scripts/BoatManager.gd` (capas al crear).

## 2026-07-13 — Ajuste al modo construcción: HoldPoint bajo + sin colisión, rotación manual en 3 ejes
- Reportado tras implementar el Grupo 4: la pieza sostenida tapaba la vista al apuntar el ghost (flotaba centrada frente a la cámara), y sin control de rotación manual era difícil ensamblar piezas a gusto (el snap heredaba el tumbado físico aleatorio).
- Fix 1: `HoldPoint` bajado de `(0,0,-1.2)` a `(0,-0.35,-1.0)` (World.tscn) + colisión completamente desactivada en la pieza sostenida (`_set_held_collision_enabled`, nuevo en Player.gd) — sin la colisión desactivada, el HoldPoint más bajo haría que la pieza rozara terreno/otras piezas. Se reactiva al soltar sin soldar y ANTES de mover/migrar al confirmar (si no, el shape migrado hereda `disabled=true` y el bote nace sin colisión real — mismo patrón de bug que ADR-005, por otra causa).
- Fix 2 (analizado con el usuario antes de implementar): se evaluó si permitir rotación libre en 3 ejes rompía `walkable`/`grabbable_edge`/`RowingStation` (Fase 3, asumen orientación "de pie" natural). Conclusión: solo importa con ángulos intermedios y solo cuando esos sistemas existan (ninguno implementado todavía); restringiendo a pasos de 90° por eje, la pieza siempre queda en una de las 24 orientaciones "de cubo", alineada a ejes. Se implementó: 3 ejes, 90°/tecla (`rotate_yaw`=R, `rotate_pitch`=T, `rotate_roll`=Y), acumulados en `_manual_rotation` (Basis, reseteado en cada `_grab`), reemplazando la derivación de yaw desde el tumbado físico.
- Pendiente anotado para Fase 3: cuando se implementen esos flags, van a necesitar ser conscientes de la orientación REAL de la pieza, no solo confiar en el flag de `PieceData`.
- Validado headless: colisión disabled→true al agarrar, →false al soltar y al confirmar (shape migrado al bote sin disabled); ghost refleja `_manual_rotation` exactamente; weld final con masa correcta.
- Actualizado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]] (nueva sección), [[Player Controller]], `project.godot` (`rotate_yaw`/`rotate_pitch`/`rotate_roll`), `Scenes/World.tscn` (HoldPoint).

## 2026-07-13 — Fase 2 Grupo 4: modo construcción real (ghost preview + snap), se retira la tecla G
- El usuario preguntó por qué haría falta una tecla aparte para confirmar la soldadura si ya existe `interact` — no hacía falta. Se retiró la acción `weld` de `project.godot` por completo.
- `Player.gd`: `_update_weld_preview()` (raycast + ghost verde/rojo, corre cada frame mientras se sostiene algo) + `_compute_snap_transform()` (rejilla 0.25m, rotación snap a 90°) + `_confirm_weld()` (mueve la pieza sostenida a la pose exacta del ghost ANTES de soldar, para que el resultado coincida con la preview). `_handle_interaction`: `interact` (E) suelda si hay objetivo válido, si no suelta — mismo botón, sin acción nueva.
- Ghost: `Node3D` con un `MeshInstance3D` duplicado por cada mesh de la pieza/bote sostenido (soporta botes de varias piezas, árbol plano); material `StandardMaterial3D` translúcido sin sombra.
- Validado headless (2 casos, sin simular input real): objetivo válido → ghost verde, snap exacto a múltiplos de 0.25, confirma y suelda (mass=23 tras Barril+Puerta, igual que Grupo 2/3); objetivo inválido (Cube) → ghost rojo, confirmar solo suelta, no crea bote.
- Creado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]]. Actualizados: [[Roadmap Prototipo SeaK]] (Grupo 4 marcado), [[Player Controller]], `project.godot` (acción `weld` eliminada).

## 2026-07-13 — Fase 2 Grupo 3: soldar pieza→bote existente y bote→bote
- Extiende [[ADR-005 BoatManager — Génesis de Botes]] (Grupo 2, que solo cubría génesis de 2 LoosePiece): ahora una soldadura sí se puede volver a fusionar con más piezas u otros botes — la limitación que el usuario señaló antes de arrancar este grupo.
- Refactor previo: `_migrate_piece` se separó en `_adopt_piece(nodes, piece_data)` (reparenta mesh+shape sueltos, no asume que vienen de una LoosePiece) + `queue_free()` de la pieza; necesario porque fusionar botes reparenta nodos que ya son hijos de OTRO BoatManager, no de una LoosePiece.
- Nuevo: `weld_piece_to_boat(boat, piece, neighbor_id)` — pieza→bote existente, "solo pasos 2-4" (sin génesis), velocidad promediada por masa, conecta al vecino indicado.
- Nuevo: `weld_boats(boat_a, boat_b)` — bote→bote, migra al de MÁS PIEZAS (no más masa), reasigna ids, reconstruye aristas internas del bote absorbido, agrega un puente geométrico entre ambos grafos (`nearest_piece_id`, aproximación mientras no haya snap real).
- Nuevo bookkeeping en `BoatManager`: `_piece_nodes` (piece_id→nodos), `_shape_to_piece_id` + `piece_id_for_shape_index()` (traduce el índice de shape de un raycast a la pieza específica dentro de un bote), `nearest_piece_id()`.
- `Player._try_weld()` extendido a las 4 combinaciones pieza/bote (antes solo pieza+pieza).
- Validado headless: Barril+Puerta→bote1(23,2); +Palé→bote1(35,3, grafo correcto); Nevera+TuboPVC→bote2(14,2); fusión bote1+bote2→bote1 sobrevive (49,5 piezas, grafo con puente correcto, bote2 liberado, 10 hijos = 5×mesh+shape); 120 frames sin tunneling ni explosión.
- Creado: [[ADR-006 Extender Soldadura — Pieza a Bote y Fusión de Botes]]. Actualizado: [[Roadmap Prototipo SeaK]] (Grupo 3 marcado).

## 2026-07-13 — Fase 2 Grupo 2: BoatManager (génesis, ConnectionGraph, masa/COM)
- Implementado el núcleo de soldadura de [[Roadmap Prototipo SeaK]] Fase 2: `Scripts/BoatManager.gd` (`RigidBody3D`), `weld_two_loose_pieces(a, b)` estático — centroide, velocidad promediada por masa, migración de mesh+shape, `ConnectionGraph`, recálculo de masa/COM custom (nunca inercia custom, godot#78750).
- Bug encontrado y corregido durante el desarrollo: un `Node3D` intermedio por pieza (siguiendo la wording literal de "AttachedPiece" en el análisis técnico) dejaba el `CollisionShape3D` sin registrar — Godot solo lo registra si el padre INMEDIATO es un `CollisionObject3D`. El bote soldado caía atravesando todo (masa/COM correctos, cero colisión real). Fix: mesh+shape migran como hijos directos del `BoatManager`, sin wrapper — coincide además con "el scene tree se mantiene plano" del propio diseño.
- Bug secundario: `global_position` fijado antes de `add_child` reventaba (`!is_inside_tree()`). Reordenado.
- Disparador de prueba provisorio en `Player.gd`: sostener una pieza + apuntar a otra + tecla **G** (`weld`) suelda. Se reemplaza en Grupo 4 por el modo construcción real. `_raycast_interact()` ahora acepta exclusión adicional (evita que el rayo choque contra la propia pieza sostenida).
- Validado headless: Barril(8)+Puerta(15) soldados → masa=23, COM=(0.152,0,0) (coincide con cálculo a mano), grafo correcto, sin tunneling ni explosión en 120 frames.
- Creado: [[ADR-005 BoatManager — Génesis de Botes]]. Actualizados: [[Roadmap Prototipo SeaK]] (Grupo 2 marcado), `project.godot` (acción `weld`).

## 2026-07-12 — Fix: piezas planas (Chapa, Puerta) atravesaban la isla al lanzarlas
- Reportado: al lanzar/empujar con fuerza una pieza plana, atravesaba el `CSGBox3D` usado como isla de prueba.
- Causa: `CSGBox3D.use_collision=true` genera colisión **cóncava** (trimesh), no un `BoxShape3D` convexo, aunque sea visualmente un rectángulo simple. Los colliders cóncavos son mucho más propensos a tunneling con cuerpos delgados/rápidos — a la velocidad de un lanzamiento fuerte, el desplazamiento por paso de física se salta la detección discreta contra el trimesh (no pasaba con una simple caída por gravedad, velocidad baja).
- Fix: `World.tscn` — `CSGBox3D.use_collision=false` (queda solo visual) + nuevo `IslandFloor` (`StaticBody3D`+`BoxShape3D` convexo, mismo transform/tamaño). `LoosePiece.tscn` — `continuous_cd=true` en las 7 piezas como refuerzo contra tunneling.
- Validado: script headless, Chapa lanzada desde 5m a -40 m/s con rotación aterriza limpiamente en la superficie de la isla (`NO_TUNNEL`).
- Actualizado: [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]] ("Fix 3").

## 2026-07-12 — Fix: la Chapa metálica no se podía agarrar (umbral de masa, no colisión)
- Reportado tras el fix de cámara/agachado: seguía sin poder agarrarse la Chapa. Investigado vía graphify + lectura directa de `Player.gd`: no era bug de colisión/raycast — `_handle_interaction` gatea el agarre por `body.mass <= carry_max_mass`, y `carry_max_mass=15.0` se fijó en Fase 1 solo para distinguir Barril(8)/Cube(200). La Chapa pesa 25 kg (la más pesada de las 7 piezas por diseño), así que siempre caía en la rama de "solo empujar", que tampoco levanta una pieza plana del suelo.
- Fix: `carry_max_mass` 15.0 → 30.0 en `Scripts/Player.gd` — las 7 piezas del prototipo (máx. Chapa, 25) quedan agarrables; el Cube (200) sigue push-only.
- Validado: `--headless --import` sin errores.
- Actualizado: [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]] (sección "Fix 2").

## 2026-07-12 — Fase 2 Grupo 1 (datos base) + fix: piezas bajas/planas imposibles de agarrar
- Movida la ruta del proyecto Godot a `F:\Claude_Vaults\Seak_doc\seak` (antes en `C:\Users\jotit\OneDrive\Documentos\GitHub\SeaK\seak`); `CLAUDE.md` actualizado.
- Implementado Fase 2 Grupo 1 de [[Roadmap Prototipo SeaK]]: `Scripts/PieceData.gd` (Resource: mass/buoyancy_factor/hp/flags bitmask/storage_slots), `Scenes/LoosePiece.gd`+`.tscn` (RigidBody3D + PieceData, sincroniza masa en `_ready()`), 7 `Resources/Pieces/*.tres` con los valores de [[Análisis Técnico Prototipo SeaK]] §6, instanciados en `World.tscn` (el `Barrel` de Fase 1 se convirtió en la instancia LoosePiece del Barril, no se duplicó).
- Reportado por el usuario: piezas bajas/planas (Palé, Chapa) casi imposibles de agarrar. Diagnóstico vía graphify/wiki: ningún ADR ni el roadmap planeaba un límite de cámara ni agachado — el pitch estaba clampeado a `[-40°,60°]` desde el template original, nunca reconsiderado. Fix: pitch ampliado a `[-80°,60°]` + nuevo agachado (`crouch`, tecla Ctrl) que baja la cámara 0.55m y reduce velocidad, sin tocar la colisión de la cápsula.
- Validado headless: 7 piezas instancian correcto (`LoosePiece`+`PieceData`+masa sincronizada); pitch efectivo -79.99° confirmado; agachado baja la cámara de y=0.765 a y=0.215 en 1s simulado; piezas se asientan casi al ras del piso (Palé y≈0.034, Chapa y≈0.002), confirmando la causa del bug.
- Creado: [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]]. Actualizados: [[Roadmap Prototipo SeaK]] (Grupo 1 marcado), [[Player Controller]].

## 2026-07-12 — Fix: el objeto cargado se quedaba atrás al moverse/girar la cámara
- Bug legítimo de la Fase 1 (sistema de carga ya implementado en [[ADR-003 Sistema de Nado, Estamina e Interacción]]), no dependiente de fases futuras — se arregló ahora.
- Causa: `_update_held_body` fijaba `linear_velocity = (to_target / delta)`, que intenta cerrar TODA la distancia al `HoldPoint` en un solo frame de física — a 60 Hz eso exige velocidades enormes para cualquier separación real, tope (`carry_speed_limit=6.0`) que se activaba constantemente al caminar/girar la cámara rápido. El objeto se quedaba atrás y solo alcanzaba al detenerse el jugador.
- Cuantificado con un test aislado headless: con la fórmula vieja, a 10 m/s de movimiento del punto de sostén, el objeto quedaba 4 unidades atrás y tardaba ~1s en alcanzar tras detenerse.
- Fix: control proporcional (`velocity = to_target * carry_catch_up_rate`, tasa=15/s) en vez de dividir por delta; tope de seguridad subido a `carry_speed_limit=12.0` (ya no es el mecanismo principal de control, solo un límite de emergencia). Mismo test: rezago durante movimiento baja a 0.5 unidades, converge en ~0.3s tras detenerse.
- Validado: `--check-only`, import headless, 180 frames de runtime.

## 2026-07-12 — Diagnóstico: colisión Player↔Cube inestable bajo movimiento errático (anotado, diferido a Fase 2/3)
- Bug reportado: parado/nadando sobre el Cube semihundido, moverse hace que el bote "nade contigo" y acelere hasta romperse; persistía incluso tras los fixes de exclusión-de-colisión-al-cargar y skip-durante-swim de la sesión anterior.
- Diagnóstico con 3 tests aislados en Godot headless (movimiento errático simulando mouse-look real): (1) el motor no empuja RigidBody3D por colisión de CharacterBody3D por sí solo; (2) con `_interact_with_rigid_bodies` completamente desactivado, el Cube explota igual — no es nuestro código de fuerzas; (3) con una excepción de colisión permanente Player↔Cube, el sistema es perfectamente estable.
- **Causa real**: la resolución de contacto nativa de Godot/Jolt entre un CharacterBody3D y un RigidBody3D constantemente forzado por boyancia externa es un caso mal condicionado para el solver cuando la geometría de contacto cambia rápido — no es ajustable con damping/softening de script.
- Se probaron y se dejaron aplicadas dos mejoras incrementales (`weight_damping`, suavizado del punto de apoyo, remoción del gate por estado que podía resonar con el propio rebote del bote) — ayudan pero NO resuelven el caso adversarial de fondo.
- Por decisión del usuario, el fix real (sistema propio de "montar plataforma" sin colisión física directa) se difiere a Fase 2/3 y queda anotado como riesgo bloqueante en [[Análisis Técnico Prototipo SeaK]] (riesgo 5) y como tarea explícita en [[Roadmap Prototipo SeaK]] Fase 3.

## 2026-07-12 — Fixes: barril rota al cargarlo + Cube explota nadando encima
- **Barril rotaba al cargarlo**: el objeto sostenido colisionaba contra la propia cápsula del jugador al girar la cámara (el `HoldPoint` barre un arco alrededor del cuerpo). Fix: `_grab()`/`_release_held_body()` gestionan una excepción de colisión (`add_collision_exception_with` / `remove_collision_exception_with`) entre el jugador y el objeto cargado mientras dura el agarre.
- **El Cube se aceleraba hasta romperse nadando encima suyo semihundido**: `_interact_with_rigid_bodies` (transferencia de peso, ADR-002) seguía corriendo en cualquier estado. Nadando, el agua ya sostiene el peso del jugador; sumarle además el peso completo (`player_mass*gravity`) a un RigidBody parcialmente hundido, combinado con las colisiones erráticas del movimiento libre de nado, entraba en resonancia con la boyancia y disparaba velocidades absurdas. Fix: se desactiva la transferencia de peso/empuje mientras `current_state == SWIMMING` (se preserva intacta en tierra/de pie).
- Validado: `--check-only`, import headless, 180 frames de runtime.

## 2026-07-12 — Ajuste de balance: escalón de hambre endurecido + salto cuesta estamina
- `HUNGER_STAMINA_STEPS` en `PlayerStats.gd`: `20%→30%` (antes 40%) y `0%→10%` (antes 30%) — la caída cerca de la inanición es ahora mucho más severa.
- Nuevo `jump_stamina_cost = 10.0` (costo fijo por salto) en `Player.gd`: el salto en tierra ahora gatea con `stats.drain_stamina(jump_stamina_cost)`, mismo patrón que sprint/nado/empuje — sin estamina no hay impulso vertical.
- Validado: `--check-only`, import headless, 180 frames de runtime.

## 2026-07-12 — Fix: la curva de hambre→estamina era interpolada, no un escalón
- El pedido original era una función ESCALÓN: el techo se mantiene fijo dentro de un tramo y solo salta al cruzar el siguiente punto de control hacia abajo (ej.: de 69% a 51% de hambre el techo se queda en 80%; recién al llegar a 50% baja a 50%). La primera implementación interpolaba linealmente entre puntos, dando una caída continua no deseada.
- `get_stamina_max()` reescrito como escalón real: itera los tramos de mayor a menor umbral, se queda con el valor del último umbral no superado.
- Bug de precisión de punto flotante detectado al verificar: `hunger/hunger_max` para hambre=70.0 no da exactamente `0.7`, así que la comparación `<=` fallaba justo en el borde (70.0 caía en el tramo de 100% en vez de saltar a 80%). Se agregó `STEP_EPSILON = 0.0001` a la comparación para que los umbrales exactos sí disparen el escalón.
- Verificado numéricamente en todos los bordes (71→100, 70→80, 51→80, 50→50, 21→50, 20→40, 19→40, 0→30) y con `--check-only`/import/180 frames de runtime.

## 2026-07-12 — Fix: la barra de estamina no reflejaba la penalización del hambre
- `DebugHUD._on_stat_changed` seteaba `bar.max_value = max_value` con el techo dinámico (`smax`) emitido por `PlayerStats`. Como `stamina` ya viene clamped a ese mismo `smax`, value==max_value siempre → la barra se veía llena al 100% aunque el techo real hubiera bajado por hambre: el dato existía, el HUD lo ocultaba.
- Fix: los `max_value` de las 3 barras quedan fijos (`hp_max`, `stamina_max_base`, `hunger_max`) desde `_ready()`; cada `stat_changed` solo actualiza `.value`. Ahora la barra de estamina se ve visiblemente más corta cuando el hambre reduce su techo (curva de [[ADR-003 Sistema de Nado, Estamina e Interacción]]).
- Validado: `--check-only`, import headless, 180 frames de runtime.

## 2026-07-12 — Fix: curva de hambre→estamina por tramos
- `PlayerStats.get_stamina_max()` usaba un solo `lerp` lineal (30%→100%) que no reflejaba ningún tramo perceptible cerca del 100% de hambre. Reemplazado por una curva de puntos de control interpolada linealmente por tramos: hambre 100%→techo 100%, 70%→80%, 50%→50%, 20%→40%, 0%→30%.
- Verificado numéricamente (script headless descartable) y con `--check-only`/import/180 frames de runtime.

## 2026-07-12 — Fixes post-Fase 1: controles de nado, empuje fantasma del Cube, salto al salir del agua
- **Controles de nado invertidos**: `_physics_swimming` negaba `input_dir.y` al construir `swim_dir`, al revés que `_physics_normal`. Corregido a usar el mismo signo.
- **El Cube se movía al caminar encima**: `_interact_with_rigid_bodies` clasificaba con un solo umbral (`normal.y > 0.6` → peso, si no → empuje lateral). Los contactos con normal intermedia (ruido de `move_and_slide` al caminar cerca del borde de una superficie plana) caían en la rama de empuje y arrastraban el bote con cada paso. Se añadió una zona muerta 0.3–0.6 (ninguna de las dos ramas) que ignora esos contactos ambiguos, sin tocar el peso vertical (parado encima) ni el empuje lateral genuino (playa→mar) documentados en [[ADR-002 Estabilización Player-Cube]].
- **Impulso al salir del agua**: al transicionar `SWIMMING → NORMAL` mientras se mantiene "jump", se aplica ahora `climb_out_boost` (4.0, exportable) como salto asistido — sin esto, la velocidad horizontal de nado no bastaba para trepar el borde de una plataforma/bote.
- Validado: `--check-only`, import headless, 180 frames de runtime.

## 2026-07-12 — Fase 1 del roadmap: movimiento, nado, estamina, agarre
- Implementada la Fase 1 completa de [[Roadmap Prototipo SeaK]] sobre `Scripts/Player.gd` (extendido, no reescrito): máquina de estados `NORMAL/SWIMMING/CLINGING`, nado con detección de agua e histéresis, gravedad reducida, dirección 3D vía basis de cámara.
- Nuevo `Scripts/PlayerStats.gd` (Node, `class_name PlayerStats`): hp/estamina/hambre con señales; hambre reduce el techo de estamina en vez de matar directo.
- Nuevo `Scripts/DebugHUD.gd`: HUD sin arte (ProgressBars) conectado a las señales de PlayerStats.
- Agarrar/cargar objetos livianos vía "mano cinemática" (velocidad conducida hacia un `HoldPoint`) en vez de joints; empuje sostenido activo para objetos pesados (`apply_force` + drenaje de estamina), distinto del empuje pasivo por colisión ya existente.
- `World.tscn`: añadidos `PlayerStats`, `HoldPoint` (Marker3D bajo la cámara), `DebugHUD` (CanvasLayer+Control), y un `Barrel` (RigidBody3D, masa 8) como objeto de prueba de agarre.
- `project.godot`: nueva acción de input `interact` (tecla E).
- Validación: `--check-only` en los 3 scripts, import headless completo, 180 frames de runtime sin errores.
- Creada: [[ADR-003 Sistema de Nado, Estamina e Interacción]]. Actualizada: [[Player Controller]].

## 2026-07-11 — Diseño del prototipo: análisis técnico + roadmap por fases
- Definida la premisa completa del juego: party game cooperativo (2-4), roguelike, vehículos modulares de basura, sin vida global del barco.
- Investigación: cuerpos compuestos vs joints en Jolt, mecánicas de *Raft* (sin física real — diferenciador de SeaK), bug godot#78750 (COM+inercia custom), daño por impulso de contacto, partición por componentes conexas.
- Creadas: [[Análisis Técnico Prototipo SeaK]] (arquitectura de los 6 sistemas: flotabilidad modular, BoatManager dinámico, fragmentación BFS, remo/pataleo, estamina/muerte asimétrica, 7 objetos de prueba) y [[Roadmap Prototipo SeaK]] (Fase 0 ✅ fundaciones → Fase 6 loop roguelike).
- Nueva carpeta wiki/design/ con [[wiki/design/_index|índice]].

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
