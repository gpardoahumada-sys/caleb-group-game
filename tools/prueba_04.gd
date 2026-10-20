extends Node

## PRUEBA DEL PISO 4 Y DEL PITCH ANTE EL COMITÉ.
##
## Lo que comprueba, y por que:
##
##   1. Que el pitch se abre en el primer nodo del arbol y ofrece tres respuestas.
##   2. Que una respuesta de RELLENO abre una repregunta del mismo director: eso es lo
##      que lo hace arbol y no una lista de preguntas sueltas.
##   3. Que ofrecer un DESCUENTO lleva a la rama de la trampa y deja la nota clavada
##      en 50 aunque el resto se haya defendido bien.
##   4. Que el camino bueno da 100, la insignia y la LLAVE DEL AUTO.
##   5. Que la llave no se duplica al repetir el pitch.
##
##   godot --headless --path . res://tools/prueba_04.tscn

const OFICINA := preload("res://scenes/building/oficina_04.tscn")

var _fallos := 0


func _ready() -> void:
	GameState.nuevo_juego()

	var nivel: Node = OFICINA.instantiate()
	add_child(nivel)
	await _esperar(0.4)

	var jugador: Node = nivel.get_node_or_null("Entidades/Player")
	if jugador == null:
		_fallar("no hay jugador montado")
		_acabar()
		return
	var comite: Node = get_tree().get_first_node_in_group("comite")
	if comite == null:
		_fallar("no hay comité en la escena")
		_acabar()
		return

	var zona: Node = nivel.get_node("Entidades/pitch/Zona")

	# --- 1. se abre en el primer nodo --------------------------------------
	zona.call("interactuar", jugador)
	await _esperar(0.2)
	_comprobar(bool(comite.call("esta_abierto")), "la E en la mesa abre el comité")
	_comprobar(str(comite.get("_actual")) == "r1",
		"empieza por la primera objeción (%s)" % str(comite.get("_actual")))
	_comprobar(_opciones(comite).size() == 3,
		"ofrece 3 respuestas (%d)" % _opciones(comite).size())

	# --- 2. el relleno provoca repregunta ----------------------------------
	comite.call("_elegir", 1)      # «somos los mejores»
	await _esperar(0.1)
	_comprobar(str(comite.get("_actual")) == "r1b",
		"una respuesta de relleno abre repregunta (%s)" % str(comite.get("_actual")))
	_comprobar(_linea(comite).contains("número"),
		"la repregunta pide un número («%s»)" % _linea(comite).left(46))

	# --- 3. el descuento clava la nota en 50 -------------------------------
	comite.call("cerrar")
	await _esperar(0.1)
	zona.call("interactuar", jugador)
	await _esperar(0.2)
	comite.call("_elegir", 0)      # r1 buena (3)
	await _esperar(0.08)
	comite.call("_elegir", 0)      # r2 buena (3)
	await _esperar(0.08)
	comite.call("_elegir", 2)      # r3: descuento -> trampa
	await _esperar(0.08)
	_comprobar(str(comite.get("_actual")) == "trampa",
		"el descuento lleva a la rama de la trampa (%s)" % str(comite.get("_actual")))
	comite.call("_elegir", 0)      # la trampa cierra el pitch
	await _esperar(0.15)
	_comprobar(is_equal_approx(float(comite.get("ultima_nota")), 50.0),
		"con descuento la nota se queda en 50 aunque lo demás esté bien (%d)"
		% int(comite.get("ultima_nota")))
	_comprobar(not GameState.tiene_insignia("acreditacion"),
		"con descuento no hay acreditación")
	_comprobar(not GameState.tiene_objeto("llave_auto"),
		"y tampoco hay llave")

	# --- 4. el camino bueno ------------------------------------------------
	comite.call("cerrar")
	await _esperar(0.1)
	zona.call("interactuar", jugador)
	await _esperar(0.2)
	for i in 4:
		comite.call("_elegir", 0)
		await _esperar(0.08)
	_comprobar(is_equal_approx(float(comite.get("ultima_nota")), 100.0),
		"defendiendo el valor la nota es 100 (%d)" % int(comite.get("ultima_nota")))
	_comprobar(GameState.tiene_insignia("acreditacion"),
		"aprobando cae la Acreditación Comercial de Terreno")
	_comprobar(GameState.tiene_objeto("llave_auto"),
		"el Gerente General entrega la Llave del Auto Corporativo")

	# --- 5. la llave no se duplica ----------------------------------------
	comite.call("cerrar")
	await _esperar(0.1)
	zona.call("interactuar", jugador)
	await _esperar(0.2)
	for i in 4:
		comite.call("_elegir", 0)
		await _esperar(0.08)
	_comprobar((GameState.inventario as Array).count("llave_auto") == 1,
		"repetir el pitch no duplica la llave (%d)" % (GameState.inventario as Array).count("llave_auto"))

	# --- 6. el ascensor de vuelta al lobby --------------------------------
	var ascensor: Node2D = nivel.get_node("Entidades/ascensor")
	_comprobar(str(ascensor.get_node("Zona").call("prompt")) == "[E] Bajar",
		"el ascensor vuelve a bajar al lobby (prompt: %s)"
		% str(ascensor.get_node("Zona").call("prompt")))

	comite.call("cerrar")
	await _esperar(0.1)
	_comprobar(not bool(comite.call("esta_abierto")), "el comité se cierra")

	_acabar()


func _opciones(comite: Node) -> Array:
	var nodos: Dictionary = comite.get("_nodos")
	var actual := str(comite.get("_actual"))
	if not nodos.has(actual):
		return []
	return (nodos[actual] as Dictionary).get("opciones", [])


func _linea(comite: Node) -> String:
	var nodos: Dictionary = comite.get("_nodos")
	var actual := str(comite.get("_actual"))
	if not nodos.has(actual):
		return ""
	return str((nodos[actual] as Dictionary).get("texto", ""))


func _comprobar(condicion: bool, texto: String) -> void:
	if condicion:
		print("  OK    ", texto)
	else:
		_fallos += 1
		print("  FALLO ", texto)


func _fallar(texto: String) -> void:
	_fallos += 1
	print("  FALLO ", texto)


func _acabar() -> void:
	print("---")
	if _fallos == 0:
		print("TODO OK")
	else:
		print("%d FALLO(S)" % _fallos)
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("progreso.json"):
		dir.remove("progreso.json")
	get_tree().quit(1 if _fallos > 0 else 0)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
