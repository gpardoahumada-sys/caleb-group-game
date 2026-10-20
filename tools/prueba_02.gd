extends Node

## PRUEBA DEL PISO 2 Y DE LA TRIVIA.
##
## Lo que comprueba, y por que cada cosa:
##
##   1. Que las cuatro terminales se pueden consultar y quedan apuntadas. Es el
##      requisito de la insignia, asi que si esto falla la puerta no abre nunca.
##   2. Que CON las cuatro leidas pero SIN la trivia la insignia NO cae. Es la mitad
##      de la regla del piso, y es justo la que se rompe si alguien cambia la tabla
##      de PISOS y se deja la trivia fuera.
##   3. Que la mesa abre la trivia de verdad, responde, cuenta bien y termina.
##   4. Que aprobando cae la insignia y el ascensor cambia de estado.
##   5. Que fallando no cae, y que repetir mejora la nota y no la empeora.
##
##   godot --headless --path . res://tools/prueba_02.tscn

const OFICINA := preload("res://scenes/building/oficina_02.tscn")
const TRIVIA := "res://data/trivia_catalogo.json"

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

	var panel: Node = get_tree().get_first_node_in_group("panel_info")
	var trivia: Node = get_tree().get_first_node_in_group("trivia")
	if panel == null or trivia == null:
		_fallar("faltan el panel o la trivia en la escena")
		_acabar()
		return

	# --- 1. las cuatro terminales ------------------------------------------
	for id in ["terminal_1", "terminal_2", "terminal_3", "terminal_4"]:
		var zona := nivel.get_node_or_null("Entidades/%s/Zona" % id)
		if zona == null:
			_fallar("no existe la terminal " + id)
			continue
		zona.call("interactuar", jugador)
		await _esperar(0.06)
		panel.call("cerrar")
		await _esperar(0.06)
	_comprobar(GameState.faltan_para("catalogo").is_empty(),
		"las cuatro terminales quedan consultadas")

	# --- 2. sin las pruebas no hay insignia --------------------------------
	_comprobar(not GameState.tiene_insignia("catalogo"),
		"con las terminales leidas pero sin pruebas NO hay insignia")
	_comprobar(GameState.objetivo_texto("catalogo").contains("trivia"),
		"el objetivo pide la trivia («%s»)" % GameState.objetivo_texto("catalogo"))
	_comprobar(GameState.objetivo_texto("catalogo").contains("Clasificador"),
		"y también el Clasificador («%s»)" % GameState.objetivo_texto("catalogo"))

	# --- 2b. el Clasificador de Dolores ------------------------------------
	var clasif: Node = get_tree().get_first_node_in_group("clasificador")
	if clasif == null:
		_fallar("no hay Clasificador en la escena")
	else:
		nivel.get_node("Entidades/clasificador/Zona").call("interactuar", jugador)
		await _esperar(0.25)
		_comprobar(bool(clasif.call("esta_abierto")),
			"la E en el atril abre el Clasificador")
		_comprobar(int(clasif.get("_documentos").size()) == 8,
			"la cinta trae 8 documentos (%d)" % int(clasif.get("_documentos").size()))

		# Tiempo agotado = documento perdido. Se acorta el reloj en vez de esperar 8 s.
		var segundos_ok := float(clasif.get("_segundos"))
		clasif.set("_segundos", 0.4)
		clasif.call("_siguiente")
		await _esperar(0.95)
		_comprobar(int(clasif.get("_aciertos")) == 0 and int(clasif.get("_i")) == 1,
			"el documento que se pasa de tiempo se pierde (i=%d, aciertos=%d)" % [
				int(clasif.get("_i")), int(clasif.get("_aciertos"))])
		clasif.set("_segundos", segundos_ok)
		clasif.call("cerrar")
		await _esperar(0.1)
		nivel.get_node("Entidades/clasificador/Zona").call("interactuar", jugador)
		await _esperar(0.3)

		# Media partida mal: la cinta no puede dar la insignia sola.
		await _jugar_clasificador(clasif, 4)
		_comprobar(is_equal_approx(GameState.puntaje_de("clasificador"), 50.0),
			"acertando 4 de 8 la nota es 50 (%d)" % int(GameState.puntaje_de("clasificador")))
		_comprobar(not GameState.tiene_insignia("catalogo"),
			"con el Clasificador a medias tampoco cae la insignia")
		clasif.call("cerrar")
		await _esperar(0.1)

		# Se repite entero y bien.
		nivel.get_node("Entidades/clasificador/Zona").call("interactuar", jugador)
		await _esperar(0.25)
		await _jugar_clasificador(clasif, 8)
		_comprobar(is_equal_approx(GameState.puntaje_de("clasificador"), 100.0),
			"acertando 8 de 8 la nota es 100 (%d)" % int(GameState.puntaje_de("clasificador")))
		_comprobar(not GameState.tiene_insignia("catalogo"),
			"con la cinta bien pero sin la trivia sigue sin insignia")
		clasif.call("cerrar")
		await _esperar(0.1)

	# --- 3. la mesa abre la trivia ------------------------------------------
	nivel.get_node("Entidades/trivia/Zona").call("interactuar", jugador)
	await _esperar(0.15)
	_comprobar(bool(trivia.call("esta_abierto")), "la E en la mesa abre la trivia")

	# --- 5a. primero se falla a proposito: solo 2 bien --------------------
	# El numero de preguntas se lee del JSON: anadir una pregunta no puede dejar la
	# prueba en rojo ni volverla tonta.
	var total_p := _total_preguntas(TRIVIA)
	await _jugar(trivia, 2, true)
	var esperado := 100.0 * 2.0 / float(total_p)
	_comprobar(absf(GameState.puntaje_de("trivia_catalogo") - esperado) < 1.5,
		"acertando 2 de %d la nota ronda %d (%d)" % [total_p, int(round(esperado)),
			int(GameState.puntaje_de("trivia_catalogo"))])
	_comprobar(not GameState.tiene_insignia("catalogo"),
		"por debajo del 80% NO cae la insignia")
	trivia.call("cerrar")
	await _esperar(0.1)

	# --- 3b/4. se repite y se aprueba -------------------------------------
	nivel.get_node("Entidades/trivia/Zona").call("interactuar", jugador)
	await _esperar(0.15)
	await _jugar(trivia, -1, false)
	_comprobar(is_equal_approx(GameState.puntaje_de("trivia_catalogo"), 100.0),
		"acertando las %d la nota es 100 (%d)" % [total_p,
			int(GameState.puntaje_de("trivia_catalogo"))])
	_comprobar(GameState.tiene_insignia("catalogo"),
		"aprobando cae el Catálogo Comercial de Bolsillo")

	# --- 4b. el ascensor cambia de estado ---------------------------------
	var ascensor: Node2D = nivel.get_node("Entidades/ascensor")
	var zona_asc: Node = ascensor.get_node("Zona")
	_comprobar(str(zona_asc.call("prompt")) == "[E] Subir",
		"el ascensor pasa a dejar subir (prompt: %s)" % str(zona_asc.call("prompt")))
	_comprobar((ascensor.get_node("Dibujo") as Sprite2D).modulate.is_equal_approx(Color.WHITE),
		"el ascensor se enciende")

	# --- 6. el jugador vuelve a poder moverse ------------------------------
	trivia.call("cerrar")
	await _esperar(0.15)
	_comprobar(not bool(trivia.call("esta_abierto")), "la trivia se cierra")

	_acabar()


## Juega la trivia respondiendo `aciertos` preguntas bien y el resto mal, en el
## orden que salgan. Con `aciertos` negativo las acierta todas.
func _jugar(trivia: Node, aciertos: int, _resto_mal: bool) -> void:
	var f := FileAccess.open(TRIVIA, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	var preguntas: Array = datos["preguntas"]
	var hechos := 0
	for q in preguntas:
		var correcta := int(q["correcta"])
		var bien := hechos < aciertos if aciertos >= 0 else true
		var elegida := correcta if bien else (correcta + 1) % 4
		trivia.call("_responder", elegida)
		await _esperar(0.03)
		trivia.call("_siguiente")
		await _esperar(0.03)
		hechos += 1


func _total_preguntas(ruta: String) -> int:
	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	return int((datos["preguntas"] as Array).size())


## Juega la cinta clasificando bien los primeros `aciertos` documentos y el resto
## mal. Espera lo que dura el veredicto antes de mandar el siguiente, porque el motor
## ignora respuestas mientras esta ensenando si fue bien.
func _jugar_clasificador(c: Node, aciertos: int) -> void:
	var f := FileAccess.open("res://data/clasificador_dolores.json", FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	var docs: Array = datos["documentos"]
	var hechos := 0
	for d in docs:
		var buena := str(d["area"])
		var area := buena if hechos < aciertos else _otra_area(buena)
		c.call("_elegir", area)
		# 0,45 s de veredicto + 0,2 s de entrada del siguiente: por debajo de eso el
		# motor ignora la respuesta y la partida se queda a medias.
		await _esperar(0.7)
		hechos += 1
	await _esperar(0.3)


func _otra_area(buena: String) -> String:
	for a in ["digital", "datos", "cloud", "gestion"]:
		if a != buena:
			return a
	return "digital"


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
