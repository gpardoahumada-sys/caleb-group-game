extends Node

## CAPTURAS DE LAS OFICINAS 3 Y 4.
##
## Herramienta aparte de tools/captura.gd a proposito: aquella entra por el ascensor
## y comprueba la navegacion; esta instancia los pisos directamente, que es mas
## corto. Para enseñar como quedan no hace falta recorrer el edificio.
##
##   godot --path . res://tools/captura_pisos.tscn

const O3 := preload("res://scenes/building/oficina_03.tscn")
const O4 := preload("res://scenes/building/oficina_04.tscn")
const CARPETA := "user://capturas"

var nivel: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	GameState.nuevo_juego()
	GameState.dar_insignia("identidad")
	GameState.dar_insignia("catalogo")

	# ---------------------------------------------------------- Oficina 3
	nivel = O3.instantiate()
	add_child(nivel)
	await _esperar(0.6)
	await _captura("08_oficina_3")

	var jugador: Node = nivel.get_node("Entidades/Player")
	nivel.get_node("Entidades/propuesta/Zona").call("interactuar", jugador)
	await _esperar(0.5)
	await _captura("09_propuesta")

	# Se resuelve bien para ver el resultado marcado en verde y en rojo.
	var m := get_tree().get_first_node_in_group("propuesta")
	var botones: Array = m.get("_botones")
	var modulos: Array = m.get("_modulos")
	for i in botones.size():
		# Los tres buenos mas uno de mas, para ver las dos marcas a la vez.
		var debe := bool((modulos[i] as Dictionary).get("correcto", false))
		(botones[i] as Button).button_pressed = debe
	await _esperar(0.1)
	await _captura("09b_propuesta_elegida")
	m.call("_enviar")
	await _esperar(0.3)
	await _captura("10_propuesta_resuelta")
	m.call("cerrar")
	await _esperar(0.2)

	nivel.queue_free()
	await _esperar(0.3)

	# ---------------------------------------------------------- Oficina 4
	nivel = O4.instantiate()
	add_child(nivel)
	await _esperar(0.6)
	await _captura("11_oficina_4")

	jugador = nivel.get_node("Entidades/Player")
	nivel.get_node("Entidades/pitch/Zona").call("interactuar", jugador)
	await _esperar(0.5)
	await _captura("12_pitch")

	var t := get_tree().get_first_node_in_group("comite")
	if t != null:
		# Dos respuestas buenas y el veredicto, que es lo que interesa documentar:
		# el árbol pregunta por los tres directores y cierra con la llave.
		t.call("_elegir", 0)
		await _esperar(0.25)
		await _captura("12b_pitch_director_2")
		for i in 3:
			t.call("_elegir", 0)
			await _esperar(0.2)
		await _captura("13_pitch_respuesta")
		t.call("cerrar")
		await _esperar(0.2)

	print("Capturas en ", ProjectSettings.globalize_path(CARPETA))
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("progreso.json"):
		dir.remove("progreso.json")
	get_tree().quit()


func _captura(nombre: String) -> void:
	await _esperar(0.25)
	var img := get_viewport().get_texture().get_image()
	var ruta := "%s/%s.png" % [CARPETA, nombre]
	img.save_png(ruta)
	print("  captura ", nombre)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
