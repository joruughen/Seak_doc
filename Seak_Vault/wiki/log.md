---
type: meta
title: "Log de Operaciones"
created: 2026-07-11
updated: 2026-07-11
tags: [log]
---

# Log

<!-- append-only: entradas nuevas ARRIBA -->

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
