---
type: analysis
status: active
date: 2026-07-11
owner: Claude + Jorge
purpose: "Arquitectura y viabilidad en Godot 4 de los 6 sistemas del prototipo SeaK (party game cooperativo de supervivencia naval con vehículos modulares de basura)"
tags: [design, architecture, godot, physics, prototype]
created: 2026-07-11
updated: 2026-07-11
---

# Análisis Técnico — Prototipo SeaK

Premisa: party game cooperativo (2-4 jugadores), roguelike. Los jugadores ensamblan basura en embarcaciones para escapar de un archipiélago procedural. **El barco no tiene vida global: la supervivencia depende de las piezas.** Estilo low-poly, colisiones simples, física primero.

**Capital técnico ya construido** (según el grafo del proyecto): [[Físicas de Flotabilidad]] (boyancia por sondas, normalizada por masa, amortiguada — [[ADR-002 Estabilización Player-Cube]]), [[Sincronización CPU-GPU de Olas]] ([[ADR-001 Refactor del Shader de Agua]]) y [[CharacterController]] (interacción estable cinemático↔dinámico). Los 6 sistemas de abajo **extienden estos tres pilares**, no parten de cero.

---

## 1. Flotabilidad y Físicas Modulares

**Decisión central: un solo `RigidBody3D` por embarcación (cuerpo compuesto), nunca un RigidBody por pieza unido con joints.**

- En Jolt, las cadenas de joints necesitan 8–12 iteraciones de solver para no vibrar (defecto: 4) y aun así son frágiles con 10+ cuerpos. Un cuerpo compuesto (múltiples `CollisionShape3D` hijas de un solo `RigidBody3D`) es soportado nativamente, estable y O(1) para el solver por bote.
- Referencia de industria: *Raft* ni siquiera simula boyancia real (cuenta fundaciones y no tiene integridad estructural). SeaK se diferencia usando **física real barata**: el patrón de sondas ya validado en [[Cube Flotante]].

**Boyancia por pieza (extensión directa del sistema actual):**
- Cada pieza ensamblada aporta 1–4 sondas (según tamaño) a la lista de sondas del bote.
- Cada arquetipo de pieza tiene un `buoyancy_factor` (barril 2.5, madera ~1.2, metal 0.3 → se hunde) que multiplica la fuerza de la sonda.
- La fuerza se aplica **en la posición de la sonda** (`apply_force(F, offset)`) → el balance de peso, la escora y el torque **emergen solos**: cargar todo el metal a babor escora el bote sin una sola línea de código extra.
- Se mantiene la fórmula ya tuneada: resorte `k·depth` normalizado por masa + amortiguación `−c·v_y(punto)` por sonda ([[Físicas de Flotabilidad]]).

**Masa y centro de masa:**
- `mass = Σ masas de piezas`. `center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM` con el promedio ponderado de las piezas, recalculado en cada ensamble/rotura.
- ⚠️ Bug conocido [godot#78750](https://github.com/godotengine/godot/issues/78750): setear **inercia custom + COM custom a la vez** corrompe `_inv_mass`. Regla: setear solo masa y COM; dejar que Jolt derive la inercia de las shapes.

**Presupuesto de rendimiento (objetivo: 4 botes × ~30 piezas a 60 Hz):**
- `get_height()` ya es O(1) (muestreo bilineal de imagen); coste total = nº sondas ≈ 30–120 muestras/tick — trivial.
- Cap duro de ~48 sondas por bote (piezas pequeñas comparten sonda).
- Shapes primitivas únicamente (Box, Cylinder, Capsule) — coherente con el estilo low-poly.
- El shader estilizado no cambia nada: la sync usa la misma textura de ruido ([[Sincronización CPU-GPU de Olas]]); para el look low-poly basta flat-shading y bajar la resolución del plano, la fórmula CPU-GPU es idéntica.

**Nodos Godot:** `RigidBody3D` (BoatBody), `CollisionShape3D` (una por pieza), `Marker3D` (sondas), `ShaderMaterial` (agua ya existente).

---

## 2. Generación Dinámica del Bote ("Cualquier cosa es un chasis")

**Patrón: el bote es un dato (grafo de conexiones) + un contenedor físico (RigidBody3D) generado bajo demanda.**

**Dos estados por pieza:**
| Estado | Nodo | Cuándo |
|---|---|---|
| `LoosePiece` | `RigidBody3D` individual (flota solo con 1 sonda) | en la playa, escombro en el mar |
| `AttachedPiece` | `Node3D` + `CollisionShape3D` bajo el BoatBody | soldada a un bote |

**Génesis del BoatManager** (pegar barril + puerta, ninguno pertenece a un bote):
1. Instanciar `BoatManager` (script sobre `RigidBody3D`) en el centroide de ambas piezas.
2. Migrar mesh + shape de cada pieza como hijas del nuevo cuerpo (transform relativo preservado); liberar los `RigidBody3D` sueltos.
3. Transferir `linear_velocity` (promedio ponderado por masa) para que no haya "tirón".
4. Registrar la arista A↔B en el **ConnectionGraph** y recalcular masa/COM/sondas.
- Pegar una pieza a un bote existente = solo pasos 2–4. Pegar dos botes = fusionar grafos y migrar todo al mayor.

**ConnectionGraph — la verdad estructural es el grafo, no el scene tree:**
- `Dictionary piece_id → Array[piece_id vecinos soldados]`, mantenido por el BoatManager.
- El scene tree bajo el BoatBody se mantiene **plano** (todas las piezas hijas directas) para evitar cadenas de transforms; la topología vive solo en el grafo. Este dato es el que consume la fragmentación (sistema 3).

**Ensamblaje en vista FPS:**
- `RayCast3D` desde la cámara (ya existe la jerarquía Head→Camera3D del [[Player Controller]]).
- Ghost preview: duplicado del mesh con material transparente verde/rojo (válido/inválido).
- Snap asistido, no CAD libre: snap a superficie + rejilla de 0.25 m + rotaciones de 90°. Es un party game: la fricción de construcción debe ser mínima.
- Confirmar → weld (efecto "pegamento/cuerda", sin física de junta: la soldadura es rígida por definición del cuerpo compuesto).

**Empuje playa → mar:**
- Reutiliza tal cual el patrón de [[ADR-002 Estabilización Player-Cube]]: transferencia de peso + `apply_central_impulse` acotado.
- Interacción "agarrar y empujar": mientras el jugador agarra el bote varado, aplica `apply_force` continuo en el punto de agarre y drena estamina. La arena tiene fricción física alta → **empujar en equipo importa**: 2 jugadores suman fuerza y vencen la fricción estática que 1 solo no vence. Mecánica cooperativa gratis, cero código especial.

**Nodos Godot:** `RigidBody3D`, `RayCast3D`, `Marker3D` (snap points opcionales), `Area3D` (zona de interacción de agarre).

---

## 3. Destrucción y Fragmentación Dinámica

**HP por pieza + daño por impulso de contacto + partición por componentes conexas.**

**Detección de daño:**
- En el BoatBody: `contact_monitor = true`, `max_contacts_reported = 8`.
- En `_integrate_forces(state)`: iterar contactos, `state.get_contact_impulse(i)` da el impulso real del solver y `state.get_contact_local_shape(i)` da el **índice de shape** → mapa `shape_index → pieza` (mantenido al migrar shapes).
- `impulso > umbral_pieza` → `daño = k · (impulso − umbral)`. Choque lento contra roca = nada; embestida = daño a LA pieza que tocó. Sin vida global, como pide el diseño.

**Partición estructural (el corazón del sistema):**
1. Pieza llega a HP 0 → se elimina su vértice del ConnectionGraph (+ efecto: mesh rota low-poly o partículas).
2. **BFS/flood-fill** sobre el grafo restante → lista de componentes conexas. Coste O(V+E): para un bote de 100 piezas es ~microsegundos, se puede hacer el mismo frame.
3. Una sola componente → el bote sigue (solo recalcular masa/COM/sondas).
4. N componentes → **la mayor conserva el BoatManager original** (sin tocar sus velocidades); cada componente extra recibe un BoatManager nuevo con velocidades heredadas: `v = v_original + ω × r` en su centroide (el pedazo que se desprende "sale volando" correctamente).
5. Componente de 1 pieza → degrada a `LoosePiece` (escombro flotante recolectable — el naufragio deja botín).

Es el patrón estándar de *Besiege*/*Trailmakers*/constructores con integridad estructural: la estructura es un grafo, la rotura es teoría de grafos, la física solo recibe el resultado.

**Nodos/APIs Godot:** `RigidBody3D.contact_monitor`, `PhysicsDirectBodyState3D.get_contact_impulse/get_contact_local_shape`, `apply_impulse` (knockback opcional).

---

## 4. Navegación Principal y de Emergencia

**Remo (primaria) — el torque emerge de la posición:**
- `RowingStation`: `Marker3D` (asiento) + `Area3D` (interacción), colocable sobre piezas planas.
- Remar = `apply_force(dir · F(estamina, ritmo), station_offset)` sobre el BoatBody. **Sin motor central falso**: remar solo del lado derecho gira el bote a la izquierda porque la fuerza está aplicada fuera del COM — física pura, igual que las sondas.
- El input rítmico (mantener/soltar al compás) da mejor F que spamear — coordinar el ritmo entre 2-4 jugadores es el chiste cooperativo.

**Pataleo (emergencia):**
- Piezas planas exponen bordes `grabbable_edge` (metadata + `Area3D` fina en el perímetro).
- El jugador nadando que agarra un borde pasa a estado `Clinging`: sigue cinemáticamente el punto del bote (mismo patrón de plataforma móvil que ya maneja el [[CharacterController]]).
- Patalear = `apply_force` pequeño en el punto de agarre + **drenaje rápido de estamina** (sistema 5). Suficiente para sacar un bote de una corriente, insostenible como propulsión.

**Nodos Godot:** `Marker3D`, `Area3D`, reutilización del patrón `apply_force(F, offset)` ya validado.

---

## 5. Estamina, Muerte Asimétrica y Anti-Exploits

**Todo es lógica de gameplay pura (sin física nueva): un componente de stats + una máquina de estados.**

**`PlayerStats` (Node hijo del Player):** `hp`, `stamina`, `hunger`; regla dura `stamina_max = base · f(hunger)` — el hambre no mata directo, te encoge el tanque (presión sistémica del core loop).

**Máquina de estados del Player** (enum + `match` en el prototipo; migrar a StateChart/plugin solo si crece):

```
Normal ⇄ Swimming ⇄ Clinging
Swimming + stamina=0 → Drowning → NáufragoCrítico (llega a la orilla del siguiente destino)
hp=0 (cualquier estado) → DeadSpectator
```

| Estado terminal | Cómo se entra | Penalización | Cómo se sale |
|---|---|---|---|
| **Náufrago Crítico** | ahogo (stamina 0 nadando) | pierde TODO el inventario; lento (×0.5); no construye ni usa estatuas | un aliado le da comida (del inventario del barco) |
| **Muerto (espectador)** | HP 0 | cámara espectador, sin cuerpo | aliados vivos pagan materiales en la Estatua de Resurrección de la siguiente isla |

- **El anti-exploit queda codificado en las condiciones, no en reglas ad-hoc**: el náufrago no puede interactuar con estatuas → un jugador que se deja ahogar jamás puede revivir barato al equipo ni saltarse el nivel; y como revivir cuesta materiales *del barco*, morirse tiene precio colectivo.
- Arrastre del ahogado: cinemática pura (Tween/`PathFollow3D` hacia la orilla del destino) — no vale la pena simularlo.
- Game over roguelike: `RunManager` (autoload) observa los estados; `todos ∈ {DeadSpectator, NáufragoCrítico sin vivos}` → fin de run, reset a isla 1 con seed nuevo.

**Nodos Godot:** `Node` (stats/componentes), `Area3D` (estatua, orillas), `Tween`/`PathFollow3D` (arrastre), autoload `RunManager`.

---

## 6. Objetos del Prototipo (7 piezas de prueba)

Cada una testea un eje distinto del sistema. Todas con shapes primitivas (Box/Cylinder) y `PieceData` (resource): `mass`, `buoyancy_factor`, `hp`, `flags`.

| # | Objeto | Masa | Buoy. | HP | Flags | Qué testea |
|---|---|---|---|---|---|---|
| 1 | **Barril de plástico** | 8 | 2.5 | 30 | — | flotación alta, el "salvavidas" del ensamble |
| 2 | **Puerta de madera** | 15 | 1.1 | 40 | `grabbable_edge`, `walkable`, admite RowingStation | plataforma: pataleo, remo, caminar encima |
| 3 | **Palé de madera** | 12 | 1.3 | 25 | `walkable` | pieza-puente barata: al romperse **parte el bote en dos** (test central del sistema 3) |
| 4 | **Nevera portátil** | 10 | 2.0 | 35 | `storage` (4 slots) | inventario embarcado; la comida anti-náufrago viaja aquí; pérdida de carga al fragmentar |
| 5 | **Chapa metálica** | 25 | 0.3 | 80 | `armor` | se hunde sola: trade-off blindaje vs escora — cargarla mal ladea el bote |
| 6 | **Neumático** | 9 | 1.6 | 60 | `bumper` (absorbe 50% impulso) | mitigación de daño contra rocas |
| 7 | **Tubo PVC** | 4 | 1.4 | 15 | — | conector ligero y frágil: eslabón débil, fragmentación en cadena |

**Costo inicial Estatua de Resurrección** (a tunear): revivir 1 jugador = 2 chatarra + 1 madera + 1 comida. Suficientemente caro para doler, no tanto como para abandonar la run.

---

## Riesgos principales

1. **Migración de shapes en runtime** (génesis/fusión de botes): reparentar shapes con transforms correctos es la parte más propensa a bugs — Fase 2 del [[Roadmap Prototipo SeaK]] la aísla y la testea sola, en tierra, antes de mojarla.
2. **COM custom + inercia** (godot#78750): regla de "solo masa + COM, nunca inercia custom" documentada arriba.
3. **Character sobre bote que se parte** bajo sus pies: el jugador debe re-resolver su plataforma; caso de prueba explícito en Fase 4.
4. **Escalado multiplayer**: el prototipo es física local single-instance; si se va a red, el BoatManager debe ser server-authoritative. Decisión diferida a post-prototipo (fuera de alcance actual).

5. **⚠️ BLOQUEANTE — colisión física directa Player↔bote es inestable bajo movimiento errático** (hallado 2026-07-12, diagnosticado con tests aislados en Godot headless):
   - **Síntoma**: parado/caminando sobre el Cube mientras se mueve erráticamente (simulando mouse-look + WASD real), el bote termina disparado a velocidades absurdas y a decenas de unidades de distancia — "rompiendo todo".
   - **Descartado por experimento**: (a) el motor NO empuja automáticamente un RigidBody3D por colisión de un CharacterBody3D (test aislado: caja quieta, `linear_velocity=0`, tras 60 frames de un CharacterBody3D intentando atravesarla). (b) el código propio de transferencia de peso (`_interact_with_rigid_bodies`) NO es la causa: con esa función completamente desactivada, el Cube igual explota exactamente igual. (c) la boyancia del Cube en sí NO es inestable: sin el jugador cerca, con el mismo `float_force` alto, se mantiene perfectamente estable.
   - **Causa real, confirmada por experimento**: la **resolución de contacto nativa de Godot/Jolt** entre el CharacterBody3D (cinemático) y el Cube (constantemente forzado por su propia boyancia). Con una excepción de colisión permanente (`add_collision_exception_with`) entre Player y Cube, el sistema vuelve a ser perfectamente estable bajo el mismo movimiento errático. Es decir: un cuerpo cinemático parado sobre un cuerpo dinámico que ADEMÁS recibe fuerzas externas grandes (boyancia) es un caso mal condicionado para el solver cuando la geometría de contacto cambia rápido (correr/girar la cámara) — no es algo ajustable con más damping o softening del lado del script.
   - **Fix correcto (diferido a Fase 2/3, no es un simple parche)**: eliminar la colisión física directa Player↔cuerpos flotantes (excepción permanente, mismo mecanismo ya usado para el objeto cargado) y reemplazar "pararse/caminar sobre el bote" por un sistema propio tipo *moving platform*: raycast hacia abajo para detectar que se está sobre un cuerpo flotante, seguir manualmente su altura/inclinación en ese punto, e inyectar su velocidad lineal+angular al jugador para que "viaje con" el bote. La transferencia de peso se re-aplica igual (`apply_force` en el punto detectado por raycast), pero ahora sin la restricción de contacto física que generaba la inestabilidad.
   - **Dónde encaja**: es, en esencia, parte de lo que Fase 3 (`Cube.gd` → `FloatingBody.gd`) ya iba a construir — se añade como tarea explícita ahí. Ver [[Roadmap Prototipo SeaK]] Fase 3.

Roadmap ejecutable: [[Roadmap Prototipo SeaK]].
Relacionado: [[overview]], [[Físicas de Flotabilidad]], [[CharacterController]], [[Sincronización CPU-GPU de Olas]], [[ADR-001 Refactor del Shader de Agua]], [[ADR-002 Estabilización Player-Cube]].
