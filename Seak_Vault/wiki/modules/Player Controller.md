---
type: module
path: "Scripts/Player.gd"
status: active
language: gdscript
purpose: "Controlador en primera persona: movimiento WASD, sprint, salto, head-bob y FOV dinámico"
depends_on: []
used_by: ["Scenes/World.tscn"]
tags: [module, player, character-body]
created: 2026-07-11
updated: 2026-07-11
---

# Player Controller

`CharacterBody3D` con cápsula (`ConvexPolygonShape3D` generado) y jerarquía `Head → Camera3D` para separar yaw (cabeza) de pitch (cámara).

## Constantes

| Constante | Valor | Rol |
|---|---|---|
| `WALK_SPEED` | 5.0 | velocidad base |
| `SPRINT_SPEED` | 8.0 | con Shift |
| `JUMP_VELOCITY` | 4.8 | impulso de salto |
| `SENSITIVITY` | 0.004 | mouse-look |
| `BOB_FREQ` / `BOB_AMP` | 2.4 / 0.08 | head-bob senoidal |
| `BASE_FOV` / `FOV_CHANGE` | 75 / 1.5 | FOV escala con velocidad |

## Flujo por frame físico (`_physics_process`)

1. Gravedad si no está en piso (`gravity = 9.8`, hardcodeada).
2. Salto (`is_on_floor()` + acción `jump`).
3. Selección de velocidad (sprint/walk).
4. Dirección desde `Input.get_vector` rotada por la base de `Head`.
5. En piso: velocidad directa; en aire: `lerp` con factor 3.0 (control aéreo reducido).
6. Head-bob y FOV según `velocity.length()`.
7. `move_and_slide()`.

## Interacción con la balsa

Ver [[CharacterController]] y [[Físicas de Flotabilidad]]. Estado pre-refactor: el script **no gestiona colisiones contra RigidBody3D** — no transfiere peso ni limita el empuje cinemático, causa central de la inestabilidad al pararse sobre [[Cube Flotante]].
