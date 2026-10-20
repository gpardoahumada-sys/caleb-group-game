extends Node

## PRUEBA DEL PISO 3 Y DEL CONSTRUCTOR DE PROPUESTAS.
##
## Lo que comprueba, y por que:
##
##   1. Que los tres casos del mural se pueden leer y quedan apuntados.
##   2. Que SIN la propuesta no hay insignia: el mural solo no basta.
##   3. Que el constructor se abre con SIETE modulos, no con tres: si vuelve a haber
##      solo tres, la eleccion es un tramite y no se puede sobredimensionar.
##   4. Que elegir de MENOS no aprueba (falta de alcance).
##   5. Que elegir de MAS tampoco aprueba, aunque los tres buenos esten dentro
##      (sobredimensionar). Es el caso que un motor de arrastrar no puede ni plantear.
##   6. Que con los tres exactos cae el Portafolio de Casos de Exito.
##   7. Que el ascensor queda habilitado.
##
##   godot --headless --path . res://tools/prueba_03.tscn

const OFICINA := preload("res://scenes/building/oficina_03.tscn")
const DATOS := "res://data/propuesta.json"

var _fallos := 0
var nivel: Node
var jugador: Node


func _ready() -> void:
	GameState.nuevo_juego()

	nivel = OFICINA.instantiate()
	add_child(nivel)
	await _esperar(0.4)

	jugador = nivel.get_node_or_null("Entidades/Player")
	if jugador == null:
		_fallar("no hay jugador montado")
		_acabar()
		return

	var panel: Node = get_tree().get_first_node_in_group("panel_info")
	var minijuego: Node = get_tree().get_first_node_in_group("propuesta")
	if panel == null or minijuego == null:
		_fallar("faltan el panel o el constructor en la escena")
		_acabar()
		return

	# --- 1. los tres casos del mural ---------------------------------------
	for id in ["caso_1", "caso_2", "caso_3"]:
		var zona := nivel.get_node_or_null("Entidades/%s/Zona" % id)
		if zona == null:
			_fallar("no existe el caso " + id)
			continue
		zona.call("interactuar", jugador)
		await _esperar(0.06)
		panel.call("cerrar")
		await _esperar(0.06)
	_comprobar(GameState.faltan_para("casos").is_empty(),
		"los tres casos del mural quedan leidos")

	# --- 2. sin la propuesta no hay insignia -------------------------------
	_comprobar(not GameState.tiene_insignia("casos"),
		"con el mural leido pero sin propuesta NO hay insignia")
	_comprobar(GameState.objetivo_texto("casos").contains("propuesta"),
		"el objetivo pide la propuesta («%s»)" % GameState.objetivo_texto("casos"))

	# --- 3. el constructor trae siete modulos ------------------------------
	var correctos := _correctos()
	_comprobar(correctos.size() == 3, "el brief tiene 3 módulos buenos (%d)" % correctos.size())

	nivel.get_node("Entidades/propuesta/Zona").call("interactuar", jugador)
	await _esperar(0.25)
	_comprobar(bool(minijuego.call("esta_abierto")), "la E en el atril abre el constructor")
	var total := int((minijuego.get("_modulos") as Array).size())
	_comprobar(total == 7, "hay 7 módulos para elegir (%d)" % total)
	_comprobar((minijuego.get("_botones") as Array).size() == 7,
		"se dibujan 7 tarjetas")

	# --- 4. quedarse corto ------------------------------------------------
	var corto: Array = correctos.slice(0, 2)
	await _marcar_y_enviar(minijuego, corto)
	_comprobar(absf(float(minijuego.get("ultima_nota")) - 66.67) < 1.5,
		"con 2 de 3 la nota ronda 67 (%d)" % int(minijuego.get("ultima_nota")))
	_comprobar(String(minijuego.get_node(
		"Veladura/Marco/Margen/Columnas/Veredicto").text).contains("Falta alcance"),
		"el veredicto avisa de la falta de alcance")
	_comprobar(not GameState.tiene_insignia("casos"), "quedarse corto no da la insignia")
	minijuego.call("cerrar")
	await _esperar(0.12)

	# --- 5. pasarse --------------------------------------------------------
	nivel.get_node("Entidades/propuesta/Zona").call("interactuar", jugador)
	await _esperar(0.25)
	var todo: Array = []
	for i in total:
		todo.append(i)
	await _marcar_y_enviar(minijuego, todo)
	# La nota guardada es la MEJOR (66 del intento anterior), asi que aqui se mira la
	# de esta partida: es lo que el jugador acaba de hacer.
	_comprobar(is_zero_approx(float(minijuego.get("ultima_nota"))),
		"eligiendo los 7 la nota de la partida es 0 (%d)" % int(minijuego.get("ultima_nota")))
	_comprobar(String(minijuego.get_node(
		"Veladura/Marco/Margen/Columnas/Veredicto").text).contains("Sobredimensionada"),
		"el veredicto avisa del sobredimensionamiento")
	_comprobar(not GameState.tiene_insignia("casos"), "sobredimensionar no da la insignia")
	minijuego.call("cerrar")
	await _esperar(0.12)

	# --- 6. los tres exactos ----------------------------------------------
	nivel.get_node("Entidades/propuesta/Zona").call("interactuar", jugador)
	await _esperar(0.25)
	await _marcar_y_enviar(minijuego, correctos)
	_comprobar(is_equal_approx(GameState.puntaje_de("propuesta"), 100.0),
		"con los 3 exactos la nota es 100 (%d)" % int(GameState.puntaje_de("propuesta")))
	_comprobar(GameState.tiene_insignia("casos"),
		"aprobando cae el Portafolio de Casos de Éxito")

	# --- 7. el ascensor ----------------------------------------------------
	var ascensor: Node2D = nivel.get_node("Entidades/ascensor")
	var zona_asc: Node = ascensor.get_node("Zona")
	_comprobar(str(zona_asc.call("prompt")) == "[E] Subir",
		"el ascensor pasa a dejar subir (prompt: %s)" % str(zona_asc.call("prompt")))

	minijuego.call("cerrar")
	await _esperar(0.15)
	_comprobar(not bool(minijuego.call("esta_abierto")), "el constructor se cierra")

	_acabar()


## Marca los modulos `elegir` y pulsa enviar.
func _marcar_y_enviar(p: Node, elegir: Array) -> void:
	var botones: Array = p.get("_botones")
	for i in botones.size():
		(botones[i] as Button).button_pressed = elegir.has(i)
	await _esperar(0.05)
	p.call("_enviar")
	await _esperar(0.12)


## Indices de los modulos que el brief si pide.
func _correctos() -> Array:
	var f := FileAccess.open(DATOS, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	var salida: Array = []
	var modulos: Array = datos["modulos"]
	for i in modulos.size():
		if bool((modulos[i] as Dictionary).get("correcto", false)):
			salida.append(i)
	return salida


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
