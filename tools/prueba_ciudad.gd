extends Node

## PRUEBA DE LA CIUDAD (ACTO 2).
##
## Lo que comprueba, y por que:
##
##   1. Que la ciudad se monta con coche, trafico, gente y semaforos. Si falta la
##      mitad, el mapa parece un decorado y no una ciudad.
##   2. Que el coche ANDA: acelerando se mueve y adquiere velocidad. Un coche que no
##      se mueve es un sprite bonito.
##   3. Que los edificios son solidos: acelerando contra el banco no se atraviesa.
##      Sin colision, la ciudad es un fondo de pantalla.
##   4. Que estan los tres clientes y la torre, con sus nombres del documento.
##   5. Que el semaforo cambia de estado solo.
##   6. Que la puerta de la calle del lobby lleva a la ciudad (el ida y vuelta).
##
##   godot --headless --path . res://tools/prueba_ciudad.tscn

const CIUDAD := preload("res://scenes/ciudad/ciudad.tscn")

var _fallos := 0


func _ready() -> void:
	GameState.nuevo_juego()

	var nivel: Node = CIUDAD.instantiate()
	add_child(nivel)
	await _esperar(0.6)

	var coche: Node = nivel.get_node_or_null("Entidades/Coche")
	if coche == null:
		_fallar("la ciudad no tiene coche")
		_acabar()
		return

	# --- 1. lo que hay montado ---------------------------------------------
	var entidades: Node = nivel.get_node("Entidades")
	var coches := 0
	var gente := 0
	for n in entidades.get_children():
		if n == coche:
			continue
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("coche_npc.gd"):
			coches += 1
		elif n.get_script() != null and str(n.get_script().resource_path).ends_with("peaton_ciudad.gd"):
			gente += 1
	_comprobar(coches >= 8, "hay trafico circulando (%d coches)" % coches)
	_comprobar(gente >= 12, "hay gente en las aceras (%d peatones)" % gente)
	# Dos por cruce: uno por eje (el que mira a la calle horizontal y el de la
	# vertical). 4 calles verticales x 3 horizontales = 12 cruces.
	_comprobar((nivel.get("_semaforos") as Array).size() == 24,
		"hay dos semáforos por cruce, 24 en total (%d)" % (nivel.get("_semaforos") as Array).size())

	# --- 2. el coche anda ---------------------------------------------------
	var antes: Vector2 = coche.global_position
	Input.action_press("mover_arriba")
	await _esperar(0.7)
	Input.action_release("mover_arriba")
	var velocidad: float = coche.get("velocidad")
	var despues: Vector2 = coche.global_position
	_comprobar(velocidad > 60.0, "acelerando, el coche coge velocidad (%.0f)" % velocidad)
	_comprobar(antes.distance_to(despues) > 40.0,
		"y se desplaza (%.0f px)" % antes.distance_to(despues))
	await _esperar(1.0)
	_comprobar(float(coche.get("velocidad")) < velocidad,
		"soltando el acelerador, frena solo (%.0f)" % float(coche.get("velocidad")))

	# --- 3. los edificios son solidos ---------------------------------------
	# Se coloca el coche justo debajo del banco y se acelera hacia el: tiene que
	# quedarse fuera. El banco esta en (255, 920) y mide 620x460.
	coche.global_position = Vector2(565, 1440)
	coche.rotation = 0.0
	coche.set("velocidad", 0.0)
	await _esperar(0.15)
	Input.action_press("mover_arriba")
	await _esperar(1.4)
	Input.action_release("mover_arriba")
	var y_final: float = coche.global_position.y
	_comprobar(y_final > 1330.0,
		"el coche no atraviesa el edificio (se paró en y=%.0f)" % y_final)

	# --- 4. los tres clientes y la torre ------------------------------------
	var marcas: Array = nivel.get("_marcas")
	var nombres := ""
	for m in marcas:
		nombres += str((m as Dictionary).get("nombre", "")) + " | "
	for esperado in ["FinBank", "OmniRetail", "MediHealth", "Torre Caleb Group"]:
		_comprobar(nombres.contains(esperado), "está «%s» en el mapa (%s)" % [esperado, esperado])
	_comprobar(marcas.size() == 4, "hay 4 sitios con puerta (%d)" % marcas.size())
	# La vuelta a la torre: la puerta de la ciudad apunta al lobby y el escenario
	# existe. El cambio de escena en si es el mismo mecanismo que el ascensor, que ya
	# se prueba cambiando de piso en prueba_todo.
	for m in marcas:
		if str((m as Dictionary).get("marca", "")) == "torre":
			var vuelta := str((m as Dictionary).get("ir_a", ""))
			_comprobar(vuelta.ends_with("oficina_01.tscn") and ResourceLoader.exists(vuelta),
				"la puerta de la torre vuelve al lobby (%s)" % vuelta)

	# --- 5. el semaforo cambia ----------------------------------------------
	var estados := {}
	for i in 3:
		var e := ""
		for s in nivel.get("_semaforos"):
			e += str((s as Dictionary).get("estado", ""))
		estados[e] = true
		await _esperar(3.2)
	_comprobar(estados.size() >= 2, "el semáforo cambia de estado solo (%d combinaciones)"
		% estados.size())

	# --- 6. el ida y vuelta con la torre -----------------------------------
	var f := FileAccess.open("res://data/oficina_01.json", FileAccess.READ)
	var plano = JSON.parse_string(f.get_as_text())
	f.close()
	var ir_a := ""
	for o in plano["objetos"]:
		if str(o.get("id", "")) == "salida":
			ir_a = str(o.get("ir_a", ""))
	_comprobar(ir_a.ends_with("ciudad.tscn"),
		"la puerta de la calle del lobby lleva a la ciudad (%s)" % ir_a)

	_acabar()


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
	Input.action_release("mover_arriba")
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
