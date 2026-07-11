---
type: concept
status: developing
purpose: "Modelo de boyancia por sondas: resorte-amortiguador contra la superficie del agua"
tags: [concept, physics, buoyancy, jolt]
created: 2026-07-11
updated: 2026-07-11
---

# Físicas de Flotabilidad

Modelo usado en SeaK: **boyancia por sondas** (probe-based buoyancy). En vez de calcular el volumen sumergido real, se distribuyen N puntos en el casco y cada uno aplica una fuerza vertical proporcional a su profundidad bajo la superficie de la ola.

## Física del modelo

Cada sonda es un **resorte**: `F = k · depth` (con `k = float_force · gravity`). Un resorte puro nunca converge — necesita **amortiguación** proporcional a la velocidad vertical del punto:

```
F = k·depth − c·v_y(punto)
v_y(punto) = (linear_velocity + angular_velocity × r).y
```

Sin el término `−c·v_y`, cualquier perturbación (el Player aterrizando, una ola rápida) provoca oscilación creciente. Esto es exactamente el bug pre-refactor de [[Cube Flotante]].

## Reglas de estabilidad (Godot 4 + Jolt)

1. **Nunca escalar un RigidBody3D** (y menos de forma no uniforme). El tamaño va en `CollisionShape3D.shape.size`.
2. **Amortiguar por sonda**, no solo con drag global multiplicativo.
3. **Normalizar por masa**: si la fuerza de boyancia escala con `mass`, la profundidad de equilibrio es independiente de la masa y se puede subir la masa de la balsa sin re-tunear.
4. **Masa realista**: una balsa de 6.4×0.5×7.2 m con masa 5 kg es dominada por cualquier contacto del Player; masas grandes hacen que el empuje cinemático sea despreciable.
5. La altura del agua consultada debe ser **la misma que se ve** ([[Sincronización CPU-GPU de Olas]]), o la balsa flota sobre una ola fantasma.

## Interacción con el CharacterBody3D

Un `CharacterBody3D` es cinemático: al chocar contra un RigidBody empuja con masa efectiva infinita. Sobre una balsa flotante esto excita el resorte de boyancia → feedback violento. Solución en [[CharacterController]]: transferir el peso del jugador como fuerza continua y limitar el empuje lateral por impulsos escalados.

Módulos que lo implementan: [[Cube Flotante]], [[Player Controller]], [[Sistema de Agua]].
