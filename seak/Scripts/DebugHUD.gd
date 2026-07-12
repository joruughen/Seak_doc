extends CanvasLayer

## HUD de depuración para Fase 1 (sin arte): barras de hp/estamina/hambre.
## Se elimina/reemplaza cuando llegue el arte real.

@onready var stats: PlayerStats = get_parent().get_node("PlayerStats")
@onready var hp_bar: ProgressBar = $Control/VBox/HPBar
@onready var stamina_bar: ProgressBar = $Control/VBox/StaminaBar
@onready var hunger_bar: ProgressBar = $Control/VBox/HungerBar


func _ready():
	# El tope visual de cada barra queda FIJO (el máximo base, no el techo de
	# estamina ya reducido por hambre). Si max_value siguiera al techo dinámico,
	# stamina quedaba clamped a ese mismo techo y la barra se veía siempre
	# "llena" (value == max_value) aunque el techo real hubiera bajado — la
	# penalización del hambre existía en los datos pero era invisible en el HUD.
	hp_bar.max_value = stats.hp_max
	stamina_bar.max_value = stats.stamina_max_base
	hunger_bar.max_value = stats.hunger_max
	stats.stat_changed.connect(_on_stat_changed)


func _on_stat_changed(stat_name: String, value: float, _max_value: float):
	match stat_name:
		"hp":
			hp_bar.value = value
		"stamina":
			stamina_bar.value = value
		"hunger":
			hunger_bar.value = value
