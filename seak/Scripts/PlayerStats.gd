extends Node
class_name PlayerStats

## Fase 1 del roadmap: hp/estamina/hambre puros (sin muerte todavía — eso es Fase 5).
## El hambre no mata directo: reduce el techo de estamina (get_stamina_max()).

signal stat_changed(stat_name: String, value: float, max_value: float)
signal exhausted

@export var hp_max := 100.0
@export var stamina_max_base := 100.0
@export var hunger_max := 100.0

@export var hunger_decay_rate := 0.15    # unidades/seg, decae siempre
@export var stamina_regen_rate := 12.0   # unidades/seg cuando no se drena
@export var stamina_regen_delay := 1.0   # seg de gracia tras el último drenaje

var hp: float
var stamina: float
var hunger: float

var _time_since_drain := 0.0


func _ready():
	hp = hp_max
	hunger = hunger_max
	stamina = get_stamina_max()


func _process(delta):
	hunger = maxf(0.0, hunger - hunger_decay_rate * delta)

	var smax := get_stamina_max()
	stamina = minf(stamina, smax)

	_time_since_drain += delta
	if _time_since_drain >= stamina_regen_delay:
		stamina = minf(smax, stamina + stamina_regen_rate * delta)

	stat_changed.emit("hp", hp, hp_max)
	stat_changed.emit("stamina", stamina, smax)
	stat_changed.emit("hunger", hunger, hunger_max)


## Tramos hambre% -> techo de estamina%, ordenados de mayor a menor hambre.
## Función ESCALÓN (no interpolada): el techo se mantiene fijo mientras el
## hambre se mueve dentro de un tramo, y solo salta al valor siguiente quien
## cruza el próximo punto hacia abajo. Ej.: con hambre bajando de 69% a 51%
## el techo se queda en 80% todo el tramo; recién al llegar a 50% baja a 50%.
const HUNGER_STAMINA_STEPS: Array[Vector2] = [
	Vector2(1.00, 1.00),
	Vector2(0.70, 0.80),
	Vector2(0.50, 0.50),
	Vector2(0.20, 0.30),
	Vector2(0.00, 0.10),
]


const STEP_EPSILON := 0.0001  # tolerancia para que hunger == umbral exacto (ej. 70.0) sí dispare el escalón, pese a errores de redondeo en hunger/hunger_max

func get_stamina_max() -> float:
	var hunger_fraction := hunger / hunger_max
	var factor := HUNGER_STAMINA_STEPS[0].y
	# Los tramos están ordenados de mayor a menor umbral: mientras el hambre
	# siga por debajo del umbral, nos quedamos con ESE valor y probamos el
	# siguiente (más estricto). En cuanto el hambre queda por ENCIMA de un
	# umbral, paramos — ya no hay tramo más ajustado que aplique.
	for step in HUNGER_STAMINA_STEPS:
		if hunger_fraction <= step.x + STEP_EPSILON:
			factor = step.y
		else:
			break
	return stamina_max_base * factor


func drain_stamina(amount: float) -> bool:
	if stamina <= 0.0:
		return false
	stamina = maxf(0.0, stamina - amount)
	_time_since_drain = 0.0
	if stamina <= 0.0:
		exhausted.emit()
	return true


func is_exhausted() -> bool:
	return stamina <= 0.0


func feed(amount: float):
	hunger = minf(hunger_max, hunger + amount)
