---
type: decision
status: done
date: 2026-07-14
owner: Claude + Jorge (propuestas técnicas revisadas de Gemini)
context: "Dos bugs reportados en el sistema de agarre/soldadura: la pieza sostenida no rota con la cámara, y los botes de varias piezas quedan con un hueco real al soldarlos (distinto del ya arreglado en ADR-007)"
tags: [decision, gameplay, physics, prototype, fase2]
created: 2026-07-14
updated: 2026-07-14
---

# ADR-008 — Rotación al Cargar (Cámara) y Bug de Signo en Botes Sostenidos

El usuario trajo dos propuestas técnicas de Gemini para validar antes de implementar. Se investigó el código actual (`Player.gd`, `PieceData.gd`, `BoatManager.gd`) vía graphify + lectura directa, y se contrastó cada propuesta contra evidencia empírica ya reunida en [[ADR-007 Modo Construcción — Ghost Preview y Snap]].

## Bug 1 — La pieza sostenida no rota con la cámara

**Diagnóstico de Gemini: correcto.** `_update_held_body()` solo controlaba `linear_velocity`; `angular_velocity` se amortiguaba hacia cero (`lerp(...,0.2)`) — nunca hubo control de rotación real, la pieza quedaba con el spin físico que tuviera al agarrarla.

**Propuesta de Gemini (diff de quaternion → eje-ángulo → `angular_velocity`): validada y adoptada**, con un ajuste: control **proporcional** (misma tasa que ya usa la posición, `carry_catch_up_rate`), no "en 1 frame" — exactamente la lección de [[ADR-003 Sistema de Nado, Estamina e Interacción]] sobre por qué dividir por delta exige velocidades absurdas. Nuevo par `carry_rotation_rate`/`carry_angular_speed_limit`, mismo patrón que `carry_catch_up_rate`/`carry_speed_limit`.

**Rotación objetivo elegida**: `camera.global_transform.basis * _manual_rotation` — la pieza gira con la cámara (arregla el bug), y R/T/Y siguen siendo el ajuste manual relativo a hacia dónde mirás. El ghost y la soldadura final **no** cambian: siguen usando `_manual_rotation` sola, en espacio mundial, sin la cámara — deliberado, no un descuido. Es lo que preserva la garantía de las 24 orientaciones "de cubo" (alineadas a ejes) que ADR-007 ya documentó como protección para `walkable`/`grabbable_edge` de Fase 3: si la orientación final dependiera de hacia dónde mirabas al soldar, esa garantía se pierde.

API nativa de Godot 4 usada (sin librerías externas): `Basis.get_rotation_quaternion()`, `Quaternion.get_axis()`/`.get_angle()`.

**Validado headless**: partiendo de un error de 90° entre la orientación de la pieza y la de la cámara, tras 1 segundo de control proporcional (`carry_rotation_rate=10`) el error residual baja a 1.47° — convergencia >98%, comportamiento de "resorte" esperable y consistente con el control de posición ya existente.

## Bug 2 — Huecos al soldar: la propuesta de Snap Points fue rechazada, y se encontró el bug real

**Diagnóstico de Gemini ("Síndrome del Bounding Box"): rechazado con evidencia.** `_held_half_extent_toward` nunca usó un bounding box genérico — usa la fórmula analítica EXACTA de proyección para `BoxShape3D` y `CylinderShape3D` (combinación tapa/radio para el cilindro). Ya validado en ADR-007: 64/64 combinaciones de rotación de una pieza suelta dan 0.0 de hueco, igual que soldar contra una pieza ya rotada dentro de un bote. La matemática de una sola pieza sostenida es correcta.

**Propuesta de Snap Points (Marker3D): rechazada.** No es solo una cuestión de eficiencia — es un downgrade de diseño: convierte "soldar en cualquier punto de contacto" (como soldadura real, lo que pide el análisis técnico: *"cualquier cosa es un chasis"*) en un sistema de sockets fijos (como Lego), exige autoría manual de marcadores por cara válida en cada pieza, y no resuelve nada que la matemática actual no resuelva ya para el caso validado.

**El bug real, encontrado al investigar por qué el usuario seguía viendo huecos DESPUÉS del fix de ADR-007**: un **error de signo**, invisible en todas las pruebas anteriores porque solo se manifiesta sosteniendo un **bote de 2+ piezas** (no una `LoosePiece` suelta).

`_held_half_extent_toward` iteraba las shapes del cuerpo sostenido y computaba, por cada una, `extent + pos_offset` (extensión de la shape + su posición local proyectada sobre la normal). Para una `LoosePiece`, el offset local siempre es 0 (mesh/shape centrados en el origen) — el signo nunca importó. Para un bote, cada pieza SÍ tiene un offset local real respecto a la raíz del `BoatManager`, y la fórmula correcta para que la pieza líder (la más cercana al objetivo) quede al ras es:

```
root = hit.position + normal · (extent − pos_offset)
```

no `extent + pos_offset`. Sumar en vez de restar empuja la raíz del bote por partida doble para cualquier pieza no centrada en el origen — el hueco resultante es proporcional a cuánto sobresale esa pieza del centro del bote, lo que explica por qué se notaba "sobre todo con las rotaciones" (rotar un bote asimétrico cambia cuál pieza es la líder y cuánto sobresale).

**Validado headless** (Barril+Tubo PVC soldados en un bote, sosteniendo ese bote y apuntando a una Puerta): distancia entre el centro de la pieza líder y el punto de contacto real bajó de **1.42 m** (bug) a **0.11 m** (correcto, consistente con el radio de la pieza + margen) tras el fix.

## Adenda: contacto asimétrico contra superficies curvas (2026-07-14)

Con el sign-fix ya aplicado, el usuario reportó una captura nueva: un cubo (Nevera) soldado contra el costado curvo de un cilindro (Barril) se veía "no conectado", casi flotando. Confirmado que la física SÍ estaba soldada (el usuario lo movió junto con el cilindro como un solo cuerpo) — el problema era puramente visual/geométrico.

**Límite real, no eliminable**: una pieza de caras planas apoyada contra un cilindro solo puede tocar en una línea de tangencia, nunca con toda la cara — igual que en la vida real (una tabla contra un tambor). Medido headless: las 4 esquinas de la cara de contacto quedaban a 0.50–0.59 m del eje del Barril (radio real 0.4 m) — un hueco de 10 a 18 cm, pero **asimétrico** (un borde casi tocando, el otro bien separado), lo que de lejos se leía como "no toca nada".

**Causa de la asimetría (sí corregible)**: `hit.normal` contra una superficie curva es una dirección radial cualquiera (ej. `(0.11, 0, 0.99)`), casi nunca exactamente un eje. Pero la pieza sostenida solo puede quedar con caras alineadas a los ejes (rotaciones de 90° de `_manual_rotation`) — empujarla a lo largo de esa normal diagonal, cuando la cara real que toca es perfectamente axial, descentraba el contacto.

**Fix**: nueva `_refine_contact_for_curved_target(hit)`, llamada al inicio de `_update_weld_preview()`. Si el objetivo golpeado es un `CylinderShape3D`, calcula la dirección radial real (proyectando el punto de impacto sobre el eje del cilindro) y la reemplaza por el eje de `_manual_rotation` (±X/±Y/±Z, las 6 caras posibles de la pieza) más parecido — así la normal usada para el offset SIEMPRE coincide con la cara real que va a tocar.

**Validado headless**: mismo caso (Nevera contra Barril) — la normal queda exactamente en un eje (`(0,0,1)`), y las 4 esquinas de la cara dan la MISMA distancia (0.516 m, valor exacto: `√(0.42² + 0.3²)`) en vez de 0.50/0.59 dispares. El hueco de curvatura sigue ahí (geometría real), pero ahora parejo en los 4 bordes.

## Adenda 2: margen de contacto reducido (2026-07-14)

Con la asimetría arreglada, el usuario preguntó qué controla el hueco restante entre piezas planas y redondas y cómo evitarlo. Se separaron dos componentes: (1) el margen fijo `+0.02` en `_compute_snap_transform` (colchón contra jitter físico, igual en toda soldadura), y (2) el hueco de curvatura en sí (geométrico, no eliminable, crece con el ancho de la pieza plana relativo al radio de la redonda). Se confirmó además que contra la **tapa plana** (arriba/abajo) de una pieza redonda el hueco ya es de solo el margen (~0.02 m, prácticamente nada) — el hueco grande es específico del costado curvo.

Se redujo el margen a `WELD_CONTACT_MARGIN := 0.005` (antes 0.02, ahora una constante nombrada en vez de un literal mágico). Antes de aplicarlo, se verificó headless que un rodamiento observado en la prueba (un bote Barril+Puerta recorriendo ~4.7 m tras soldarse) **no lo causaba el margen** — se reprodujo idéntico (8.36 vs 8.36 m/s de velocidad máxima) tanto con 0.02 como con 0.005: es comportamiento preexistente y físicamente esperable (el Barril es un cilindro; un compuesto asimétrico apoyado sobre su costado redondo puede rodar al asentarse, nada relacionado con el margen de contacto).

Relacionado: [[Roadmap Prototipo SeaK]], [[Análisis Técnico Prototipo SeaK]], [[ADR-007 Modo Construcción — Ghost Preview y Snap]].

## Resumen de cambios en `Scripts/Player.gd`

- `_update_held_body()`: agregado control proporcional de rotación (reemplaza el `angular_velocity.lerp(ZERO, 0.2)` que solo amortiguaba).
- Nuevos exports: `carry_rotation_rate := 10.0`, `carry_angular_speed_limit := 12.0`.
- `_held_half_extent_toward()`: `extent + pos_offset` → `extent - pos_offset`.
- Nueva `_refine_contact_for_curved_target(hit)`, llamada desde `_update_weld_preview()`: centra el contacto contra objetivos `CylinderShape3D`.

Relacionado: [[ADR-007 Modo Construcción — Ghost Preview y Snap]], [[ADR-005 BoatManager — Génesis de Botes]], [[ADR-003 Sistema de Nado, Estamina e Interacción]], [[Player Controller]].
