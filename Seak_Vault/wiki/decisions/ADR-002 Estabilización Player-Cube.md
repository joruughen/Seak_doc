---
type: decision
status: done
date: 2026-07-11
owner: Claude + Jorge
context: "Al subirse el Player al Cube flotante, la física se rompía y lo inestabilizaba violentamente"
tags: [decision, physics, buoyancy, character-body, jolt]
created: 2026-07-11
updated: 2026-07-11
---

# ADR-002 — Estabilización Player-Cube

## Problema

Cuatro causas apiladas (ver [[Físicas de Flotabilidad]] y [[CharacterController]]):

1. **Escala no uniforme (6.37, 0.50, 7.19) en el RigidBody3D** — Jolt no la soporta de forma estable; los contactos se recalculaban mal cada paso.
2. **Resorte de boyancia sin amortiguación** — la fuerza dependía solo de la profundidad; cualquier perturbación oscilaba sin converger.
3. **Masa 5 kg** para una balsa de 6.4×0.5×7.2 m — los impulsos de depenetración del Player (cuerpo cinemático = masa efectiva infinita) dominaban la dinámica.
4. **Sin gestión de la interacción cinemático↔dinámico** — `move_and_slide()` resolvía contra la balsa sin límite de fuerza.

## Decisión

**En `World.tscn`:**
- Escala movida del transform del Cube a `BoxShape3D.size` y `BoxMesh.size` (= `6.3657, 0.4967, 7.1852`); el cuerpo queda con basis identidad.
- Las 9 sondas reposicionadas a coordenadas reales (ej. `(3.034, -0.248, 3.813)`), que antes dependían de la escala del padre.
- Masa: 5 → **200 kg**.

**En `Cube.gd` — boyancia normalizada por masa y amortiguada:**
```gdscript
force_per_probe = mass * gravity * float_force / probes.size()
damp_per_probe  = mass * vertical_damping / probes.size()
buoyancy = force_per_probe * depth - damp_per_probe * point_velocity_y
```
- Normalizar por masa hace que la profundidad de equilibrio sea `1/float_force` = 0.2 m **independiente de la masa** — se puede subir la masa sin re-tunear.
- El término `-damp * v_y(punto)` (velocidad vertical del punto: `linear_velocity + angular_velocity × r`) convierte el resorte en resorte-amortiguador → converge en vez de oscilar.

**En `Player.gd` — interacción explícita con RigidBody3D:**
- Normal ~vertical (parado encima): `apply_force(DOWN * player_mass * gravity, punto_contacto)` — el peso (70 kg → 686 N) hunde la balsa solo **7 cm** extra (686 / (200·9.8·5)), estable y predecible.
- Normal lateral: `apply_central_impulse(-normal * push_force * delta)` — empuje acotado (200 N) en vez de depenetración infinita.

## Consecuencias

- El Player puede caminar sobre la balsa: esta se hunde levemente bajo su peso y se mece amortiguada.
- Nuevos exports tuneables: `vertical_damping` (Cube), `player_mass` y `push_force` (Player).
- La boyancia ahora lee la **misma ola que se dibuja** gracias a [[ADR-001 Refactor del Shader de Agua]].
- Validado: escena principal 120 frames en headless sin errores de física ni de scripts.

Relacionado: [[Cube Flotante]], [[Player Controller]], [[Escena World]].
