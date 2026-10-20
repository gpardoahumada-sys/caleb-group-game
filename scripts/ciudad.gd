extends Node2D

## LA CIUDAD DEL ACTO 2.
##
## Se monta entera por codigo desde data/ciudad.json: calles, aceras, manzanas,
## edificios, semaforos, trafico y gente. El JSON solo dice DONDE esta cada cosa; la
## geometria de las calles y los carriles sale de las tablas de centros de calle, que
## es lo que evita tener que dibujar a mano cada raya del asfalto.
##
## Reglas del mapa:
##
##   - Cada manzana es un rectangulo de parcela. La acera va POR FUERA de ese
##     rectangulo, comiendo el borde de la calle: asi una calle de 130 px deja 98 px
##     utiles, que es lo que necesitan dos carriles de coches de 44.
##   - El trafico da vueltas a las manzanas en sentido horario y desplazado a la
##     derecha del eje: es lo que hace que cada coche vaya por su carril.
##   - Los semaforos son un ciclo global por eje (verde, ambar, rojo). No hay
##     controladores por cruce porque a esta escala el jugador no puede ver dos
##     cruces a la vez: lo que nota es que hay un ritmo.

const ARTE := "res://art/ciudad/"
const PLANO := "res://data/ciudad.json"
const COCHE := preload("res://scenes/ciudad/coche.tscn")
const COCHE_NPC := preload("res://scenes/ciudad/coche_npc.tscn")
const PEATON := preload("res://scenes/ciudad/peaton.tscn")

## Ciclo del semaforo, en segundos. Suma 18: verde largo, ambar corto.
const VERDE := 7.0
const AMBAR := 2.0

## A que distancia del edificio se puede pulsar la E.
const ALCANCE := 190.0

@onready var _suelo: Node2D = $Suelo
@onready var _manzanas: Node2D = $Manzanas
@onready var _entidades: Node2D = $Entidades
@onready var _hud: Node = $HUD
@onready var _panel: Node = $PanelInfo

var _datos := {}
var _mundo := Vector2(3300, 1660)
var _calles_v: Array = []
var _calles_h: Array = []
var _ancho := 130.0
var _acera := 16.0
var _semaforos: Array = []
var _reloj := 0.0
var _coche: Node = null
var _marcas: Array = []
var _cerca: Dictionary = {}


func _ready() -> void:
	if not _leer_plano():
		return
	_montar_suelo()
	_montar_rayas()
	_montar_manzanas()
	_montar_semaforos()
	_montar_trafico()
	_montar_gente()
	_montar_coche()
	_hud.call("configurar", str(_datos.get("nombre", "Ciudad")), "", "",
		"cruza la ciudad y encuentra a los tres clientes")
	_panel.connect("cerrado", _al_cerrar_panel)


func _leer_plano() -> bool:
	if not FileAccess.file_exists(PLANO):
		push_error("No existe el plano de la ciudad " + PLANO)
		return false
	var f := FileAccess.open(PLANO, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	if not (datos is Dictionary):
		push_error("El plano de la ciudad no se entiende.")
		return false
	_datos = datos
	var mundo: Array = datos.get("mundo", [3300, 1660])
	_mundo = Vector2(float(mundo[0]), float(mundo[1]))
	_calles_v = datos.get("calles_v", [])
	_calles_h = datos.get("calles_h", [])
	_ancho = float(datos.get("ancho_calle", 130))
	_acera = float(datos.get("acerado", 16))
	return true


# ------------------------------------------------------------------- el suelo

## Una textura repetida del tamano que haga falta. Con region + repeat se evita
## clonar el PNG cien veces para llenar la ciudad.
func _textura(ruta: String, rect: Rect2, repetir := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ruta)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	if repetir:
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = rect.position
	return s


func _montar_suelo() -> void:
	_suelo.add_child(_textura(ARTE + "asfalto.png", Rect2(Vector2.ZERO, _mundo)))


## Las rayas discontinuas del eje de cada calle, saltandose los cruces: una raya
## pintada encima de una interseccion delata que el mapa es una cuadricula pegada.
func _montar_rayas() -> void:
	var linea := load(ARTE + "linea.png")
	for x in _calles_v:
		var cx := float(x)
		var y := 0.0
		while y < _mundo.y:
			if not _en_cruce(cx, y + 17.0):
				var s := Sprite2D.new()
				s.texture = linea
				s.centered = false
				s.position = Vector2(cx - linea.get_width() / 2.0, y)
				_suelo.add_child(s)
			y += 70.0
	for y in _calles_h:
		var cy := float(y)
		var x := 0.0
		while x < _mundo.x:
			if not _en_cruce(x + 17.0, cy):
				var s := Sprite2D.new()
				s.texture = linea
				s.centered = false
				s.rotation = PI / 2.0
				s.position = Vector2(x + 17.0, cy)
				_suelo.add_child(s)
			x += 70.0


## ¿Ese punto cae dentro de un cruce de calles?
func _en_cruce(x: float, y: float) -> bool:
	var media := _ancho / 2.0
	for vx in _calles_v:
		if absf(x - float(vx)) < media and _alguna_h(y, media):
			return true
	return false


func _alguna_h(y: float, margen: float) -> bool:
	for cy in _calles_h:
		if absf(y - float(cy)) < margen:
			return true
	return false


# --------------------------------------------------------------- las manzanas

func _montar_manzanas() -> void:
	var marcas: Dictionary = _datos.get("marcas", {})
	for m in _datos.get("manzanas", []):
		var rect := _rect_de(m)
		# Acera: un marco por fuera de la parcela, comiendo el borde de la calle.
		_manzanas.add_child(_textura(ARTE + "acera.png",
			Rect2(rect.position - Vector2(_acera, _acera),
				rect.size + Vector2(_acera, _acera) * 2.0)))
		# Parcela pavimentada. El cesped se queda en los parterres: una manzana entera
		# de hierba se lee como un parque y hace que la ciudad parezca vacia.
		_manzanas.add_child(_textura(ARTE + "plaza.png", rect))
		for parterre in m.get("parterres", []):
			var r: Array = parterre
			_manzanas.add_child(_textura(ARTE + "cesped.png",
				Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))))

		# Aparcamientos y demas relleno: sin esto la parcela es una losa con un
		# edificio flotando en medio.
		for x in m.get("extras", []):
			var xp: Array = x.get("pos", [0, 0])
			var xt: Array = x.get("tam", [400, 120])
			_manzanas.add_child(_textura(ARTE + str(x["arte"]),
				Rect2(float(xp[0]), float(xp[1]), float(xt[0]), float(xt[1])),
				false))

		for e in m.get("edificios", []):
			var pos: Array = e.get("pos", [0, 0])
			var tam: Array = e.get("tam", [400, 320])
			var sprite := Sprite2D.new()
			sprite.texture = load(ARTE + str(e["arte"]))
			sprite.centered = false
			sprite.position = Vector2(float(pos[0]), float(pos[1]))
			if sprite.texture.get_size() != Vector2(float(tam[0]), float(tam[1])):
				sprite.scale = Vector2(float(tam[0]) / sprite.texture.get_width(),
					float(tam[1]) / sprite.texture.get_height())
			_manzanas.add_child(sprite)

			# El edificio es solido: sin esto se puede atravesar la ciudad entera
			# conduciendo en linea recta.
			_solido(Vector2(float(pos[0]), float(pos[1])),
				Vector2(float(tam[0]), float(tam[1])))

			var marca := str(e.get("marca", ""))
			if marca != "" and marcas.has(marca):
				var info: Dictionary = marcas[marca]
				_marcas.append({
					"marca": marca,
					"nombre": str(info.get("nombre", marca)),
					"verbo": str(info.get("verbo", "Ver")),
					"texto": str(info.get("texto", "")),
					"ir_a": str(info.get("ir_a", "")),
					# La puerta esta en el centro de la fachada, no en el centro del
					# edificio: hay que llegar a la puerta.
					"pos": Vector2(float(pos[0]) + float(tam[0]) / 2.0,
						float(pos[1]) + float(tam[1]) - 40.0),
				})

		# Arboles en la acera, uno por esquina y otro a mitad de cada lado.
		_montar_arboles(rect)


func _montar_arboles(rect: Rect2) -> void:
	var arte := load(ARTE + "arbol.png")
	var puntos := [
		rect.position + Vector2(26, 26),
		Vector2(rect.position.x + rect.size.x - 26, rect.position.y + 26),
		Vector2(rect.position.x + 26, rect.position.y + rect.size.y - 26),
		rect.position + rect.size - Vector2(26, 26),
		Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y - 8),
	]
	for p in puntos:
		var s := Sprite2D.new()
		s.texture = arte
		s.position = p
		_manzanas.add_child(s)


func _rect_de(m: Dictionary) -> Rect2:
	var r: Array = m.get("rect", [0, 0, 100, 100])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _solido(pos: Vector2, tam: Vector2) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = tam
	forma.shape = caja
	forma.position = pos + tam / 2.0
	cuerpo.add_child(forma)
	add_child(cuerpo)


# ------------------------------------------------------------- los semaforos

func _montar_semaforos() -> void:
	for vx in _calles_v:
		for hy in _calles_h:
			# Uno por eje, en la esquina de la manzana: el que mira a la calle
			# horizontal y el que mira a la vertical.
			_semaforos.append(_crear_semaforo(
				Vector2(float(vx) - _ancho / 2.0 - _acera - 10.0,
					float(hy) - _ancho / 2.0 - _acera - 30.0), "h"))
			_semaforos.append(_crear_semaforo(
				Vector2(float(vx) + _ancho / 2.0 + _acera + 10.0,
					float(hy) - _ancho / 2.0 - _acera - 30.0), "v"))


func _crear_semaforo(pos: Vector2, eje: String) -> Dictionary:
	var s := Sprite2D.new()
	s.texture = load(ARTE + "semaforo_verde.png")
	s.position = pos
	# Fuera del y_sort de las entidades: un semaforo no debe tapar a un coche.
	_manzanas.add_child(s)
	return {"pos": pos, "eje": eje, "estado": "verde", "sprite": s}


func _process(delta: float) -> void:
	_reloj = fmod(_reloj + delta, (VERDE + AMBAR) * 2.0)
	var ciclo := VERDE + AMBAR
	var v_estado := "verde" if _reloj < VERDE else ("ambar" if _reloj < ciclo else "rojo")
	var h_estado := "rojo" if _reloj < ciclo else (
		"verde" if _reloj < ciclo + VERDE else "ambar")
	for s in _semaforos:
		var dict: Dictionary = s
		var quiero := v_estado if str(dict["eje"]) == "v" else h_estado
		if str(dict["estado"]) != quiero:
			dict["estado"] = quiero
			(dict["sprite"] as Sprite2D).texture = load(ARTE + "semaforo_%s.png" % quiero)
	_buscar_cerca()


# ----------------------------------------------------------------- el trafico

## La vuelta a una manzana, desplazada 30 px a la derecha del eje de cada calle.
func _ruta_manzana(rect: Rect2) -> Array:
	var y_arriba := rect.position.y - _ancho / 2.0 + 30.0
	var y_abajo := rect.position.y + rect.size.y + _ancho / 2.0 - 30.0
	var x_izq := rect.position.x - _ancho / 2.0 + 30.0
	var x_der := rect.position.x + rect.size.x + _ancho / 2.0 - 30.0
	return [
		Vector2(x_izq, y_arriba), Vector2(x_der, y_arriba),
		Vector2(x_der, y_abajo), Vector2(x_izq, y_abajo),
	]


func _montar_trafico() -> void:
	var colores := ["coche_npc1.png", "coche_npc2.png", "coche_npc3.png"]
	var i := 0
	for m in _datos.get("manzanas", []):
		var rect := _rect_de(m)
		var ruta := _ruta_manzana(rect)
		# Dos coches por manzana, en puntos distintos de la vuelta.
		for k in 2:
			var coche := COCHE_NPC.instantiate()
			(coche.get_node("Dibujo") as Sprite2D).texture = load(
				ARTE + colores[i % colores.size()])
			coche.ruta = ruta
			coche.semaforos = _semaforos
			var tramo := k * 2
			coche.position = ruta[tramo % ruta.size()]
			coche.global_position = coche.position
			coche.set("_indice", (tramo + 1) % ruta.size())
			if k == 1:
				coche.position = (ruta[0] + ruta[1]) / 2.0
				coche.global_position = coche.position
				coche.set("_indice", 1)
			_entidades.add_child(coche)
			i += 1


func _montar_gente() -> void:
	var hojas := ["npc_verde.png", "npc_granate.png", "npc_mayor.png",
		"npc_ejecutivo.png"]
	var i := 0
	for m in _datos.get("manzanas", []):
		var rect := _rect_de(m)
		# La gente anda por la ACERA, que esta por fuera de la parcela: si se les pone
		# en el borde de la parcela caminan por dentro del jardin y parece que flotan
		# sobre el cesped.
		var margen := 8.0
		var puntos := [
			rect.position - Vector2(margen, margen),
			Vector2(rect.position.x + rect.size.x + margen, rect.position.y - margen),
			Vector2(rect.position.x + rect.size.x + margen,
				rect.position.y + rect.size.y + margen),
			Vector2(rect.position.x - margen, rect.position.y + rect.size.y + margen),
		]
		var cantidad := 3
		for k in cantidad:
			var p := PEATON.instantiate()
			(p.get_node("Dibujo") as Sprite2D).texture = load(
				"res://art/" + str(hojas[i % hojas.size()]))
			# Los peatones son pequenos: se doblan para que se vean, igual que en la
			# torre.
			(p.get_node("Dibujo") as Sprite2D).scale = Vector2(2, 2)
			p.ruta = puntos
			p.position = puntos[k % puntos.size()]
			_entidades.add_child(p)
			i += 1


# ------------------------------------------------------------- el coche y las puertas

func _montar_coche() -> void:
	var inicio: Array = _datos.get("inicio", [1450, 800, 90])
	_coche = COCHE.instantiate()
	_coche.position = Vector2(float(inicio[0]), float(inicio[1]))
	_coche.rotation = deg_to_rad(float(inicio[2]))
	_entidades.add_child(_coche)
	var cam: Camera2D = _coche.get_node("Camara")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(_mundo.x)
	cam.limit_bottom = int(_mundo.y)
	cam.make_current()


## El edificio que tiene al coche a tiro, o {} si no hay ninguno.
func _buscar_cerca() -> void:
	if _coche == null:
		return
	var mejor: Dictionary = {}
	var menor := ALCANCE
	for m in _marcas:
		var d: float = (_coche.global_position - (m["pos"] as Vector2)).length()
		if d < menor:
			menor = d
			mejor = m
	if mejor.get("marca", "") != _cerca.get("marca", ""):
		_cerca = mejor
		_hud.call("aviso", "[E] " + str(mejor["verbo"]) if not mejor.is_empty() else "")


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("interactuar") or _cerca.is_empty():
		return
	if bool(_coche.get("puede_conducir")) == false:
		return
	get_viewport().set_input_as_handled()
	var ir_a := str(_cerca.get("ir_a", ""))
	if ir_a != "":
		# Volver a la torre. Se suelta la escena actual antes de cambiarla, o Godot se
		# lleva por delante el arbol entero a mitad de fotograma.
		get_tree().current_scene = null
		get_tree().change_scene_to_file(ir_a)
		return
	_coche.set("puede_conducir", false)
	_hud.call("aviso", "")
	_panel.call("abrir", str(_cerca["nombre"]), str(_cerca.get("texto", "")))


func _al_cerrar_panel() -> void:
	if _coche != null:
		_coche.set("puede_conducir", true)
	_cerca = {}
