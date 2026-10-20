extends Node

## CAPTURAS DE LA CIUDAD.
##
## Arranca la ciudad, conduce un poco y guarda tres o cuatro vistas: la salida de la
## torre, un cruce con trafico y cada uno de los tres clientes. Sirve para revisar el
## mapa sin tener que jugarlo a mano cada vez.
##
##   godot --path . res://tools/captura_ciudad.tscn

const CIUDAD := preload("res://scenes/ciudad/ciudad.tscn")
const CARPETA := "user://capturas"

var nivel: Node
var coche: Node


func _ready() -> void:
	GameState.nuevo_juego()
	GameState.dar_insignia("identidad")
	GameState.dar_insignia("catalogo")
	GameState.dar_insignia("casos")
	GameState.dar_insignia("acreditacion")
	GameState.dar_objeto("llave_auto")

	nivel = CIUDAD.instantiate()
	add_child(nivel)
	await _esperar(0.8)
	coche = nivel.get_node_or_null("Entidades/Coche")
	if coche == null:
		push_error("La ciudad no tiene coche")
		get_tree().quit()
		return

	# 1. La salida de la torre, con la avenida por delante.
	await _captura("20_ciudad_salida")

	# 2. Un cruce con semaforos y trafico circulando.
	await _teletransporte(Vector2(1065, 765), 0.0)
	await _esperar(1.6)
	await _captura("21_ciudad_cruce")

	# 3. Los tres clientes, con el coche delante de la puerta.
	for dato in [["22_finbank", Vector2(565, 1300)], ["23_omniretail", Vector2(1565, 1360)],
			["24_medihealth", Vector2(2565, 1360)]]:
		await _teletransporte(dato[1], 0.0)
		await _esperar(0.7)
		await _captura(dato[0])

	# 4. La torre desde la calle, de vuelta.
	await _teletransporte(Vector2(1565, 790), 0.0)
	await _esperar(0.7)
	await _captura("25_ciudad_torre")

	print("Capturas en ", ProjectSettings.globalize_path(CARPETA))
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("progreso.json"):
		dir.remove("progreso.json")
	get_tree().quit()


func _teletransporte(pos: Vector2, grados: float) -> void:
	coche.global_position = pos
	coche.rotation = deg_to_rad(grados)
	await _esperar(0.5)


func _captura(nombre: String) -> void:
	await _esperar(0.3)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [CARPETA, nombre])
	print("  captura ", nombre)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
