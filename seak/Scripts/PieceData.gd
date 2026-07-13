extends Resource
class_name PieceData

## Fase 2 del roadmap: datos puros de una pieza ensamblable. Sin lógica de
## física aquí — eso llega con FloatingBody (Fase 3) y BoatManager (Fase 2 Grupo 2).

@export var piece_name := ""
@export var mass := 1.0
@export var buoyancy_factor := 1.0
@export var hp := 10.0

@export_flags("walkable", "grabbable_edge", "storage", "bumper", "armor") var flags := 0

## Solo relevante si el flag "storage" está activo.
@export var storage_slots := 0

## Escala visual (solo la malla, no la colisión) mientras el jugador sostiene
## esta pieza — para que no tape tanto la vista al apuntar dónde soldarla.
## Ajustable por pieza: si alguna se ve muy grande/chica reducida, corregir acá.
@export_range(0.1, 1.0, 0.05) var held_view_scale := 0.5


func has_flag(flag_bit: int) -> bool:
	return (flags & flag_bit) != 0
