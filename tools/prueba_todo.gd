extends Node

## LA PARTIDA COMPLETA, DE ARRIBA ABAJO, EN UNA SOLA PRUEBA.
##
## Las otras pruebas miran un piso cada una. Esta recorre el edificio entero como lo
## haria un jugador: entra, lee lo que hay que leer, aprueba cada minijuego, sube por
## el ascensor de verdad -con su cambio de escena- y al final comprueba que la puerta
## de la calle se abre.
##
## Es la que detecta lo que ninguna prueba de piso ve: que una insignia se llame de
## una forma en la tabla y de otra en el plano, que un ascensor apunte a una escena
## que no existe, o que la cadena de requisitos se rompa en el salto entre pisos.
##
##   godot --headless --path . res://tools/prueba_todo.tscn
##
## Sale con codigo 1 si algo falla.

const OFICINA_1 := preload("res://scenes/building/oficina_01.tscn")

var nivel: Node = null
var jugador: Node = null
var _fallos := 0


func _ready() -> void:
	GameState.nuevo_juego()

	nivel = OFICINA_1.instantiate()
	add_child(nivel)
	# La prueba se queda viva fuera de "la escena actual" para sobrevivir a los
	# cambios de piso, que liberan la escena actual.
	get_tree().current_scene = null
	await _esperar(0.5)
	jugador = nivel.get_node_or_null("Entidades/Player")
	if jugador == null:
		_fallar("no hay jugador en la Oficina 1")
		_acabar()
		return

	# ---------------------------------------------------------------- piso 1
	print("— Oficina 1")
	await _leer("pantalla")
	await _leer("recepcion")
	await _jugar_arrastrar("mapa_aliados", true)
	await _jugar_trivia("trivia_cultura", "res://data/trivia_cultura.json", 5)
	_comprobar(GameState.tiene_insignia("identidad"),
		"Insignia de Identidad (organigrama + trivia de cultura)")

	if not await _subir("ascensor"):
		_acabar()
		return

	# ---------------------------------------------------------------- piso 2
	print("— Oficina 2")
	for id in ["terminal_1", "terminal_2", "terminal_3", "terminal_4"]:
		await _leer(id)
	await _jugar_clasificador("clasificador")
	await _jugar_trivia("trivia", "res://data/trivia_catalogo.json", -1)
	_comprobar(GameState.tiene_insignia("catalogo"),
		"Catálogo de Bolsillo (cinta %d, trivia %d)" % [
			int(GameState.puntaje_de("clasificador")),
			int(GameState.puntaje_de("trivia_catalogo"))])

	if not await _subir("ascensor"):
		_acabar()
		return

	# ---------------------------------------------------------------- piso 3
	print("— Oficina 3")
	for id in ["caso_1", "caso_2", "caso_3"]:
		await _leer(id)
	await _jugar_propuesta("propuesta")
	_comprobar(GameState.tiene_insignia("casos"),
		"Portafolio de casos (nota %d)" % int(GameState.puntaje_de("propuesta")))

	if not await _subir("ascensor"):
		_acabar()
		return

	# ---------------------------------------------------------------- piso 4
	print("— Oficina 4")
	await _jugar_comite("pitch")
	_comprobar(GameState.tiene_insignia("acreditacion"),
		"Acreditación de Terreno (nota %d)" % int(GameState.puntaje_de("pitch_comite")))
	_comprobar(GameState.tiene_objeto("llave_auto"),
		"el comité entrega la llave del auto")

	# Y de vuelta al lobby, que es donde esta la puerta de la calle.
	if not await _subir("ascensor"):
		_acabar()
		return

	# ---------------------------------------------------------------- el cierre
	print("— Vuelta al lobby")
	var salida := nivel.get_node_or_null("Entidades/salida/Zona")
	_comprobar(salida != null and str(salida.call("prompt")) == "[E] Salir",
		"la puerta de la calle ya deja salir (prompt: %s)"
			% (str(salida.call("prompt")) if salida != null else "no existe"))
	_comprobar(GameState.cuantas_insignias() == 4,
		"las cuatro insignias (%d)" % GameState.cuantas_insignias())
	print("  puntajes: identidad=%d catalogo=%d casos=%d acreditacion=%d" % [
		int(GameState.puntaje_de("trivia_catalogo")),
		int(GameState.puntaje_de("trivia_catalogo")),
		int(GameState.puntaje_de("propuesta")),
		int(GameState.puntaje_de("pitch_comite"))])

	_acabar()


# ------------------------------------------------------------------- acciones

## Lee lo que hay en un objeto del piso y cierra el panel, como un jugador.
func _leer(id: String) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % id)
	if zona == null:
		_fallar("no existe el objeto " + id)
		return
	zona.call("interactuar", jugador)
	await _esperar(0.12)
	var panel := get_tree().get_first_node_in_group("panel_info")
	if panel != null:
		panel.call("cerrar")
	await _esperar(0.08)


## Pulsa el ascensor y se queda con el piso nuevo. Devuelve si ha cambiado.
func _subir(puerta: String) -> bool:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % puerta)
	if zona == null:
		_fallar("no hay ascensor llamado " + puerta)
		return false
	zona.call("interactuar", jugador)
	await _esperar(0.9)

	var nuevo := get_tree().current_scene
	if nuevo == null or nuevo == nivel:
		_fallar("el ascensor no cambió de piso")
		return false
	# Si el piso lo instanció la prueba, se tira a mano; si era "la escena actual",
	# la libera el propio cambio de escena. Y hay que comprobar is_instance_valid
	# antes de tocarlo: el nodo anterior ya puede estar liberado por ese cambio, y
	# preguntarle el padre a un nodo muerto aborta la prueba entera.
	if is_instance_valid(nivel) and nivel.get_parent() == self:
		nivel.queue_free()
	nivel = nuevo
	await _esperar(0.4)
	jugador = nivel.get_node_or_null("Entidades/Player")
	if jugador == null:
		_fallar("el piso nuevo no tiene jugador")
		return false
	return true


## Elige los tres modulos que el brief pide y envia la propuesta.
func _jugar_propuesta(objeto: String) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % objeto)
	if zona == null:
		_fallar("no existe el atril " + objeto)
		return
	zona.call("interactuar", jugador)
	await _esperar(0.25)
	var p := get_tree().get_first_node_in_group("propuesta")
	if p == null or not bool(p.call("esta_abierto")):
		_fallar("el constructor no se abrió en " + objeto)
		return
	var botones: Array = p.get("_botones")
	var modulos: Array = p.get("_modulos")
	for i in botones.size():
		(botones[i] as Button).button_pressed = bool(
			(modulos[i] as Dictionary).get("correcto", false))
	await _esperar(0.05)
	p.call("_enviar")
	await _esperar(0.15)
	p.call("cerrar")
	await _esperar(0.12)


## Juega el pitch entero eligiendo siempre la respuesta de valor.
func _jugar_comite(objeto: String) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % objeto)
	if zona == null:
		_fallar("no existe la mesa del comité " + objeto)
		return
	zona.call("interactuar", jugador)
	await _esperar(0.25)
	var c := get_tree().get_first_node_in_group("comite")
	if c == null or not bool(c.call("esta_abierto")):
		_fallar("el comité no se abrió en " + objeto)
		return
	# Recorre el arbol por la primera opcion hasta que el nodo no lleve a ninguno.
	var nodos: Dictionary = c.get("_nodos")
	var actual := str(c.get("_actual"))
	var vueltas := 0
	while actual != "" and nodos.has(actual) and vueltas < 10:
		c.call("_elegir", 0)
		await _esperar(0.08)
		actual = str(c.get("_actual"))
		vueltas += 1
	await _esperar(0.2)
	c.call("cerrar")
	await _esperar(0.12)


## Juega la cinta entera acertando todo, que es lo que hace un jugador que ya sabe.
func _jugar_clasificador(objeto: String) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % objeto)
	if zona == null:
		_fallar("no existe el atril " + objeto)
		return
	zona.call("interactuar", jugador)
	await _esperar(0.3)
	var c := get_tree().get_first_node_in_group("clasificador")
	if c == null or not bool(c.call("esta_abierto")):
		_fallar("el clasificador no se abrió en " + objeto)
		return
	for d in c.get("_documentos"):
		c.call("_elegir", str((d as Dictionary)["area"]))
		# 0,45 de veredicto + 0,2 de entrada: por debajo, la respuesta se ignora.
		await _esperar(0.7)
	await _esperar(0.3)
	c.call("cerrar")
	await _esperar(0.15)


func _jugar_trivia(objeto: String, ruta: String, aciertos: int) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % objeto)
	if zona == null:
		_fallar("no existe la mesa de trivia " + objeto)
		return
	zona.call("interactuar", jugador)
	await _esperar(0.2)

	var t := get_tree().get_first_node_in_group("trivia")
	if t == null or not bool(t.call("esta_abierto")):
		_fallar("la trivia no se abrió en " + objeto)
		return

	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	var preguntas: Array = datos["preguntas"]
	var hechas := 0
	for q in preguntas:
		var correcta := int(q["correcta"])
		var bien := hechas < aciertos if aciertos >= 0 else true
		var elegida := correcta if bien else (correcta + 1) % 4
		t.call("_responder", elegida)
		await _esperar(0.03)
		t.call("_siguiente")
		await _esperar(0.03)
		hechas += 1
	t.call("cerrar")
	await _esperar(0.15)


## Resuelve el minijuego de arrastrar, bien o mal, en los DOS modos:
##
##   - ASIGNAR (el Mapa de Aliados): cada pieza trae "destino", asi que bien es
##     soltarla en su hueco y mal es soltarla en el siguiente.
##   - ELEGIR (el Constructor de Propuestas): las piezas traen "correcta" y los
##     huecos son anonimos, asi que bien es soltar las marcadas y mal las demas.
##
## La primera version solo entendia el segundo, y fallaba sin decir nada: no habia
## piezas que soltar, la partida no terminaba y el piso 1 se quedaba sin insignia.
func _jugar_arrastrar(objeto: String, correctas: bool) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % objeto)
	if zona == null:
		_fallar("no existe la mesa de arrastrar " + objeto)
		return
	zona.call("interactuar", jugador)
	await _esperar(0.2)

	var m := get_tree().get_first_node_in_group("arrastrar")
	if m == null or not bool(m.call("esta_abierto")):
		_fallar("el minijuego de arrastrar no se abrió en " + objeto)
		return

	var piezas: Dictionary = m.get("_piezas")
	var huecos: Array = m.get("_huecos")
	var huecos_json: Array = (m.get("_datos") as Dictionary).get("huecos", [])

	var ids: Array = piezas.keys()
	ids.sort()

	# Se decide, pieza a pieza, en que hueco va cada una.
	var pares: Array = []
	var modo_asignar := false
	for id in ids:
		if (piezas[id] as Dictionary).has("destino"):
			modo_asignar = true
			break

	if modo_asignar:
		for id in ids:
			var destino := str((piezas[id] as Dictionary).get("destino", ""))
			var numero := -1
			for i in range(huecos_json.size()):
				if str((huecos_json[i] as Dictionary).get("id", "")) == destino:
					numero = i
			if numero < 0:
				continue
			if not correctas:
				numero = (numero + 1) % huecos.size()
			pares.append([numero, id])
	else:
		var libre := 0
		for id in ids:
			var es_buena := bool((piezas[id] as Dictionary).get("correcta", false))
			if es_buena != correctas:
				continue
			pares.append([libre % huecos.size(), id])
			libre += 1

	for par in pares:
		m.call("_al_soltar", huecos[int(par[0])], {"pieza": str(par[1])})
		await _esperar(0.05)
	m.call("cerrar")
	await _esperar(0.15)


# --------------------------------------------------------------------- utiles

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
	# Una partida completa deja CUATRO insignias. Si el recorrido se corta a mitad
	# -un error de script aborta la corrutina-, sin esta comprobacion el resumen
	# diria "sin fallos" habiendo hecho dos pisos de cuatro: la peor forma de mentir
	# en una prueba.
	if GameState.cuantas_insignias() < 4:
		_fallos += 1
		print("  FALLO la partida no llegó al final: %d de 4 insignias"
			% GameState.cuantas_insignias())
	print("---")
	if _fallos == 0:
		print("PARTIDA COMPLETA SIN FALLOS")
	else:
		print("%d FALLO(S)" % _fallos)
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("progreso.json"):
		dir.remove("progreso.json")
	get_tree().quit(1 if _fallos > 0 else 0)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
