extends RigidBody3D

# Rigidez del resorte de boyancia. La fuerza total escala con la masa, así que
# la profundidad de hundimiento en equilibrio es 1.0 / float_force metros,
# independiente de la masa del cuerpo.
@export var float_force := 5.0
# Amortiguación vertical por sonda (proporcional a la velocidad del punto).
# Sin esto el resorte oscila para siempre y se inestabiliza con el Player encima.
@export var vertical_damping := 3.0
@export var water_drag := 0.05
@export var water_angular_drag := 0.05

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var water = get_node('/root/World/Water')

@onready var probes = $ProbeContainer.get_children()

var submerged := false


func _physics_process(_delta):
	submerged = false
	var force_per_probe := mass * gravity * float_force / probes.size()
	var damp_per_probe := mass * vertical_damping / probes.size()
	for p in probes:
		var depth: float = water.get_height(p.global_position) - p.global_position.y
		if depth > 0.0:
			submerged = true
			var offset: Vector3 = p.global_position - global_position
			var point_velocity_y := linear_velocity.y + angular_velocity.cross(offset).y
			var buoyancy := force_per_probe * depth - damp_per_probe * point_velocity_y
			apply_force(Vector3.UP * buoyancy, offset)


func _integrate_forces(state: PhysicsDirectBodyState3D):
	if submerged:
		state.linear_velocity *= 1.0 - water_drag
		state.angular_velocity *= 1.0 - water_angular_drag
