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
| `CROUCH_SPEED` | 2.5 | velocidad agachado |

## Flujo por frame físico (`_physics_process`)

1. Gravedad si no está en piso (`gravity = 9.8`, hardcodeada).
2. Salto (`is_on_floor()` + acción `jump`).
3. Selección de velocidad (sprint/walk).
4. Dirección desde `Input.get_vector` rotada por la base de `Head`.
5. En piso: velocidad directa; en aire: `lerp` con factor 3.0 (control aéreo reducido).
6. Head-bob y FOV según `velocity.length()`.
7. `move_and_slide()`.

## Interacción con la balsa

Ver [[CharacterController]] y [[Físicas de Flotabilidad]]. Resuelto en [[ADR-002 Estabilización Player-Cube]]: transferencia de peso + empuje lateral acotado contra RigidBody3D.

## Nado, estamina e interacción (Fase 1 del roadmap)

Ver [[ADR-003 Sistema de Nado, Estamina e Interacción]] para el detalle completo. Resumen:

- **Máquina de estados** `NORMAL / SWIMMING / CLINGING` (este último scaffolded, sin gameplay hasta Fase 3).
- **Nado**: detección de agua vía `water.get_height()` en los pies (con histéresis), gravedad reducida, dirección de nado usando el basis completo de la cámara (pitch incluido).
- **`PlayerStats`** (Node hijo): hp/estamina/hambre; el hambre reduce el techo de estamina, no mata directo (escalón: 100%→100%, 70%→80%, 50%→50%, 20%→30%, 0%→10%).
- **Salto y sprint drenan estamina**: salto cuesta `jump_stamina_cost=10` fijo por salto; sprint drena `sprint_stamina_cost` por segundo. Sin estamina, ninguno de los dos se ejecuta.
- **Agarrar/cargar** objetos livianos (masa ≤ 15) con una "mano cinemática" (conduce la velocidad del RigidBody hacia un `HoldPoint` frente a la cámara) en vez de joints.
- **Empujar sostenido** objetos pesados (masa > 15): `apply_force` continuo en la dirección de la cámara + drenaje de estamina — distinto del empuje pasivo por colisión de `_interact_with_rigid_bodies`.
- **`DebugHUD`**: barras de hp/estamina/hambre sin arte, conectadas a las señales de `PlayerStats`.

## Cámara y agachado (fix, 2026-07-12)

- **Pitch de cámara**: `[-80°, 60°]` (antes `[-40°, 60°]`) — el límite viejo no dejaba apuntar el raycast de agarre a objetos bajos/planos (Palé, Chapa) parado cerca. Ver [[ADR-004 Piezas Sueltas y Fix de Agarre Bajo]].
- **Agachado** (`crouch`, tecla Ctrl): baja `head.position.y` en `crouch_camera_drop=0.55` con transición suave y reduce velocidad a `CROUCH_SPEED`. Solo cámara+velocidad, sin resize de la cápsula de colisión. Nuevo, no estaba planeado en el roadmap — se agregó junto con el fix de pitch para que el jugador pueda agarrar piezas casi a ras de suelo.
