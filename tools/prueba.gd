extends Node

## PRUEBA DE ENTRADA Y DE PUERTA.
##
## No comprueba "que el codigo no peta": comprueba lo que de verdad se rompe en
## silencio al escribir un proyecto a mano, que son dos cosas:
##
##   1. que el mapa de teclas de project.godot funciona -que la D mueve y la E
##      interactua-, con eventos de teclado DE VERDAD y no con Input.action_press,
##      que se saltaria justo la parte que puede estar mal;
##   2. que leer lo que pide la insignia la concede, y que entonces la puerta del
##      ascensor cambia de texto.
##
##   godot --headless --path . res://tools/prueba.tscn
##
## Sale con codigo 1 si algo falla, para poder meterlo en un script.

const OFICINA := preload("res://scenes/building/oficina_01.tscn")

var _fallos := 0


func _ready() -> void:
	GameState.nuevo_juego()

	var nivel: Node = OFICINA.instantiate()
	add_child(nivel)
	# Si la prueba fuera la "escena actual", el cambio de piso del ascensor se la
	# llevaria por delante a mitad de test. Se suelta la referencia y la prueba sigue
	# viva en la raiz, que es lo que permite comprobar la navegacion de verdad.
	get_tree().current_scene = null
	await _esperar(0.4)

	var jugador: Node = nivel.get_node_or_null("Entidades/Player")
	if jugador == null:
		_fallar("no hay jugador montado")
		_acabar()
		return

	# --- 1. la D mueve hacia la derecha -------------------------------------
	var x0: float = jugador.global_position.x
	await _tecla(KEY_D, true)
	await _esperar(0.45)
	await _tecla(KEY_D, false)
	await _esperar(0.15)
	var movido: float = jugador.global_position.x - x0
	_comprobar(movido > 20.0, "la D mueve al personaje (se movio %.1f px)" % movido)

	# --- 2. no se atraviesan las paredes ------------------------------------
	var arriba0: float = jugador.global_position.y
	await _tecla(KEY_W, true)
	await _esperar(1.6)
	await _tecla(KEY_W, false)
	await _esperar(0.15)
	_comprobar(jugador.global_position.y > 64.0,
		"la pared de arriba frena al personaje (y = %.0f, la pared acaba en 64)"
			% jugador.global_position.y)

	# --- 3. la E abre el panel del mostrador --------------------------------
	var mostrador: Node2D = nivel.get_node("Entidades/recepcion")
	jugador.global_position = mostrador.global_position + Vector2(0, 96)
	await _esperar(0.4)
	await _tecla(KEY_E, true)
	await _tecla(KEY_E, false)
	await _esperar(0.2)

	var panel: Node = get_tree().get_first_node_in_group("panel_info")
	_comprobar(panel != null and bool(panel.call("esta_abierto")),
		"la E abre el panel de lo que tienes delante")

	# --- 4. cerrar el panel devuelve el control ----------------------------
	await _esperar(0.25)
	await _tecla(KEY_E, true)
	await _tecla(KEY_E, false)
	await _esperar(0.2)
	_comprobar(panel != null and not bool(panel.call("esta_abierto")),
		"la E vuelve a cerrar el panel")
	_comprobar(not bool(jugador.get("bloqueado")), "al cerrar se recupera el movimiento")

	# --- 5. la insignia sale de leer lo que hay que leer --------------------
	# Se limpia antes: abrir el mostrador en el paso 3 ya lo apunto como leido, y
	# sin esto la prueba daria por bueno un estado que arrastra.
	GameState.nuevo_juego()
	_comprobar(GameState.faltan_para("identidad").size() == 2,
		"al empezar faltan los dos requisitos de lectura")
	_comprobar(GameState.faltan_pruebas("identidad").size() == 2,
		"al empezar faltan las dos pruebas: Mapa de Aliados y Trivia de Cultura")
	GameState.marcar_leido("pantalla")
	GameState.marcar_leido("recepcion")
	_comprobar(not GameState.tiene_insignia("identidad"),
		"con los dos leídos pero SIN las pruebas NO hay insignia")
	GameState.apuntar_puntaje("mapa_aliados", 100.0)
	_comprobar(not GameState.tiene_insignia("identidad"),
		"con una prueba aprobada y otra no, todavía NO")
	GameState.apuntar_puntaje("trivia_cultura", 100.0)
	_comprobar(GameState.tiene_insignia("identidad"),
		"con el organigrama y la trivia aprobados SÍ hay insignia")

	# --- 6. y entonces la puerta deja de estar cerrada ----------------------
	var ascensor: Node2D = nivel.get_node("Entidades/ascensor")
	var zona: Node = ascensor.get_node("Zona")
	_comprobar(str(zona.call("prompt")) == "[E] Subir",
		"el ascensor pasa a dejar subir (prompt: %s)" % str(zona.call("prompt")))

	# --- 7. el ascensor se enciende al ganar la insignia --------------------
	var dibujo: Sprite2D = ascensor.get_node("Dibujo")
	_comprobar(dibujo.modulate.is_equal_approx(Color.WHITE),
		"el ascensor se enciende (modulate %s)" % str(dibujo.modulate))

	# --- 8. la linea de objetivo del HUD sigue el progreso ------------------
	GameState.nuevo_juego()
	await _esperar(0.1)
	var etiqueta: Label = nivel.get_node("HUD/Cinta/Objetivo")
	_comprobar(etiqueta.text.contains("pantalla") and etiqueta.text.contains("mostrador"),
		"el objetivo nombra lo que falta al empezar («%s»)" % etiqueta.text)
	GameState.marcar_leido("pantalla")
	await _esperar(0.1)
	_comprobar(not etiqueta.text.contains("la pantalla"),
		"al leer la pantalla el objetivo deja de pedirla («%s»)" % etiqueta.text)

	# --- 9. el objeto a tiro se aclara y el resto no ------------------------
	jugador.global_position = mostrador.global_position + Vector2(0, 96)
	await _esperar(0.35)
	var dib_mostrador: Sprite2D = mostrador.get_node("Dibujo")
	var dib_planta: Sprite2D = nivel.get_node("Entidades/planta_1/Dibujo")
	_comprobar(dib_mostrador.modulate.r > 1.0,
		"el mostrador a tiro se aclara (modulate %s)" % str(dib_mostrador.modulate))
	_comprobar(dib_planta.modulate.is_equal_approx(Color.WHITE),
		"la planta lejana no se aclara")

	# --- 10. el ascensor cambia de piso de verdad --------------------------
	GameState.nuevo_juego()
	_dar_identidad()
	_comprobar(GameState.tiene_insignia("identidad"),
		"insignia lista para probar la navegacion")
	jugador.global_position = ascensor.global_position + Vector2(0, 96)
	await _esperar(0.3)
	zona.call("interactuar", jugador)
	await _esperar(0.9)
	var nuevo := get_tree().current_scene
	_comprobar(nuevo != null and nuevo.scene_file_path.ends_with("oficina_02.tscn"),
		"el ascensor carga la Oficina 2 (%s)"
			% (nuevo.scene_file_path if nuevo != null else "no ha cambiado nada"))
	if nuevo != null:
		nuevo.queue_free()

	# --- 11. hay gente, se mueve y se puede hablar con ella -----------------
	var marta: Node2D = nivel.get_node_or_null("Entidades/recepcionista")
	_comprobar(marta != null, "la recepcionista está montada en el piso")
	if marta != null:
		var zona_marta: Node = marta.get_node_or_null("Zona")
		_comprobar(zona_marta != null and str(zona_marta.call("prompt")) == "[E] Hablar",
			"la recepcionista responde a la E (prompt: %s)"
				% (str(zona_marta.call("prompt")) if zona_marta else "no tiene zona"))
		jugador.global_position = marta.global_position + Vector2(0, 110)
		await _esperar(0.4)
		if zona_marta != null:
			zona_marta.call("interactuar", jugador)
			await _esperar(0.2)
			_comprobar(panel != null and bool(panel.call("esta_abierto")),
				"hablar con ella abre el panel")
			panel.call("cerrar")
			await _esperar(0.15)

	var paseante: Node2D = nivel.get_node_or_null("Entidades/paseante_1")
	if paseante != null:
		var antes := paseante.global_position
		await _esperar(2.2)
		var andado := paseante.global_position.distance_to(antes)
		_comprobar(andado > 20.0, "el compañero que pasea se mueve (%.0f px en 2,2 s)" % andado)
	else:
		_fallar("no hay ningún compañero paseando")

	_acabar()


func _comprobar(condicion: bool, texto: String) -> void:
	if condicion:
		print("  OK    ", texto)
	else:
		_fallos += 1
		print("  FALLO ", texto)


## Deja el piso 1 completo: lo leído y las dos pruebas. Se usa donde lo que
## interesa es tener la insignia, no cómo se consigue.
func _dar_identidad() -> void:
	GameState.marcar_leido("pantalla")
	GameState.marcar_leido("recepcion")
	GameState.apuntar_puntaje("mapa_aliados", 100.0)
	GameState.apuntar_puntaje("trivia_cultura", 100.0)


func _fallar(texto: String) -> void:
	_fallos += 1
	print("  FALLO ", texto)


func _acabar() -> void:
	print("---")
	if _fallos == 0:
		print("TODO OK")
	else:
		print("%d FALLO(S)" % _fallos)
	# El progreso de la prueba no puede quedarse en la partida del jugador.
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("progreso.json"):
		dir.remove("progreso.json")
	get_tree().quit(1 if _fallos > 0 else 0)


## Pulsa o suelta una tecla de verdad, por su codigo fisico: es lo que comprueba
## que el mapa de teclas de project.godot esta bien escrito.
func _tecla(codigo: Key, pulsada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pulsada
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
