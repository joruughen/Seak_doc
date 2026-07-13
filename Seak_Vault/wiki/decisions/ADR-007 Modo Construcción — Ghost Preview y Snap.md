---
type: decision
status: done
date: 2026-07-13
owner: Claude + Jorge
context: "Fase 2 Grupo 4 del roadmap: modo construcción real (ghost preview + snap), reemplaza el disparador de prueba (tecla G) de los Grupos 2-3"
tags: [decision, gameplay, ui, prototype, fase2]
created: 2026-07-13
updated: 2026-07-13
---

# ADR-007 — Modo Construcción: Ghost Preview y Snap (Fase 2 Grupo 4)

Los Grupos 2-3 ([[ADR-005 BoatManager — Génesis de Botes]], [[ADR-006 Extender Soldadura — Pieza a Bote y Fusión de Botes]]) usaban una tecla de prueba (**G**, acción `weld`) sin ningún feedback visual de qué se iba a soldar ni dónde. Este grupo lo reemplaza por el modo construcción real de [[Análisis Técnico Prototipo SeaK]] §2: *"RayCast3D desde la cámara + ghost preview verde/rojo... snap a superficie + rejilla 0.25m + rotaciones 90°... Confirmar → weld."*

## Decisión: confirmar con `interact` (E), no con una tecla nueva

El usuario preguntó explícitamente por qué haría falta "otra tecla" si ya existe `interact` para agarrar/soltar — y tenía razón: no hacía falta. Se retiró la acción `weld` de `project.godot` por completo. Ahora, sosteniendo una pieza o un bote:
- Si el raycast (apuntando con la cámara) encuentra un objetivo soldable → `interact` (E) **suelda** ahí.
- Si no hay objetivo válido → `interact` (E) **suelta** el objeto, exactamente el comportamiento de siempre.

Una sola tecla, dos resultados según haya o no un objetivo válido — no dos acciones separadas que el jugador tenga que recordar.

## Ghost preview

`_update_weld_preview()` corre cada frame mientras se sostiene una pieza/bote: raycast (excluyendo la pieza sostenida — está en la propia trayectoria del rayo, frente a la cámara) y, si encuentra algo, construye o reutiliza un `_ghost` (`Node3D` con un `MeshInstance3D` duplicado por cada mesh de la pieza/bote sostenido — un bote puede tener varios, ya que su árbol es plano). Color verde (`_ghost_material_valid`) si el objetivo es soldable (`LoosePiece` o `BoatManager`, y no la propia pieza sostenida); rojo (`_ghost_material_invalid`) en cualquier otro caso (ej. apuntar al Cube, o a un punto sin nada soldable). Los materiales son `StandardMaterial3D` translúcidos, sin sombra (`SHADING_MODE_UNSHADED`) y sin cull (`CULL_DISABLED`) — solo un indicador visual, no interactúa con la iluminación de la escena.

## Snap: rejilla 0.25m + rotación 90°

`_compute_snap_transform(hit)`: la posición del ghost es el punto de impacto (`hit.position`) desplazado un poco a lo largo de la normal (para asentar sobre la superficie, no enterrarse) y redondeado a la rejilla (`snap_grid_size = 0.25`, por eje). La rotación toma el yaw actual de la pieza sostenida y lo redondea al múltiplo de 90° más cercano (`snap_rotation_deg`), con pitch/roll en cero — coherente con que todas las piezas del prototipo son formas boxy/cilíndricas pensadas para apoyarse planas. Es deliberadamente una aproximación ("snap asistido, no CAD libre" — la fricción de construcción debe ser mínima, dice el propio análisis técnico), no un snap real a caras/bordes de la geometría.

## Confirmar en la pose exacta del ghost

Al confirmar, `_confirm_weld()` primero **mueve** la pieza sostenida al transform ya calculado del ghost (`held_body.global_transform = _weld_snap_transform`) y recién ahí llama a la función de soldadura correspondiente (`weld_two_loose_pieces`/`weld_piece_to_boat`/`weld_boats`, según la combinación pieza/bote, igual que en el Grupo 3). Sin este paso, el ghost mostraría una posición prolija con snap pero la pieza terminaría soldada donde sea que la mano cinemática la hubiera dejado flotando junto a la cámara — una discrepancia entre lo que el preview promete y lo que realmente pasa. Moverla justo antes de soldar cierra esa brecha sin tocar en nada la lógica de soldadura del Grupo 3.

## Ajuste tras feedback del usuario: la pieza sostenida tapaba la vista, y hacía falta control de rotación (2026-07-13)

Dos problemas reportados al probar el diseño del modo construcción (antes de implementarlo del todo):

**1. La pieza sostenida tapaba la vista al apuntar el ghost.** El `HoldPoint` estaba centrado frente a la cámara (`(0,0,-1.2)` local a `Camera3D`), así que la pieza real —flotando ahí mientras se apunta al destino— quedaba justo en el medio de la pantalla. Fix acordado con el usuario: `HoldPoint` bajado a `(0,-0.35,-1.0)` (más abajo y cerca, estilo "en la mano/cadera") **+ colisión completamente desactivada** en los `CollisionShape3D` de la pieza mientras se sostiene (`_set_held_collision_enabled()`). Sin la colisión desactivada, el `HoldPoint` más bajo haría que la pieza rozara el terreno u otras piezas en vez de seguir limpio a la mano cinemática. La colisión se reactiva en dos puntos: al soltar sin soldar (`_release_held_body`) y al confirmar la soldadura, ANTES de mover la pieza a la pose del ghost y migrarla (`_confirm_weld`) — si quedara desactivada, el shape migrado al `BoatManager` heredaría `disabled=true` y el bote nacería sin colisión real (mismo tipo de bug que ya se vio en [[ADR-005 BoatManager — Génesis de Botes]], por otra causa).

**2. Sin control de rotación, era difícil ensamblar piezas a gusto.** El snap original derivaba la rotación del ghost del tumbado físico aleatorio de la pieza sostenida — el jugador no tenía forma de decidir cómo quedaba orientada. Se evaluó con el usuario si permitir rotación libre en los 3 ejes (pitch/yaw/roll) rompería algo del plan: **sí, en teoría** — `walkable`, `grabbable_edge` y `RowingStation` ([[Análisis Técnico Prototipo SeaK]] §4-6, tabla de piezas) asumen que la pieza está en su orientación "de pie" natural; una pieza `walkable` rotada de canto seguiría teniendo el flag activo sin que ninguna cara caminable quede realmente arriba. **Pero solo importa para Fase 3** (nada consume esos flags todavía) y **solo con ángulos intermedios** — restringiendo cada eje a pasos de 90° (no libre), la pieza siempre cae en una de las 24 orientaciones "de cubo", perfectamente alineada a ejes, nunca en diagonal. Se decidió: **3 ejes, 90° por tecla** — `rotate_yaw` (R), `rotate_pitch` (T), `rotate_roll` (Y), cada una rotando `_manual_rotation` (un `Basis` acumulado, reseteado a `IDENTITY` en cada `_grab()`) en su eje LOCAL (`Basis *= Basis(eje, 90°)`, no en el eje global — así las rotaciones compuestas se sienten predecibles, como girar un cubo). `_compute_snap_transform` ahora usa `_manual_rotation` directamente en vez de derivar el yaw del tumbado físico.

> [!warning] Pendiente para Fase 3
> Cuando se implementen `walkable`/`grabbable_edge`/`RowingStation`, esos sistemas deberán ser conscientes de la orientación REAL de la pieza (qué cara del mundo queda hacia arriba), no solo confiar en el flag de `PieceData` — una pieza `walkable` rotada 90° en pitch/roll ya no tiene ninguna cara caminable hacia arriba, aunque el flag siga en `true`. Anotado aquí para no perderlo de vista.

**Validado headless**: colisión desactivada al agarrar (`CollisionShape3D.disabled == true`), reactivada tanto al soltar sin soldar como al confirmar (el shape migrado al bote queda `disabled == false`); rotación manual aplicada y reflejada exactamente en el ghost (`_ghost.global_transform.basis == _manual_rotation`); weld final con masa correcta (23, Barril+Puerta) igual que sin rotación.

## Segunda ronda de ajustes: tunneling, pitch asimétrico, precisión de encaje, vista tapada, y seguridad al soltar (2026-07-13)

Cinco problemas reportados al seguir probando el diseño del modo construcción:

**1. Piezas que se atraviesan al soldar (ej. Tubo PVC).** El snap empujaba la pieza un padding FIJO de `0.05` a lo largo de la normal del impacto, sin considerar el tamaño real de la pieza en esa dirección. El Tubo PVC (cilindro delgado, radio 0.05, altura 1.5) puede tener hasta 0.75 de semi-extensión si su lado largo queda mirando hacia la superficie tras rotarlo — muy por encima del padding fijo, así que la mayor parte de la pieza terminaba enterrada en el objetivo. Fix: `_held_half_extent_toward(world_normal)` calcula la semi-extensión REAL de cada `CollisionShape3D` de la pieza/bote sostenido a lo largo de esa dirección (fórmula exacta de proyección para `BoxShape3D`: suma de `|componente|·semieje`; para `CylinderShape3D`: combinación tapa/radio), usando la orientación que la pieza va a tener (`_manual_rotation`), no su tumbado físico actual. `_compute_snap_transform` ahora empuja `half_extent + 0.02` en vez de `0.05` fijos.

**2. Pitch de cámara asimétrico** (`[-80°,60°]`): quedó así desde ADR-004, que solo amplió el límite de "mirar abajo" sin tocar el de arriba. Con eso, apuntar el ghost hacia arriba estaba mucho más restringido que hacia abajo, sin ningún motivo de diseño. Fix: `[-80°, 80°]`, simétrico.

**3. Difícil encajar piezas "perfectas" borde a borde.** En gran parte resuelto por el fix #1 (la pieza ahora queda al ras de la superficie, no enterrada ni flotando con un hueco). Un encaje borde-a-borde realmente exacto (alinear el borde de la Chapa con el borde de otra pieza) excede lo que da un snap de rejilla 0.25m + rotación 90° — se deja así por ahora (coincide con "snap asistido, no CAD libre" del diseño); si sigue siendo un problema, la rejilla se puede afinar más adelante.

**4. La pieza sostenida seguía tapando mucha vista.** Se agregó `PieceData.held_view_scale` (`@export_range(0.1,1.0)`, default `0.5`) — factor de escala **solo visual** (la malla, no la colisión) aplicado a la pieza sostenida mientras se apunta. Customizable por pieza, tal como pidió el usuario, para poder ajustar después si alguna queda muy grande/chica reducida. El **ghost** en el destino sigue mostrando el tamaño ORIGINAL (no el encogido) — `_build_ghost_for` usa la escala guardada en `_held_original_mesh_scale`, no la actual, para que el preview siga siendo fiel al resultado final. No aplica a un bote sostenido (varias piezas encogiendo juntas se vería confuso).

**5. Seguridad al soltar sin colisión.** El usuario preguntó explícitamente: si la pieza queda atravesando el suelo u otro objeto mientras se sostiene (sin colisión) y se suelta ahí, ¿no se cae al vacío o queda atorada? Se reemplazó el enfoque anterior (desactivar `CollisionShape3D.disabled` por completo) por un esquema de **capas de colisión**: capa 1 = entorno (piso, isla, Cube — sin cambios, es el default de todo lo demás), capa 2 = piezas/botes (`LoosePiece.tscn` y `BoatManager` en su creación: `collision_layer=2, collision_mask=3`). Mientras se sostiene algo, se cambia a `collision_layer=0, collision_mask=1` — sigue colisionando contra el ENTORNO (nunca cae al vacío ni atraviesa el piso) pero deja de colisionar contra OTRAS piezas (no se traba raro mientras se carga cerca de otras). Al soltar o justo antes de confirmar una soldadura, se restaura `layer=2, mask=3`. Si al restaurar queda algo superpuesto con otra pieza, el motor la empuja afuera suavemente (depenetración normal de Godot) — un "pop" leve, no un enganche permanente ni una caída.

**Validado headless**: pitch ±80° confirmado; capas de colisión correctas en los 3 momentos (normal 2/3, sostenido 0/1, restaurado 2/3); escala de malla se reduce a `~0.5×` al agarrar y se restaura exacta al soltar; `_held_half_extent_toward` calcula `0.75` para el Tubo PVC acostado (mitad exacta de su altura 1.5) y el snap resultante empuja la pieza esa distancia en vez de los `0.05` fijos de antes; soldadura final con masa correcta (Tubo PVC + Puerta = 19).

## Tercera ronda: hueco visible entre Barril y Tubo PVC al soldar (2026-07-13)

Reportado con una captura: Barril y Tubo PVC quedaban soldados con un hueco visible entre ambos, en vez de tocarse. Reproducido headless (Barril apuntando a un Tubo PVC de pie): la posición "al ras" (`hit.position + hit.normal * (half_extent+0.02)`, el fix de la ronda anterior) daba un punto EXACTO de contacto — pero el paso siguiente, `pos = (pos/snap_grid_size).round()*snap_grid_size`, redondeaba los 3 ejes por igual a la rejilla de 0.25m, **incluyendo el eje de contacto**, moviéndolo hasta 0.125m — 0.052m de hueco medido en la reproducción, sin ninguna rotación de por medio.

**Primer intento**: dejar exacto solo el eje más alineado con la normal del impacto (`contact_axis`), redondeando los otros dos a la rejilla. Mejoró el eje de contacto (0 de hueco ahí), pero el Tubo PVC es tan angosto (radio 0.05) que redondear los ejes TANGENCIALES igual podía desplazar el punto de contacto hasta 0.125m — más que suficiente para dejarlo fuera del radio del tubo, reapareciendo el hueco por otro lado.

**Fix final**: se quitó la rejilla de posición por completo — sin una superficie plana grande todavía (el modo construcción actual solda entre piezas individuales, no sobre un casco extendido), alinear a una rejilla de 0.25m no aporta nada hoy y sí puede separar piezas angostas del punto de contacto exacto. `_compute_snap_transform` ahora devuelve la posición "al ras" (offset por tamaño real) sin ningún redondeo — dos piezas SIEMPRE quedan tocándose al confirmar. Se quitó `snap_grid_size` (ya no se usa). Si más adelante se agrega una superficie de casco donde alinear varios tablones en fila sí tenga sentido, se puede reintroducir una rejilla ahí, con más cuidado.

**Validado headless**: la reproducción exacta del bug (Barril apuntando a un Tubo PVC de pie) da ahora `0.0` de diferencia entre la posición al ras calculada y la posición final usada para soldar.

## Cuarta ronda: encogido perdido al sostener un bote ya soldado (2026-07-13)

Reportado con captura (varias piezas con huecos visibles entre sí): el usuario notó que, tras soldar dos piezas, sostener el BOTE resultante ya no aplicaba ningún encogido visual — `_apply_held_view_scale` explícitamente lo excluía (`held_body is LoosePiece` únicamente), así que el bote volvía a tapar la vista igual que antes de tener `held_view_scale`. Solución propuesta por el usuario y aplicada: cuando lo sostenido es un `BoatManager`, usar el `held_view_scale` **más chico** entre todas sus piezas (`_piece_data.values()`) y aplicarlo a todas las mallas del bote por igual. Validado headless: bote de 2 piezas (Barril, `held_view_scale=0.5`) se encoge a `0.5×` al agarrarlo y restaura `1.0×` exacto al soltar.

**Sobre los huecos con rotaciones** (la otra mitad de este reporte): se corrió un stress test headless de las 64 combinaciones posibles de rotación manual (4 yaw × 4 pitch × 4 roll) contra un objetivo fijo, y por separado un caso de soldar contra una pieza YA rotada dentro de un bote existente — **las dos pruebas dan `0.0` de hueco en todos los casos**. La matemática del snap (offset por tamaño real + eje de contacto exacto) se sostiene para cualquier rotación individual probada hasta ahora.

## Quinta ronda: encontrada la causa real de los huecos — el jugador empuja al objetivo sin querer (2026-07-13)

Con una segunda captura (ghost gigante verde, sostenía el Barril rotado con T apuntando a la punta del Tubo PVC) se aisló el problema real. Dos hallazgos distintos:

**El "ghost gigante" no era un bug.** Verificado headless: la escala del ghost es `(1,1,1)` exacta y su posición coincide al ras con el objetivo (`half_extent=0.54`, coherente). Lo que pasaba es que la cámara terminó a solo ~0.5m del objetivo (hubo que acercarse mucho para apuntar la punta angosta del tubo), y a esa distancia CUALQUIER objeto del tamaño del Barril (~0.8-0.9m) llena la pantalla — pura perspectiva, no una escala ni posición incorrectas. El usuario decidió no tocar esto (ya sabe que hay que alejarse de objetivos angostos).

**El hueco real sí se reprodujo**, y la causa es distinta a todo lo investigado antes: **el propio jugador empuja físicamente al objetivo** al pararse muy cerca para apuntarlo, usando el mecanismo de empuje que ya existe desde la Fase 1 (`_interact_with_rigid_bodies`, `push_force=200N`). Piezas livianas como el Tubo PVC (4 kg) se corren con solo rozarlas. Reproducido headless: con el jugador parado cerca 30 frames (0.5s), el tubo se corrió de su posición asentada por varios centímetros — más que suficiente para que la posición que el ghost ya había calculado (basada en dónde ESTABA el objetivo) dejara de coincidir con dónde terminó, produciendo el hueco al confirmar (o, en casos más extremos, que el objetivo se saliera del todo de la línea de mira y la soldadura fallara en silencio).

**Fix**: mientras `_weld_target` sea válido, se agrega una excepción de colisión temporal entre el jugador y ese objetivo (mismo mecanismo que ya existe para la pieza sostenida) — se actualiza cada vez que el objetivo apuntado cambia (`_update_weld_preview`) y se limpia en `_clear_weld_preview`. El jugador ya no puede empujar sin querer lo que está a punto de soldar.

**Validado headless**: con el Tubo PVC ya asentado en el piso (sin la excepción, esto habría producido varios cm de deriva como en la primera reproducción) y el jugador parado cerca 30 frames CON la excepción activa, la deriva bajó a `0.0015m` — prácticamente cero.

## Validación (ghost/snap básico)

Dos scripts headless (llamadas directas a `_grab`/`_update_weld_preview`/`_confirm_weld`, sin simular input real de teclado/mouse):
1. **Caso válido**: Barril sostenido apuntando a la Puerta a 2m → `_weld_target == Puerta`, ghost verde con 1 mesh, snap position `(0.0, 1.75, -2.0)` (múltiplo exacto de 0.25 en los 3 ejes). Al confirmar: Barril y Puerta se liberan, aparece un `BoatManager` nuevo con `mass=23` (2 piezas) — coincide con el Grupo 2/3.
2. **Caso inválido**: Barril sostenido apuntando al Cube (200 kg, no es `LoosePiece`/`BoatManager`) → `_weld_target == null`, ghost rojo. Confirmar solo suelta: el Barril sigue siendo una `LoosePiece` suelta, no se crea ningún bote.

Relacionado: [[Roadmap Prototipo SeaK]], [[Análisis Técnico Prototipo SeaK]], [[ADR-006 Extender Soldadura — Pieza a Bote y Fusión de Botes]], [[ADR-005 BoatManager — Génesis de Botes]], [[Player Controller]].
