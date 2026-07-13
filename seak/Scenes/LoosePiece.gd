extends RigidBody3D
class_name LoosePiece

## Fase 2 Grupo 1: pieza suelta con datos (PieceData) pero sin boyancia ni
## soldadura todavía. Flota (Fase 3) y se suelda a un bote (Fase 2 Grupo 2)
## en tareas posteriores.

@export var piece_data: PieceData


func _ready():
	if piece_data:
		mass = piece_data.mass
