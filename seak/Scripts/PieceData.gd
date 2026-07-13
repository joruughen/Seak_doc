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


func has_flag(flag_bit: int) -> bool:
	return (flags & flag_bit) != 0
