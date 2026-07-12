---
type: decision
status: done
date: 2026-07-12
owner: Claude + Jorge
context: "Implementación de la Fase 1 del roadmap del prototipo SeaK: el jugador vive en el mundo (corre, nada, se cansa, agarra y empuja cosas)"
tags: [decision, gameplay, physics, player, prototype]
created: 2026-07-12
updated: 2026-07-12
---

# ADR-003 — Sistema de Nado, Estamina e Interacción (Fase 1)

Implementa la Fase 1 de [[Roadmap Prototipo SeaK]]: máquina de estados del Player, nado, `PlayerStats`, HUD de debug, y agarrar/empujar objetos. Ver diseño previo en [[Análisis Técnico Prototipo SeaK]].

## Máquina de estados (`Player.gd`)

`enum State { NORMAL, SWIMMING, CLINGING }` con dispatch por `match` en `_physics_process`. `CLINGING` queda **scaffolded pero inalcanzable**: ningún código lo asigna todavía — se activa recién en Fase 3 (Pataleo/Clinging, bordes `grabbable_edge`). Decisión deliberada: declarar la forma del enum/match ahora evita un refactor de la máquina de estados cuando Fase 3 añada el tercer caso real.

**Detección de agua e histéresis:** `_water_depth_at_feet()` compara `water.get_height(global_position)` (la misma API que ya usa [[Cube Flotante]], mismo gemelo CPU-GPU) contra la posición de los pies (`global_position.y - FEET_OFFSET`, aprox. la mitad de la cápsula, ya que el origin del CharacterBody3D es su centro, no sus pies). Se entra a nadar con `depth > 0.3` y se sale con `depth < -0.2`: el margen asimétrico evita parpadeo de estado justo en la línea de flotación.

## Nado

Gravedad reducida (`water_gravity_scale = 0.15`) en vez de flotación por sondas — el jugador no es un cuerpo rígido, así que no necesita el sistema de boyancia de [[Físicas de Flotabilidad]], solo "caer" más lento en el agua.

**Dirección con el basis completo de la cámara** (`camera.global_transform.basis`), no solo `Head` (que es horizontal): mirar hacia arriba/abajo mientras se nada empuja al jugador hacia arriba/abajo, dando nado libre en 3D real sin código adicional de pitch.

## `PlayerStats` — hambre como techo, no como daño directo

`stamina_max = stamina_max_base · f(hunger%)`: el hambre en 0 no mata, encoge el tanque de estamina. `f` es una función **escalón** (no interpolada): el techo se mantiene fijo dentro de un tramo y solo salta al valor siguiente al cruzar el próximo punto de control hacia abajo — 100%→100%, 70%→80%, 50%→50%, 20%→30%, 0%→10%. Ej.: con hambre bajando de 69% a 51% el techo se queda en 80% todo el tramo; recién al tocar 50% baja a 50%. La caída final (20%→30%, 0%→10%) es agresiva a propósito: cerca de la inanición el jugador queda casi sin poder actuar. Esto es intencional (ver [[Análisis Técnico Prototipo SeaK]] §5): la presión sistémica del hambre debe sentirse en el core loop de exploración como golpes discretos, no como una erosión continua — la muerte real llega en Fase 5 vía ahogamiento/HP.

**Nota de precisión de punto flotante**: `hunger/hunger_max` para hambre exactamente en un umbral (ej. 70.0) no siempre da el literal exacto (`0.7`) por redondeo binario, así que la comparación del escalón falla justo en el borde sin tolerancia. Se agregó `STEP_EPSILON = 0.0001` a la comparación para que los umbrales exactos disparen el escalón de forma confiable.

`drain_stamina(amount) -> bool` devuelve `false` si ya está en 0: el llamador (nado, sprint, empuje sostenido) usa el valor de retorno para **cortar la propulsión sin necesidad de chequear `is_exhausted()` por separado en cada sitio** — evita el bug de "drenar en negativo" y centraliza la regla en un solo método.

## Agarrar y empujar — patrón "mano cinemática" en vez de joints

Para cargar objetos pequeños (ej. el Barril de prueba, masa 8 ≤ `carry_max_mass=15`) se evaluó `PinJoint3D`/`Generic6DOFJoint3D` contra **conducir la velocidad del RigidBody directamente hacia un punto objetivo** (`HoldPoint`, un `Marker3D` frente a la cámara):

```gdscript
held_body.linear_velocity = (hold_point.global_position - held_body.global_position) / delta
```

Se eligió la mano cinemática porque los joints en Godot 4 requieren que **ambos extremos sean `PhysicsBody3D`** — el punto de sostén conceptual (frente a la cámara del Player) no es un cuerpo físico, así que habría que crear un `StaticBody3D`/`RigidBody3D` invisible solo para anclar el joint, además de gestionar su ciclo de vida (crear al agarrar, liberar al soltar). Conducir la velocidad directamente es menos código, no dispara los problemas de estabilidad de joints en Jolt (8-12 iteraciones de solver para cadenas complejas, ver [[Análisis Técnico Prototipo SeaK]] §1), y da control total sobre el límite de velocidad (`carry_speed_limit`) para que el objeto cargado nunca atraviese geometría a alta velocidad.

**Umbral masa-agarrable vs masa-empujable** (`carry_max_mass = 15.0`) reemplaza el uso de grupos (`"carryable"`/`"pushable_large"`) planeado inicialmente en el análisis: la masa ya es el dato que distingue Barril (8, cargable) de Cube (200, solo empujable) sin necesitar etiquetar objetos en el editor — se simplifica hasta que Fase 2 introduzca `PieceData` con reglas más finas.

**Empuje sostenido** (`_push_held`) es una fuerza activa y continua (`apply_force` en dirección de cámara, sin componente vertical) distinta del empuje pasivo por colisión que ya existía en `_interact_with_rigid_bodies` (impulso de depenetración acotado): el pasivo resuelve el choque al caminar contra un cuerpo; el activo es una habilidad deliberada (mantener "interactuar" apuntando a algo pesado) que además cuesta estamina — necesaria para que "empujar el bote a la playa" sea una acción intencional del jugador, no un efecto secundario de caminar.

## Objeto de prueba

Se añadió un `Barrel` (RigidBody3D, masa 8, `CylinderShape3D`) directamente en `World.tscn` como placeholder de prueba — **no** es todavía una `LoosePiece` con `PieceData` (eso es Fase 2); solo valida el agarre/carga contra un objeto real.

## Validación

`--check-only` en `PlayerStats.gd`, `DebugHUD.gd`, `Player.gd`; import headless completo de `World.tscn` (nodos nuevos: `PlayerStats`, `HoldPoint`, `DebugHUD`+`Control`, `Barrel`); 180 frames de runtime sin errores. Pendiente: prueba manual del usuario en el editor (nado, drenaje de estamina, agarre del barril, empuje del Cube).

## Fixes tras la primera prueba manual (2026-07-12)

Tres bugs reportados al probar la Fase 1 en el editor:

1. **Controles de nado invertidos**: `swim_dir` construía `Vector3(input_dir.x, 0, -input_dir.y)` — negaba `input_dir.y` mientras que `_physics_normal` usa `input_dir.y` sin negar. Bastaba con quitar el signo para que W/S coincidieran con el movimiento en tierra.
2. **El Cube se arrastraba al caminar encima**: la clasificación arriba/lateral en `_interact_with_rigid_bodies` usaba un único umbral (`normal.y > 0.6`). Al caminar sobre una superficie plana, `move_and_slide` reporta ocasionalmente normales intermedias (0.3–0.6, ruido de contacto en el borde de la cápsula) que caían en la rama de empuje lateral (`apply_central_impulse`) — cada paso aplicaba un impulso horizontal real al bote, arrastrándolo. Fix: zona muerta 0.3–0.6 que no dispara ninguna rama. Se preserva intacto el peso vertical (parado encima, normal.y > 0.6) y el empuje lateral genuino contra normales claramente horizontales (normal.y < 0.3, ej. empujar el bote desde la playa).
3. **Falta impulso para subir a un borde/bote**: nadar no daba suficiente velocidad vertical para trepar una plataforma al llegar a su borde. Fix: al detectar la transición `SWIMMING → NORMAL` (salir del agua) mientras se mantiene "jump" presionado, se aplica `velocity.y = max(velocity.y, climb_out_boost)` — un mini-salto asistido, análogo al climb-out de juegos de nado tipo *Sea of Thieves*.

Validado de nuevo: `--check-only`, import headless, 180 frames de runtime.

## Ajustes de balance (2026-07-12)

- **Escalón de hambre endurecido**: `HUNGER_STAMINA_STEPS` cambió de `20%→40%, 0%→30%` a **`20%→30%, 0%→10%`** — la caída cerca de la inanición ahora es mucho más severa (a hambre 0 casi no queda tanque de estamina).
- **El salto ahora cuesta estamina**: `jump_stamina_cost = 10.0` (costo fijo por salto, no por segundo — a diferencia de sprint/nado/empuje que drenan por segundo). Mismo patrón que el resto de las acciones: `stats.drain_stamina(jump_stamina_cost)` gatea el salto — sin estamina, no hay impulso vertical. Se aplica solo al salto en tierra (`_physics_normal`); el ascenso nadando ya tenía su propio costo (`swim_stamina_cost * 0.5`).

Validado de nuevo: `--check-only`, import headless, 180 frames de runtime.

## Fixes de estabilidad: carga y resonancia nado-boyancia (2026-07-12)

Dos bugs adicionales, uno de la propia Fase 1 (omisión), otro de integración entre sistemas de fases distintas nunca probados juntos:

1. **El objeto cargado rotaba al girar la cámara**: el `HoldPoint` está fijo frente a la cámara, así que girar la cámara barre un arco — el objeto sostenido (ej. el Barril) chocaba contra la propia cápsula del jugador en ese arco, generando torque no deseado. Faltaba lo obvio: excluir esa colisión mientras dura el agarre. Fix: `_grab(body)` llama `add_collision_exception_with` en ambos sentidos (jugador↔objeto); `_release_held_body()` la revierte al soltar (o si el objeto se invalida mientras se sostiene).
2. **El Cube se disparaba a velocidades absurdas nadando parado encima suyo semihundido**: `_interact_with_rigid_bodies` (transferencia de peso de [[ADR-002 Estabilización Player-Cube]]) corría sin importar el estado del Player. Con el bote parcialmente hundido, los pies del jugador entran en zona de nado (`SWIMMING`) mientras la cápsula sigue tocando el Cube; el agua ya sostiene el peso del jugador en ese estado, así que sumarle ADEMÁS el peso completo (`player_mass*gravity` ≈ 686N) en un punto de contacto que cambia erráticamente por el movimiento libre de nado (sin `is_on_floor()`, sin fricción de piso) entraba en resonancia con el resorte-amortiguador de boyancia de [[Cube Flotante]] y disparaba velocidades crecientes sin control. Fix: `_interact_with_rigid_bodies` se salta por completo mientras `current_state == SWIMMING` — en tierra/de pie sigue funcionando igual que antes.

Ninguno de los dos estaba anotado en [[Roadmap Prototipo SeaK]] como tarea: el primero era una omisión de la Fase 1 ya implementada; el segundo, un caso de integración entre Fase 0 (boyancia) y Fase 1 (nado) que no se había probado en conjunto hasta ahora.

Validado: `--check-only`, import headless, 180 frames de runtime.

Relacionado: [[Roadmap Prototipo SeaK]], [[Análisis Técnico Prototipo SeaK]], [[Player Controller]], [[CharacterController]], [[Físicas de Flotabilidad]], [[Cube Flotante]].
