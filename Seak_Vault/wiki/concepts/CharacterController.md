---
type: concept
status: developing
purpose: "Interacción estable entre CharacterBody3D (cinemático) y RigidBody3D (dinámico) en Godot 4 + Jolt"
tags: [concept, physics, character-body, jolt]
created: 2026-07-11
updated: 2026-07-11
---

# CharacterController

Patrón de interacción entre un `CharacterBody3D` (cuerpo **cinemático**: se mueve por `move_and_slide()`, no responde a fuerzas) y un `RigidBody3D` (cuerpo **dinámico**: integra fuerzas).

## El problema fundamental

En Godot 4 el `CharacterBody3D` no tiene masa: cuando `move_and_slide()` resuelve una colisión contra un RigidBody, el solver lo trata como un obstáculo de **masa infinita**. Consecuencias sobre una balsa flotante:

- Al aterrizar, la depenetración empuja la balsa hacia abajo con fuerza arbitraria.
- La balsa se hunde → la boyancia (resorte) sobre-responde → la balsa sube de golpe → el Player pierde el piso → vuelve a caer → **feedback violento** ([[Físicas de Flotabilidad]]).
- Como plataforma móvil, el Character hereda `platform velocity`, lo que realimenta el ciclo.

## Receta estable (Godot 4 + Jolt)

1. **Transferencia de peso explícita**: si la colisión es con normal ~vertical (estamos parados encima), aplicar `apply_force(peso · DOWN, punto_de_contacto)` al RigidBody cada frame físico. El peso es un valor tuneable (`player_mass · gravity`), no un impulso.
2. **Empuje lateral escalado**: para normales ~horizontales, `apply_central_impulse(−normal · push_force · delta)` — nunca dejar que la depenetración haga el trabajo.
3. **Balsa masiva + boyancia normalizada por masa**: con masa alta (ej. 200 kg) y `F_boyancia ∝ mass`, el peso del jugador solo añade un hundimiento proporcional pequeño y predecible.
4. **Boyancia amortiguada**: sin damping por sonda, cualquier transferencia de peso excita oscilaciones.

Implementado en: [[Player Controller]] y [[Cube Flotante]].
