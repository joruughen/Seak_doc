---
type: roadmap
status: active
date: 2026-07-11
owner: Claude + Jorge
purpose: "Plan de desarrollo incremental del prototipo SeaK, por fases testeables"
tags: [design, roadmap, prototype, tasks]
created: 2026-07-11
updated: 2026-07-11
---

# Roadmap — Prototipo SeaK

Plan por fases incrementales. **Regla: cada fase termina con algo jugable/testeable en el editor**; no se abre la siguiente hasta que la "Definición de Hecho" (DoD) de la actual pase. Arquitectura de referencia: [[Análisis Técnico Prototipo SeaK]].

> [!key-insight] Estrategia
> El orden ataca el riesgo técnico primero: la migración de shapes en runtime (Fase 2) y la fragmentación (Fase 4) son lo único genuinamente difícil — todo lo demás es extensión de patrones ya validados en [[ADR-001 Refactor del Shader de Agua]] y [[ADR-002 Estabilización Player-Cube]].

---

## ✅ Fase 0 — Fundaciones (COMPLETADA 2026-07-11)

- [x] Boyancia por sondas amortiguada y normalizada por masa ([[Cube Flotante]])
- [x] Sincronización CPU-GPU de la ola (`wave_time` + gemelo `_wave_height`) ([[Sincronización CPU-GPU de Olas]])
- [x] Shader de agua estilizado multi-octava ([[ADR-001 Refactor del Shader de Agua]])
- [x] Interacción estable CharacterBody↔RigidBody: peso transferido + empuje acotado ([[ADR-002 Estabilización Player-Cube]])

---

## ✅ Fase 1 — Movimiento, Nado y Estamina (COMPLETADA 2026-07-12)

*Objetivo: el jugador vive en el mundo — corre, nada, se cansa, agarra cosas.*

- [x] Máquina de estados del Player: `Normal / Swimming / Clinging` (enum + match) — `Clinging` queda scaffolded, sin gameplay todavía (llega en Fase 3)
- [x] Nado: detección de agua vía `get_height()` vs posición del player; movimiento 3D flotante con gravedad reducida
- [x] Componente `PlayerStats` (Node): `hp`, `stamina`, `hunger` con señales de cambio
- [x] Drenaje de estamina: correr (lento), nadar (medio); regeneración en reposo
- [x] `stamina_max = base · f(hunger)`; hunger decae con el tiempo
- [x] HUD mínimo de debug: barras de hp/estamina/hambre (Label/ProgressBar, sin arte)
- [x] Pickup/carry de piezas sueltas pequeñas (raycast + agarre al `Marker3D` frente a la cámara)
- [x] Interacción "agarrar y empujar" objetos grandes: `apply_force` continuo en punto de agarre + drenaje de estamina

**DoD:** el jugador corre por la playa, nada alrededor del Cube actual, se agota nadando (sin muerte aún), levanta el Barril de prueba y empuja el Cube. Validado headless (check de los 3 scripts + import de la escena + 180 frames de runtime); pendiente prueba manual en el editor.

Detalle de la implementación: [[ADR-003 Sistema de Nado, Estamina e Interacción]].

---

## Fase 2 — Unión Dinámica de Objetos (⚠️ mayor riesgo técnico)

*Objetivo: "cualquier cosa es un chasis" — probado EN TIERRA, sin agua de por medio.*

- [x] Resource `PieceData`: `mass`, `buoyancy_factor`, `hp`, `flags` (walkable, grabbable_edge, storage, bumper, armor)
- [x] Escena `LoosePiece` (RigidBody3D + shape primitiva + PieceData) — instanciar los 7 objetos del prototipo
- [ ] Modo construcción FPS: `RayCast3D` desde cámara + ghost preview verde/rojo
- [ ] Snap asistido: superficie + rejilla 0.25 m + rotación 90°
- [ ] `BoatManager` (RigidBody3D): génesis al soldar 2 piezas sueltas — migrar meshes+shapes, liberar cuerpos, transferir velocidad ponderada
- [ ] Soldar pieza→bote existente (migración simple)
- [ ] Soldar bote→bote (fusión de grafos, migrar al mayor)
- [ ] `ConnectionGraph` (Dictionary piece_id→vecinos) mantenido en cada weld
- [ ] Recalcular `mass` y `center_of_mass` (COM custom, **nunca inercia custom** — godot#78750) en cada cambio
- [ ] Mapa `shape_index → piece_id` (lo consumirá la Fase 4)

**DoD:** en la playa, pego barril+puerta+palé en cualquier orden; el ensamble es UN RigidBody que empujo con la Fase 1; el inspector muestra masa y COM correctos; no hay tirones al soldar.

**Grupo 1 completado (2026-07-12)**: `PieceData` + `LoosePiece` + los 7 objetos de prueba instanciados en la playa. Detalle: [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]]. De paso se arregló un bug transversal (no de esta fase): el pitch de cámara topaba en -40° y no había agachado, por lo que las piezas bajas/planas (Palé, Chapa) eran casi imposibles de agarrar — ver mismo ADR.

---

## Fase 3 — Flotabilidad Modular y Navegación

*Objetivo: el ensamble navega — botadura, remo, pataleo, balance de peso.*

- [ ] ⚠️ BLOQUEANTE (diagnosticado 2026-07-12): reemplazar la colisión física directa Player↔bote por un sistema propio de "montar plataforma" (raycast hacia abajo + tracking manual de altura/inclinación + heredar velocidad lineal/angular del bote), con excepción de colisión permanente Player↔cuerpos flotantes. La colisión nativa Godot/Jolt entre un CharacterBody3D y un RigidBody3D constantemente forzado por boyancia es inestable bajo movimiento errático del jugador — confirmado con tests aislados, no se resuelve con damping/tuning. Detalle completo: [[Análisis Técnico Prototipo SeaK]] §Riesgos, riesgo 5.
- [ ] Generalizar `Cube.gd` → `FloatingBody.gd`: sondas dinámicas construidas desde las piezas (1–4 por pieza según tamaño, cap 48/bote)
- [ ] `buoyancy_factor` por pieza multiplicando la fuerza de su sonda
- [ ] `LoosePiece` flota solo (1 sonda central) — escombros y barriles a la deriva
- [ ] Botadura: empuje cooperativo playa→mar (fricción de arena alta; 2 jugadores > 1)
- [ ] Test de balance: chapa metálica a un lado → el bote escora visiblemente; distribuida → estable
- [ ] `RowingStation` (Marker3D+Area3D) colocable en piezas `walkable`: remar = `apply_force` en el offset del asiento (el torque emerge)
- [ ] Input rítmico de remo: F depende de estamina y cadencia
- [ ] Bordes `grabbable_edge`: estado `Clinging` (seguir punto del bote como plataforma móvil)
- [ ] Pataleo: `apply_force` pequeño en punto de agarre + drenaje rápido de estamina

**DoD:** 1-2 jugadores botan un bote de 5+ piezas, reman hasta mar abierto sorteando olas, la carga mal puesta escora, y un nadador puede empujar el bote pataleando hasta agotarse.

---

## Fase 4 — Destrucción y Fragmentación

*Objetivo: el bote se rompe por piezas y se parte en mitades navegables.*

- [ ] `contact_monitor + max_contacts_reported` en BoatManager; leer `get_contact_impulse/get_contact_local_shape` en `_integrate_forces`
- [ ] Daño por impulso: umbral por pieza, `daño = k·(impulso−umbral)`, ruteado vía mapa shape→pieza
- [ ] Flag `bumper` (neumático): absorbe 50% del impulso en su contacto
- [ ] Muerte de pieza: quitar del ConnectionGraph + despawn con partículas low-poly
- [ ] **BFS de componentes conexas** tras cada muerte de pieza
- [ ] Split: la componente mayor conserva el BoatManager; las demás → BoatManager nuevo con `v + ω×r` heredada
- [ ] Componente de 1 pieza → degradar a `LoosePiece` (escombro recolectable)
- [ ] Caso de prueba obligatorio: bote barril—palé—barril; disparar/chocar el palé central → **dos mitades navegables**
- [ ] Caso de prueba: jugador parado sobre la mitad que se desprende (re-resolución de plataforma, sin caer por el mundo)
- [ ] Rocas estáticas (StaticBody3D primitivas) como peligro de colisión en el mar

**DoD:** navegar contra una roca rompe la pieza de proa (o la salva el neumático); destruir la pieza-puente parte el bote en dos mitades que siguen flotando y se pueden remar por separado; la nevera al partirse suelta su carga.

---

## Fase 5 — Supervivencia, Muerte Asimétrica y Estatua

*Objetivo: las reglas roguelike y anti-exploit del diseño.*

- [ ] Estados terminales: `Drowning → NáufragoCrítico` y `DeadSpectator`
- [ ] Ahogo (stamina 0 nadando): arrastre cinemático (Tween/PathFollow3D) a la orilla del siguiente destino + drop total de inventario
- [ ] Náufrago Crítico: velocidad ×0.5, no construye, no interactúa con estatuas; se cura al recibir comida de un aliado
- [ ] Interacción "dar comida" entre jugadores (de inventario/nevera del barco)
- [ ] Muerte por HP 0: cámara espectador (seguir aliados)
- [ ] `ResurrectionStatue` (Area3D en cada isla): interactuable solo por vivos no-náufragos; costo 2 chatarra + 1 madera + 1 comida
- [ ] `RunManager` (autoload): observa estados; todos muertos/náufragos sin vivos → game over → reset de run
- [ ] Comida como item: restaura hunger (y por tanto stamina_max); spawn escaso en islas

**DoD:** un jugador se ahoga → aparece náufrago sin inventario en la isla destino y NO puede usar la estatua; otro muere por daño → espectador; el vivo llega, paga la estatua y lo revive; si mueren todos, la run reinicia.

---

## Fase 6 — Loop Roguelike Mínimo

*Objetivo: cerrar el core loop isla→mar→isla con presión sistémica.*

- [ ] Generador mínimo de archipiélago: 2-3 islas low-poly con seed (posición, tamaño, spawns de piezas/comida) — procedural simple, no terrain sculpting
- [ ] Spawns de basura por tabla de rareza en cada isla
- [ ] Dirección de viaje señalizada (siguiente isla visible en el horizonte)
- [ ] Estatua de Resurrección por isla (de Fase 5) como checkpoint del viaje
- [ ] Peligro móvil dummy: "tiburón" (RigidBody3D primitiva que embiste piezas exteriores cada N segundos) — solo para testear daño en travesía
- [ ] Ciclo completo: recolectar → construir → botar → navegar → llegar → repetir
- [ ] Game over + restart con seed nuevo (roguelike)
- [ ] Pase de tuning: pesos, costos de estatua, drenajes de estamina, HP de piezas (tabla en [[Análisis Técnico Prototipo SeaK]] §6)

**DoD:** una run completa de 2 islas jugable de principio a fin: se puede ganar llegando y se puede perder por naufragio total o muerte del equipo.

---

## Fuera de alcance del prototipo (decisión explícita)

- Multiplayer en red (el diseño es red-compatible: BoatManager centraliza autoridad, pero se implementa post-prototipo)
- Arte final, audio, UI real (todo placeholder low-poly/debug)
- Clima dinámico y hambre avanzada (solo el decay básico de Fase 1)
- IA real de enemigos (el tiburón dummy de Fase 6 no es la versión final)

Relacionado: [[Análisis Técnico Prototipo SeaK]], [[overview]], [[Físicas de Flotabilidad]], [[CharacterController]].
