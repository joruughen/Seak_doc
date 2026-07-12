extends CharacterBody3D

enum State { NORMAL, SWIMMING, CLINGING }

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.8
const SENSITIVITY = 0.004

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Interacción con RigidBody3D (plataformas flotantes, cajas).
# El CharacterBody3D es cinemático: sin esto empuja con masa efectiva infinita.
@export var player_mass := 70.0   # kg transferidos como peso al pararse encima
@export var push_force := 200.0   # N de empuje lateral contra cuerpos dinámicos
@export var weight_damping := 300.0  # amortigua oscilaciones verticales en el punto de apoyo (N por m/s)
@export var weight_offset_smoothing := 6.0  # suaviza el punto donde se aplica el peso (más alto = sigue más rápido)
var _weight_offsets: Dictionary = {}  # RigidBody3D -> Vector3 offset suavizado

# --- Nado (Fase 1) ---
@export var swim_speed := 3.5
@export var swim_ascend_speed := 2.5
@export var water_gravity_scale := 0.15
@export var swim_stamina_cost := 8.0    # unidades/seg mientras se propulsa nadando
@export var climb_out_boost := 4.0      # impulso vertical al salir del agua sujetando salto (ayuda a subir a bordes/botes)
const FEET_OFFSET := 1.0                # aprox. mitad de altura de la cápsula (origin ≈ centro)
const SWIM_ENTER_DEPTH := 0.3           # profundidad en los pies para ENTRAR a nadar
const SWIM_EXIT_DEPTH := -0.2           # los pies deben salir por encima del agua para SALIR (histeresis)

# --- Sprint / Salto (drenan estamina en tierra) ---
@export var sprint_stamina_cost := 4.0  # unidades/seg corriendo
@export var jump_stamina_cost := 10.0   # unidades por salto (costo fijo, no por segundo)

# --- Agarrar / empujar (Fase 1) ---
@export var interact_range := 2.5
@export var carry_max_mass := 15.0      # piezas <= esto se cargan; más pesado, solo se empuja
@export var carry_catch_up_rate := 15.0 # 1/s: qué tan rápido cierra la distancia al HoldPoint (proporcional, no snap-en-1-frame)
@export var carry_speed_limit := 12.0   # tope de seguridad (evita atravesar geometría), ya no es el mecanismo principal de control
@export var push_hold_force := 400.0    # N continuos al empujar sostenido (además del choque pasivo)
@export var push_stamina_cost := 10.0   # unidades/seg empujando sostenido

var current_state: State = State.NORMAL
var held_body: RigidBody3D = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var hold_point = $Head/Camera3D/HoldPoint
@onready var stats: PlayerStats = $PlayerStats
@onready var water = get_node_or_null('/root/World/Water')


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))


func _physics_process(delta):
	_update_state()

	match current_state:
		State.SWIMMING:
			_physics_swimming(delta)
		State.CLINGING:
			# Se implementa en Fase 3 (Pataleo/Clinging). Por ahora se comporta
			# como Normal si algo llegara a fijar este estado.
			_physics_normal(delta)
		_:
			_physics_normal(delta)

	move_and_slide()
	# Gateado por colisión real (normal.y > 0.6 en _interact_with_rigid_bodies),
	# no por current_state: un gate binario por estado (SWIMMING vs NORMAL)
	# puede prenderse/apagarse en sincronía con el propio rebote del bote y
	# bombear energía en vez de amortiguarla (resonancia). La fuerza ahora
	# amortiguada (weight_damping) ya se ocupa de que no dispare velocidades.
	_interact_with_rigid_bodies(delta)
	_handle_interaction(delta)


func _water_depth_at_feet() -> float:
	if water == null:
		return -INF
	var water_y = water.get_height(global_position)
	var feet_y = global_position.y - FEET_OFFSET
	return water_y - feet_y


func _update_state():
	if current_state == State.CLINGING:
		return  # la salida de Clinging la gestiona su propio sistema (Fase 3)

	var depth := _water_depth_at_feet()
	if current_state == State.SWIMMING:
		if depth < SWIM_EXIT_DEPTH:
			current_state = State.NORMAL
			if Input.is_action_pressed("jump"):
				# Pequeño salto asistido al salir del agua sujetando espacio:
				# sin esto, la velocidad horizontal de nado no basta para
				# trepar el borde de un bote/plataforma.
				velocity.y = maxf(velocity.y, climb_out_boost)
	else:
		if depth > SWIM_ENTER_DEPTH:
			current_state = State.SWIMMING


func _physics_normal(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump (drena estamina; sin estamina no se puede saltar).
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if stats.drain_stamina(jump_stamina_cost):
			velocity.y = JUMP_VELOCITY

	# Handle Sprint (drena estamina; sin estamina no se puede sprintar).
	if Input.is_action_pressed("sprint") and not stats.is_exhausted():
		speed = SPRINT_SPEED
		if velocity.length() > 0.1:
			stats.drain_stamina(sprint_stamina_cost * delta)
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)


func _physics_swimming(delta):
	# Gravedad reducida: el jugador flota en vez de hundirse como una piedra.
	velocity.y -= gravity * water_gravity_scale * delta

	var input_dir = Input.get_vector("left", "right", "up", "down")
	var wants_to_move = input_dir.length() > 0.1
	var wants_to_ascend = Input.is_action_pressed("jump")

	# Dirección 3D completa (usa el pitch de la cámara): mirar hacia arriba/abajo
	# nadando te lleva hacia arriba/abajo, como en cualquier nado libre.
	# Mismo signo que _physics_normal (input_dir.y sin negar) — invertirlo aquí
	# hacía que W/S quedaran al revés solo al nadar.
	var swim_dir = (camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if wants_to_move and stats.drain_stamina(swim_stamina_cost * delta):
		velocity = velocity.lerp(swim_dir * swim_speed, delta * 4.0)
	else:
		# Sin estamina: deja de propulsar (deriva/se hunde lentamente), pero no muere aquí.
		velocity.x = lerp(velocity.x, 0.0, delta * 2.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 2.0)

	if wants_to_ascend and stats.drain_stamina(swim_stamina_cost * 0.5 * delta):
		velocity.y = lerp(velocity.y, swim_ascend_speed, delta * 4.0)

	camera.fov = lerp(camera.fov, BASE_FOV, delta * 8.0)


func _interact_with_rigid_bodies(delta):
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body == null:
			continue
		var normal := collision.get_normal()
		if normal.y > 0.6:
			# Parados encima: transferir el peso como fuerza continua en el
			# punto de contacto, para que la balsa se hunda de forma estable.
			#
			# El punto de contacto salta con cada paso/giro de cámara del
			# jugador (más aún corriendo o mirando alrededor erráticamente):
			# aplicar el peso ahí en crudo genera un torque casi aleatorio
			# cada frame, que ni el damping vertical alcanza a absorber —
			# el bote termina arrastrado/disparado en la dirección donde el
			# jugador se movió. Se suaviza el offset (low-pass) para que el
			# "centro de carga" solo pueda moverse gradualmente, no saltar.
			var raw_offset: Vector3 = collision.get_position() - body.global_position
			var offset: Vector3 = _weight_offsets.get(body, raw_offset)
			offset = offset.lerp(raw_offset, clampf(delta * weight_offset_smoothing, 0.0, 1.0))
			_weight_offsets[body] = offset

			var point_velocity_y := body.linear_velocity.y + body.angular_velocity.cross(offset).y
			var weight_force_y: float = -player_mass * gravity - weight_damping * point_velocity_y
			body.apply_force(Vector3(0.0, weight_force_y, 0.0), offset)
		elif normal.y < 0.3:
			# Contacto claramente lateral: empuje acotado en vez de la depenetración
			# de masa infinita del solver.
			body.apply_central_impulse(-normal * push_force * delta)
		# Zona muerta 0.3-0.6: el capsule reporta normales intermedias al caminar
		# cerca del borde de una superficie plana (ruido normal de move_and_slide).
		# Tratarlas como empuje lateral arrastraba el bote con cada paso al caminar
		# encima; se ignoran a propósito.


func _raycast_interact() -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * interact_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	return space_state.intersect_ray(query)


func _handle_interaction(delta):
	if held_body != null:
		if Input.is_action_just_pressed("interact") or not is_instance_valid(held_body):
			_release_held_body()
		else:
			_update_held_body(delta)
		return

	var hit := _raycast_interact()
	if hit.is_empty():
		return
	var body := hit.collider as RigidBody3D
	if body == null:
		return

	if Input.is_action_just_pressed("interact") and body.mass <= carry_max_mass:
		_grab(body)
	elif Input.is_action_pressed("interact") and body.mass > carry_max_mass:
		_push_held(body, delta)


func _grab(body: RigidBody3D):
	held_body = body
	# Sin esto, el objeto cargado choca contra la propia cápsula del jugador al
	# girar la cámara (el HoldPoint barre un arco alrededor del cuerpo) y sale
	# rotando/empujado en vez de seguir suavemente al punto de sostén.
	held_body.add_collision_exception_with(self)
	add_collision_exception_with(held_body)


func _release_held_body():
	if held_body and is_instance_valid(held_body):
		held_body.remove_collision_exception_with(self)
		remove_collision_exception_with(held_body)
	held_body = null


func _update_held_body(_delta):
	# Control proporcional (velocidad = distancia * tasa), no "distancia/delta":
	# dividir por delta intenta cerrar TODA la brecha en un solo frame de física,
	# lo que a 60 Hz exige velocidades enormes para cualquier separación real —
	# el tope (carry_speed_limit) se activaba todo el tiempo que el jugador
	# caminaba o giraba la cámara rápido, y el objeto se quedaba visiblemente
	# atrás hasta que el jugador se detenía y el punto de sostén dejaba de
	# moverse. Con velocidad proporcional a la distancia, el objeto acelera
	# solo lo necesario para alcanzar, sin depender de la duración del frame.
	var to_target = hold_point.global_position - held_body.global_position
	held_body.linear_velocity = (to_target * carry_catch_up_rate).limit_length(carry_speed_limit)
	held_body.angular_velocity = held_body.angular_velocity.lerp(Vector3.ZERO, 0.2)


func _push_held(body: RigidBody3D, delta):
	if not stats.drain_stamina(push_stamina_cost * delta):
		return
	var dir = -camera.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	body.apply_force(dir * push_hold_force, Vector3.ZERO)


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
