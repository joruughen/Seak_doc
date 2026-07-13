extends RigidBody3D
class_name BoatManager

## Fase 2 Grupo 2 (génesis) + Grupo 3 (extender): soldar piezas y botes entre
## sí, en tierra (sin agua todavía — la boyancia por pieza llega en Fase 3).
##
## La verdad estructural es el ConnectionGraph, no el scene tree: mesh y
## CollisionShape3D de cada pieza quedan como hijos DIRECTOS del BoatManager,
## sin ningún Node3D intermedio por pieza. Esto no es solo prolijidad: en
## Godot, CollisionShape3D únicamente registra su shape si su padre INMEDIATO
## es un CollisionObject3D — un Node3D "AttachedPiece" de por medio lo deja
## sin colisión real y el bote cae atravesando todo (ver [[ADR-005]]).

var connection_graph: Dictionary = {}       # piece_id (int) -> Array[int] vecinos soldados
var _piece_local_pos: Dictionary = {}       # piece_id -> Vector3 (posición local bajo este BoatManager, para COM)
var _piece_data: Dictionary = {}            # piece_id -> PieceData
var _piece_nodes: Dictionary = {}           # piece_id -> Array[Node] (mesh + CollisionShape3D de esa pieza)
var _shape_to_piece_id: Dictionary = {}     # CollisionShape3D.get_instance_id() -> piece_id
var _next_piece_id := 0


## Génesis: pega dos LoosePiece sueltas (ninguna pertenece todavía a un bote)
## y devuelve el BoatManager recién creado.
static func weld_two_loose_pieces(a: LoosePiece, b: LoosePiece) -> BoatManager:
	var boat := BoatManager.new()
	boat.continuous_cd = true  # mismo refuerzo anti-tunneling que LoosePiece (ADR-004 Fix 3)
	# Mismas capas que LoosePiece (layer=2 "piezas", mask=3 "entorno+piezas") —
	# necesario para que sostener un bote y suprimir su colisión contra otras
	# piezas (Player._grab) funcione igual que con una LoosePiece suelta.
	boat.collision_layer = 2
	boat.collision_mask = 3
	var parent := a.get_parent()

	# Velocidad promedio ponderada por masa: sin esto el bote "tironea" al
	# nacer, arrancando con la velocidad de una sola de las dos piezas.
	var total_mass_ab := a.mass + b.mass
	var avg_velocity := (a.linear_velocity * a.mass + b.linear_velocity * b.mass) / total_mass_ab

	# Añadir al árbol PRIMERO: fijar global_position en un Node3D todavía sin
	# padre revienta ("!is_inside_tree()") porque necesita el transform del
	# padre para calcularlo.
	parent.add_child(boat)
	boat.global_position = (a.global_position + b.global_position) * 0.5
	boat.linear_velocity = avg_velocity

	var id_a := boat._migrate_piece(a)
	var id_b := boat._migrate_piece(b)
	boat._connect(id_a, id_b)
	boat._recalculate_mass_and_com()
	return boat


## Grupo 3: pega una LoosePiece suelta a un bote ya existente ("solo pasos
## 2-4": no hay génesis de BoatManager nuevo). `neighbor_piece_id` es la
## pieza del bote a la que se conecta en el grafo (-1 si no se pudo
## determinar, ej. bote recién creado sin piezas — no debería pasar en uso
## normal).
static func weld_piece_to_boat(boat: BoatManager, piece: LoosePiece, neighbor_piece_id: int) -> void:
	var total_mass := boat.mass + piece.mass
	var avg_velocity := (boat.linear_velocity * boat.mass + piece.linear_velocity * piece.mass) / total_mass
	boat.linear_velocity = avg_velocity

	var new_id := boat._migrate_piece(piece)
	if neighbor_piece_id >= 0 and boat.connection_graph.has(neighbor_piece_id):
		boat._connect(new_id, neighbor_piece_id)
	boat._recalculate_mass_and_com()


## Grupo 3: fusiona dos botes existentes. "Migrar al mayor" = el bote con más
## piezas absorbe al otro (se libera); sus grafos se fusionan con los ids
## reasignados, y se agrega un puente geométrico (pieza más cercana del chico
## ↔ pieza más cercana del grande) ya que todavía no hay snap real (Grupo 4)
## que indique el punto exacto de contacto. Devuelve el bote sobreviviente.
static func weld_boats(boat_a: BoatManager, boat_b: BoatManager) -> BoatManager:
	var bigger := boat_a if boat_a._piece_data.size() >= boat_b._piece_data.size() else boat_b
	var smaller := boat_b if bigger == boat_a else boat_a

	var total_mass := bigger.mass + smaller.mass
	var avg_velocity := (bigger.linear_velocity * bigger.mass + smaller.linear_velocity * smaller.mass) / total_mass
	bigger.linear_velocity = avg_velocity

	var smaller_ids: Array = smaller._piece_data.keys()
	var bridge_small_id: int = smaller_ids[0]
	var bridge_small_global: Vector3 = smaller.global_transform * smaller._piece_local_pos[bridge_small_id]
	var bridge_big_id := bigger.nearest_piece_id(bridge_small_global)

	var old_to_new := {}
	for old_id in smaller_ids:
		var nodes: Array = smaller._piece_nodes[old_id]
		var pd: PieceData = smaller._piece_data[old_id]
		old_to_new[old_id] = bigger._adopt_piece(nodes, pd)

	# Aristas internas del bote chico, reconstruidas con los ids nuevos.
	for old_id in smaller_ids:
		for old_neighbor in smaller.connection_graph[old_id]:
			var na: int = old_to_new[old_id]
			var nb: int = old_to_new[old_neighbor]
			if not bigger.connection_graph[na].has(nb):
				bigger._connect(na, nb)

	if bridge_big_id >= 0:
		bigger._connect(old_to_new[bridge_small_id], bridge_big_id)

	bigger._recalculate_mass_and_com()
	smaller.queue_free()
	return bigger


## Migra mesh+shape de una LoosePiece como hijos DIRECTOS del BoatManager
## (transform relativo preservado), libera el RigidBody3D suelto, y registra
## la pieza en el grafo. Devuelve el piece_id asignado.
func _migrate_piece(piece: LoosePiece) -> int:
	var id := _adopt_piece(piece.get_children(), piece.piece_data)
	piece.queue_free()
	return id


## Reparenta un set de nodos (mesh + CollisionShape3D de una sola pieza,
## vengan de una LoosePiece o de otro BoatManager al fusionar) como hijos
## DIRECTOS de este BoatManager, preservando su transform global. Devuelve el
## piece_id asignado.
func _adopt_piece(nodes: Array, piece_data: PieceData) -> int:
	var id := _next_piece_id
	_next_piece_id += 1

	var shape_local_pos := Vector3.ZERO
	for node in nodes:
		var node_global: Transform3D
		if node is Node3D:
			node_global = node.global_transform
		var old_parent: Node = node.get_parent()
		if old_parent:
			old_parent.remove_child(node)
		add_child(node)
		if node is Node3D:
			# Restaura el transform global tras el reparent: preserva la
			# posición/rotación real de la pieza sin recalcular nada a mano.
			node.global_transform = node_global
		if node is CollisionShape3D:
			shape_local_pos = node.position
			_shape_to_piece_id[node.get_instance_id()] = id

	_piece_local_pos[id] = shape_local_pos
	_piece_data[id] = piece_data
	_piece_nodes[id] = nodes
	connection_graph[id] = []
	return id


func _connect(id_a: int, id_b: int):
	connection_graph[id_a].append(id_b)
	connection_graph[id_b].append(id_a)


## Traduce el índice de shape que devuelve un raycast (`intersect_ray().shape`)
## al piece_id dueño de esa CollisionShape3D. -1 si no se encuentra (no
## debería pasar para un shape que pertenece a este cuerpo).
func piece_id_for_shape_index(shape_index: int) -> int:
	var owner_id := shape_find_owner(shape_index)
	var shape_node := shape_owner_get_owner(owner_id)
	if shape_node and _shape_to_piece_id.has(shape_node.get_instance_id()):
		return _shape_to_piece_id[shape_node.get_instance_id()]
	return -1


## Pieza de este bote más cercana (en espacio global) a `global_pos`. Usado
## como aproximación de "a qué pieza se conecta" cuando no hay snap real
## (Grupo 4) que indique el punto exacto de contacto. -1 si el bote no tiene
## piezas todavía.
func nearest_piece_id(global_pos: Vector3) -> int:
	var best_id := -1
	var best_dist := INF
	for id in _piece_local_pos:
		var piece_global: Vector3 = global_transform * _piece_local_pos[id]
		var d := piece_global.distance_to(global_pos)
		if d < best_dist:
			best_dist = d
			best_id = id
	return best_id


## Recalcula mass y center_of_mass (custom) a partir de las piezas soldadas.
## NUNCA inercia custom aquí (godot#78750: combinar masa/COM custom con
## inercia custom da resultados físicos incorrectos) — inertia_mode se deja
## en su default (AUTO), calculado por el motor a partir de las shapes.
func _recalculate_mass_and_com():
	var total_mass := 0.0
	var weighted_pos := Vector3.ZERO
	for id in _piece_data:
		var pd: PieceData = _piece_data[id]
		var local_pos: Vector3 = _piece_local_pos[id]
		total_mass += pd.mass
		weighted_pos += local_pos * pd.mass

	mass = total_mass
	if total_mass > 0.0:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = weighted_pos / total_mass
