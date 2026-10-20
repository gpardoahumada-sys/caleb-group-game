extends Node

## HERRAMIENTA DE CAPTURAS.
##
## Arranca el piso de verdad, lo juega un poco por codigo y guarda capturas en
## user://capturas/. Sirve para dos cosas: ver el piso sin jugarlo a mano, y poder
## comprobar que lo que se ha montado es lo que se cree (que es distinto).
##
##   godot --path . res://tools/captura.tscn
##
## Deja el progreso como estaba: al terminar borra el fichero que haya escrito, para
## que la primera partida de verdad empiece limpia.

const OFICINA := preload("res://scenes/building/oficina_01.tscn")
const TRIVIA := "res://data/trivia_catalogo.json"
const CARPETA := "user://capturas"

var nivel: Node = null
var jugador: Node = null
var n := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	GameState.nuevo_juego()

	# El cambio de piso libera "la escena actual". Si esta herramienta fuera la
	# escena actual, el ascensor se la llevaria por delante a mitad de las capturas
	# (paso de verdad la primera vez). Soltando la referencia, la herramienta se
	# queda viva en la raiz y puede seguir sacando fotos al piso nuevo.
	get_tree().current_scene = null

	nivel = OFICINA.instantiate()
	add_child(nivel)
	await _esperar(0.5)
	jugador = nivel.get_node_or_null("Entidades/Player")
	if jugador == null:
		push_error("No hay jugador montado: revisa nivel.gd")
		get_tree().quit(1)
		return

	# 2. El lobby tal cual se abre.
	await _captura("01_lobby")

	# 2a. El Mapa de Aliados: el organigrama del piso 1.
	await _ir_a("mapa_aliados")
	await _captura("01b_mapa_aliados")
	var arr := get_tree().get_first_node_in_group("arrastrar")
	if arr != null:
		arr.call("cerrar")
	await _esperar(0.2)

	# 2b. La Trivia de Cultura.
	await _ir_a("trivia_cultura")
	await _captura("01c_trivia_cultura")
	var trv := get_tree().get_first_node_in_group("trivia")
	if trv != null:
		trv.call("cerrar")
	await _esperar(0.2)

	# 2b. La recepcionista: alguien con quien hablar.
	await _ir_a("recepcionista")
	await _captura("02b_recepcionista")

	# 2. El ascensor SIN la insignia: tiene que decir que falta y por que.
	await _ir_a("ascensor")
	await _captura("02_ascensor_bloqueado")

	# 3. El mostrador de recepcion.
	await _ir_a("recepcion")
	await _captura("03_recepcion")

	# 4. La pantalla del auditorio.
	await _ir_a("pantalla")
	await _captura("04_pantalla")

	# 5. Con los dos requisitos leidos cae la insignia. Y el ascensor ya no solo dice
	#    que se abre: ABRE. Se pulsa de verdad, como lo haria un jugador, y se
	#    comprueba que el juego cambia de piso.
	print("Insignia de identidad: ", GameState.tiene_insignia("identidad"))
	# La insignia del piso 1 ya NO se gana solo leyendo: hacen falta el organigrama y
	# la trivia. Para las capturas del piso 2 se dan por aprobadas, que es lo que el
	# jugador habría hecho a estas alturas.
	GameState.apuntar_puntaje("mapa_aliados", 100.0)
	GameState.apuntar_puntaje("trivia_cultura", 100.0)
	var ascensor: Node2D = nivel.get_node("Entidades/ascensor")
	jugador.global_position = ascensor.global_position + Vector2(0, 96)
	await _esperar(0.3)
	ascensor.get_node("Zona").call("interactuar", jugador)
	await _esperar(0.9)

	nivel.queue_free()
	var oficina2 := get_tree().current_scene
	if oficina2 == null:
		push_error("el ascensor no ha cambiado de piso")
		get_tree().quit(1)
		return
	nivel = oficina2
	jugador = nivel.get_node_or_null("Entidades/Player")
	await _captura("05_oficina_2_al_entrar")

	# 5b. El Clasificador de Dolores, que es el otro reto del piso.
	var clasif := get_tree().get_first_node_in_group("clasificador")
	if clasif != null:
		nivel.get_node("Entidades/clasificador/Zona").call("interactuar", jugador)
		await _esperar(0.5)
		await _captura("05b_clasificador")
		# Y con el tiempo casi agotado, para dejar constancia del aviso rojo.
		clasif.set("_restante", 2.0)
		await _esperar(0.35)
		await _captura("05c_clasificador_urgencia")
		clasif.call("cerrar")
		await _esperar(0.2)

	# 6-7. La trivia del piso 2.
	var trivia := get_tree().get_first_node_in_group("trivia")
	nivel.get_node("Entidades/trivia/Zona").call("interactuar", jugador)
	await _esperar(0.45)
	await _captura("06_trivia")

	var f := FileAccess.open(TRIVIA, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	trivia.call("_responder", int(datos["preguntas"][0]["correcta"]))
	await _esperar(0.45)
	await _captura("07_trivia_acierto")

	print("Capturas en ", ProjectSettings.globalize_path(CARPETA))
	_limpiar_progreso()
	get_tree().quit()


## Lleva al jugador junto a un objeto y lo consulta, como si hubiera caminado hasta
## alli y hubiera pulsado E.
func _ir_a(id: String) -> void:
	var zona := nivel.get_node_or_null("Entidades/%s/Zona" % id)
	if zona == null:
		push_error("No existe el objeto " + id)
		return
	var objeto := zona.get_parent() as Node2D
	# Un paso por delante y por debajo: a la altura a la que se mira el mueble.
	jugador.global_position = objeto.global_position + Vector2(0, 96)
	await _esperar(0.35)
	zona.call("interactuar", jugador)
	await _esperar(0.35)


func _captura(nombre: String) -> void:
	await _esperar(0.25)
	var img := get_viewport().get_texture().get_image()
	var ruta := "%s/%s.png" % [CARPETA, nombre]
	img.save_png(ruta)
	print("  captura ", nombre, " -> ", ProjectSettings.globalize_path(ruta))
	n += 1


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


## Tira el progreso que haya escrito esta herramienta: la partida del jugador no
## puede empezar con las cosas ya leidas por una prueba.
func _limpiar_progreso() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("progreso.json"):
		dir.remove("progreso.json")
