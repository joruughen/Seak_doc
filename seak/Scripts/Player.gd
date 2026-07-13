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
@export var carry_max_mass := 30.0      # piezas <= esto se cargan; más pesado, solo se empuja
# 30, no 15: el umbral viejo se ajustó en la Fase 1 solo para distinguir el
# Barril (8) del Cube (200). La Chapa metálica (Fase 2, 25 kg, la más pesada
# de las 7 piezas del prototipo) caía en la rama de "solo empujar" y nunca se
# podía agarrar. 30 deja las 7 piezas agarrables y el Cube (200) push-only.
@export var carry_catch_up_rate := 15.0 # 1/s: qué tan rápido cierra la distancia al HoldPoint (proporcional, no snap-en-1-frame)
@export var carry_speed_limit := 12.0   # tope de seguridad (evita atravesar geometría), ya no es el mecanismo principal de control
@export var push_hold_force := 400.0    # N continuos al empujar sostenido (además del choque pasivo)
@export var push_stamina_cost := 10.0   # unidades/seg empujando sostenido

# --- Modo construcción (Fase 2 Grupo 4): ghost preview + snap, confirmar con
# la misma tecla de interactuar (E) — no una tecla aparte. ---
@export var snap_rotation_deg := 90.0  # paso de rotación manual, en grados (3 ejes)
var _manual_rotation := Basis.IDENTITY  # rotación elegida a mano (R/T/Y), reemplaza el tumbado físico
var _ghost: Node3D = null
var _ghost_for_body: RigidBody3D = null
var _ghost_material_valid: StandardMaterial3D
var _ghost_material_invalid: StandardMaterial3D
var _weld_target: RigidBody3D = null
var _weld_target_shape_index := -1
var _weld_snap_transform := Transform3D.IDENTITY
var _held_original_mesh_scale: Dictionary = {}  # MeshInstance3D -> Vector3 escala original (antes de encoger para no tapar vista)
var _weld_target_exception: RigidBody3D = null  # objetivo con el que se agregó una excepción de colisión temporal (ver _update_weld_preview)

# Capas de colisión: 1 = entorno (default de todo lo demás), 2 = piezas/botes.
# Mientras se sostiene algo, se cambia a HELD_LAYER/HELD_MASK (solo entorno)
# para que nunca pueda caer al vacío pero tampoco se trabe contra otras
# piezas mientras se carga.
const PIECE_LAYER := 2
const PIECE_MASK := 3
const HELD_LAYER := 0
const HELD_MASK := 1

# --- Agachado (fix: sin esto la cámara no baja lo suficiente para apuntar a
# piezas bajas/planas paradas cerca, aun con el pitch ampliado a -80°) ---
const CROUCH_SPEED = 2.5
@export var crouch_camera_drop := 0.55  # cuánto baja la cámara agachado, en metros
@export var crouch_transition_speed := 8.0
var is_crouching := false

var current_state: State = State.NORMAL
var held_body: RigidBody3D = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var hold_point = $Head/Camera3D/HoldPoint
@onready var stats: PlayerStats = $PlayerStats
@onready var water = get_node_or_null('/root/World/Water')
@onready var head_stand_y: float = head.position.y


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ghost_material_valid = _make_ghost_material(Color(0.2, 1.0, 0.2, 0.45))
	_ghost_material_invalid = _make_ghost_material(Color(1.0, 0.2, 0.2, 0.45))


func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		# -80°/+80° (antes -80°/60°, asimétrico): el límite de "mirar arriba"
		# se quedó en 60° del template original cuando ADR-004 solo amplió el
		# de abajo — con eso, apuntar el ghost del modo construcción hacia
		# arriba quedaba mucho más restringido que hacia abajo sin motivo.
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _physics_process(delta):
	_update_state()
	_update_crouch(delta)

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


func _update_crouch(delta):
	# Solo tiene sentido parado en tierra; nadando ya se apunta con el pitch
	# completo (_physics_swimming usa el basis 3D de la cámara).
	is_crouching = Input.is_action_pressed("crouch") and current_state == State.NORMAL and is_on_floor()
	var target_y := head_stand_y - (crouch_camera_drop if is_crouching else 0.0)
	head.position.y = lerp(head.position.y, target_y, clampf(delta * crouch_transition_speed, 0.0, 1.0))


func _physics_normal(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump (drena estamina; sin estamina no se puede saltar).
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if stats.drain_stamina(jump_stamina_cost):
			velocity.y = JUMP_VELOCITY

	# Handle Sprint (drena estamina; sin estamina no se puede sprintar).
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and not stats.is_exhausted():
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


func _raycast_interact(extra_exclude: Array = []) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * interact_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self] + extra_exclude
	return space_state.intersect_ray(query)


func _handle_interaction(delta):
	if held_body != null:
		if not is_instance_valid(held_body):
			_release_held_body()
			return

		# Modo construcción (Fase 2 Grupo 4): sosteniendo una LoosePiece o un
		# bote, el raycast busca dónde soldarlo y muestra un ghost preview
		# (verde/rojo) en la posición con snap. Confirmar = la misma tecla de
		# interactuar (E): si hay un objetivo válido, suelda ahí; si no, suelta
		# el objeto como antes — no hace falta una tecla aparte.
		if held_body is LoosePiece or held_body is BoatManager:
			_handle_manual_rotation()
			_update_weld_preview()
			if Input.is_action_just_pressed("interact"):
				if _weld_target != null:
					_confirm_weld()
				else:
					_release_held_body()
				return
			_update_held_body(delta)
			return

		if Input.is_action_just_pressed("interact"):
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
	# rotando/empujado en vez de seguir suavemente al punto de sostén. Se
	# mantiene como refuerzo aunque abajo también se restringe la colisión
	# contra otras piezas mientras se sostiene.
	held_body.add_collision_exception_with(self)
	add_collision_exception_with(held_body)
	_set_held_collision_enabled(false)
	_manual_rotation = Basis.IDENTITY
	_apply_held_view_scale()


func _release_held_body():
	if held_body and is_instance_valid(held_body):
		_set_held_collision_enabled(true)
		held_body.remove_collision_exception_with(self)
		remove_collision_exception_with(held_body)
	_restore_held_view_scale()
	held_body = null
	_clear_weld_preview()


## Mientras se sostiene, la pieza deja de colisionar contra OTRAS piezas/botes
## (capa 2) pero sigue colisionando contra el entorno (capa 1: piso, isla,
## Cube) — nunca puede quedar flotando en el vacío ni atravesar el suelo si se
## suelta encima de él; a lo sumo, si queda un poco superpuesta con otra
## pieza al soltarla, el motor la empuja afuera suavemente al reactivar la
## colisión completa (un "pop" leve, no un enganche permanente).
func _set_held_collision_enabled(enabled: bool):
	if held_body == null:
		return
	held_body.collision_layer = PIECE_LAYER if enabled else HELD_LAYER
	held_body.collision_mask = PIECE_MASK if enabled else HELD_MASK


## Encoge solo la malla (no la colisión) de la pieza/bote sostenido, para que
## no tape tanto la vista al apuntar dónde soldarlo. Factor customizable por
## pieza (`PieceData.held_view_scale`); sosteniendo un bote ya soldado (varias
## piezas), se usa el factor MÁS CHICO entre todas sus piezas — sin esto, el
## bote se veía a tamaño completo y volvía a tapar la vista igual que antes
## de tener el encogido.
func _apply_held_view_scale():
	_held_original_mesh_scale.clear()
	var factor := 1.0
	if held_body is LoosePiece and held_body.piece_data:
		factor = held_body.piece_data.held_view_scale
	elif held_body is BoatManager:
		for pd in held_body._piece_data.values():
			factor = minf(factor, pd.held_view_scale)
	if factor >= 1.0:
		return
	for child in held_body.get_children():
		if child is MeshInstance3D:
			_held_original_mesh_scale[child] = child.scale
			child.scale *= factor


func _restore_held_view_scale():
	for mesh in _held_original_mesh_scale:
		if is_instance_valid(mesh):
			mesh.scale = _held_original_mesh_scale[mesh]
	_held_original_mesh_scale.clear()


## Rotación manual de la pieza sostenida, 90° por tecla en cada eje (Y=yaw,
# X=pitch, Z=roll — local a la orientación ya elegida, para que las
## rotaciones compuestas se sientan predecibles). Reemplaza al tumbado físico
## aleatorio: el jugador decide exactamente cómo queda, sin romper walkable/
## grabbable_edge de Fase 3 (90° en los 3 ejes mantiene la pieza siempre
## alineada a los ejes, nunca en un ángulo intermedio).
func _handle_manual_rotation():
	var step := deg_to_rad(snap_rotation_deg)
	if Input.is_action_just_pressed("rotate_yaw"):
		_manual_rotation *= Basis(Vector3.UP, step)
	if Input.is_action_just_pressed("rotate_pitch"):
		_manual_rotation *= Basis(Vector3.RIGHT, step)
	if Input.is_action_just_pressed("rotate_roll"):
		_manual_rotation *= Basis(Vector3.FORWARD, step)


## Ghost preview del modo construcción: raycast (excluyendo la pieza
## sostenida) para encontrar dónde soldar, snap de posición/rotación, y
## color verde/rojo según si el objetivo es válido (otra LoosePiece o bote).
func _update_weld_preview():
	var hit := _raycast_interact([held_body])
	if hit.is_empty():
		_clear_weld_preview()
		return

	var target := hit.collider as RigidBody3D
	var valid := target != null and target != held_body and (target is LoosePiece or target is BoatManager)

	if _ghost == null or _ghost_for_body != held_body:
		if _ghost:
			_ghost.queue_free()
		_ghost = _build_ghost_for(held_body)
		_ghost_for_body = held_body
		get_tree().root.add_child(_ghost)

	_weld_snap_transform = _compute_snap_transform(hit)
	_ghost.global_transform = _weld_snap_transform
	_ghost.visible = true
	var material := _ghost_material_valid if valid else _ghost_material_invalid
	for mesh_child in _ghost.get_children():
		mesh_child.material_override = material

	_weld_target = target if valid else null
	_weld_target_shape_index = hit.shape if valid else -1

	# El jugador puede empujar sin querer el objetivo (mecanismo de empuje de
	# la Fase 1, _interact_with_rigid_bodies) por estar parado muy cerca para
	# apuntarlo — piezas livianas como el Tubo PVC (4 kg) se corren con solo
	# rozarlas, invalidando la posición que el ghost ya calculó y dejando un
	# hueco (o fallando la soldadura) al confirmar. Excepción de colisión
	# temporal con el objetivo mientras sea válido, igual que ya se hace con
	# la pieza sostenida.
	var new_exception: RigidBody3D = _weld_target
	if new_exception != _weld_target_exception:
		if _weld_target_exception and is_instance_valid(_weld_target_exception):
			remove_collision_exception_with(_weld_target_exception)
			_weld_target_exception.remove_collision_exception_with(self)
		if new_exception:
			add_collision_exception_with(new_exception)
			new_exception.add_collision_exception_with(self)
		_weld_target_exception = new_exception


func _clear_weld_preview():
	if _ghost:
		_ghost.queue_free()
	_ghost = null
	_ghost_for_body = null
	_weld_target = null
	_weld_target_shape_index = -1
	if _weld_target_exception and is_instance_valid(_weld_target_exception):
		remove_collision_exception_with(_weld_target_exception)
		_weld_target_exception.remove_collision_exception_with(self)
	_weld_target_exception = null


## Duplicado visual (mismo mesh, transform local preservado, escala ORIGINAL
## aunque la pieza sostenida esté encogida para no tapar la vista — el ghost
## siempre muestra el tamaño real que va a quedar soldado) de cada
## MeshInstance3D de `body` — sirve tanto para una LoosePiece (1 mesh) como
## para un bote sostenido (varios meshes, árbol plano bajo el BoatManager).
func _build_ghost_for(body: RigidBody3D) -> Node3D:
	var ghost := Node3D.new()
	for child in body.get_children():
		if child is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.mesh = child.mesh
			mi.transform = child.transform
			mi.scale = _held_original_mesh_scale.get(child, child.scale)
			ghost.add_child(mi)
	return ghost


## Mitad del tamaño de una shape a lo largo de una dirección LOCAL a esa
## shape (ya normalizada). Exacto para Box (proyección de una caja) y
## Cylinder (combinación tapa/radio); son las únicas formas del prototipo.
func _shape_half_extent_along(shape: Shape3D, local_dir: Vector3) -> float:
	if shape is BoxShape3D:
		var he: Vector3 = shape.size * 0.5
		return absf(local_dir.x) * he.x + absf(local_dir.y) * he.y + absf(local_dir.z) * he.z
	elif shape is CylinderShape3D:
		var sin_component := sqrt(maxf(0.0, 1.0 - local_dir.y * local_dir.y))
		return shape.height * 0.5 * absf(local_dir.y) + shape.radius * sin_component
	return 0.1  # fallback conservador para shapes no contempladas


## Qué tan lejos hay que empujar la pieza sostenida a lo largo de
## `world_normal` (la normal del impacto) para que quede asentada AL RAS de
## la superficie en vez de enterrada — considera el tamaño real de cada
## CollisionShape3D de la pieza/bote sostenido en la orientación que va a
## quedar (`_manual_rotation`), no un padding fijo. Sin esto, piezas grandes
## en una dirección (ej. el Tubo PVC acostado) quedaban enterradas en el
## objetivo al soldar.
func _held_half_extent_toward(world_normal: Vector3) -> float:
	var root_local_normal: Vector3 = _manual_rotation.inverse() * world_normal
	var max_extent := 0.0
	for child in held_body.get_children():
		if child is CollisionShape3D and child.shape:
			var shape_local_dir: Vector3 = child.transform.basis.inverse() * root_local_normal
			var extent := _shape_half_extent_along(child.shape, shape_local_dir)
			var pos_offset: float = child.transform.origin.dot(root_local_normal)
			max_extent = maxf(max_extent, extent + pos_offset)
	return max_extent


## Snap asistido, no CAD libre (Análisis Técnico §2): la rotación que el
## jugador ya eligió a mano (R/T/Y, ver _handle_manual_rotation) + la pieza
## empujada a lo largo de la normal del impacto por su tamaño real (no un
## padding fijo) para asentarla al ras de la superficie en vez de enterrarla
## o dejarla flotando.
##
## Sin rejilla de posición: se probó redondeando los 3 ejes a `snap_grid_size`
## (0.25m) y, aun dejando el eje de contacto exacto, redondear los otros dos
## ejes tangenciales podía desplazar el punto de contacto hasta 0.125m —
## suficiente para separarlo por completo de piezas angostas (ej. el Tubo
## PVC, radio 0.05) y dejar un hueco visible. Sin una superficie plana grande
## todavía (eso es un modo de construcción futuro sobre el casco), alinear a
## una rejilla no aporta nada hoy; se prioriza que dos piezas SIEMPRE queden
## tocándose al confirmar.
func _compute_snap_transform(hit: Dictionary) -> Transform3D:
	var half_extent := _held_half_extent_toward(hit.normal)
	var pos: Vector3 = hit.position + hit.normal * (half_extent + 0.02)
	return Transform3D(_manual_rotation, pos)


## Confirma la soldadura en la pose del ghost (snap ya calculado en
## _update_weld_preview): reactiva la colisión y la escala (desactivada/
## reducida mientras se sostenía) y mueve la pieza sostenida ahí antes de
## soldar, para que el resultado coincida con lo que el ghost prometía, no
## con donde haya quedado flotando la mano cinemática.
func _confirm_weld():
	_set_held_collision_enabled(true)
	_restore_held_view_scale()
	held_body.global_transform = _weld_snap_transform
	var held := held_body
	var target := _weld_target

	if held is LoosePiece and target is LoosePiece:
		BoatManager.weld_two_loose_pieces(held, target)
	elif held is LoosePiece and target is BoatManager:
		var neighbor_id: int = target.piece_id_for_shape_index(_weld_target_shape_index)
		BoatManager.weld_piece_to_boat(target, held, neighbor_id)
	elif held is BoatManager and target is LoosePiece:
		var neighbor_id: int = held.nearest_piece_id(target.global_position)
		BoatManager.weld_piece_to_boat(held, target, neighbor_id)
	elif held is BoatManager and target is BoatManager:
		BoatManager.weld_boats(held, target)

	_release_held_body()


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
