extends Node2D

## EL PISO, MONTADO DESDE UN PLANO.
##
## Esta escena no lleva el mobiliario colocado a mano: lo lee de data/oficina_01.json
## y lo construye. La razon es el Acto 1 entero: los cuatro pisos son la MISMA sala
## con otro plano, y la ciudad del Acto 2 es lo mismo con calles en vez de oficinas.
## Cuatro .tscn casi iguales se desincronizan en cuanto se cambia una pared; cuatro
## JSON no, porque la logica es una sola.
##
## Convencion de coordenadas, que es lo que hay que tener claro al editar el JSON:
##
##   - "pos" de un objeto es DONDE APOYA EN EL SUELO (el centro de su base, no su
##     centro). El dibujo se sube solo a partir de ahi. Asi el orden de dibujado
##     (y_sort) sale bien sin trucos: el comercial tapa un escritorio si sus pies
##     estan mas abajo, y queda detras si esta mas arriba.
##   - "col" es la caja de colision del mueble, tambien apoyada en esa base.
##   - "rect" de un muro es [x, y, ancho, alto] con el origen arriba a la izquierda
##     del mundo, que es como se mide en una tabla.

const JUGADOR := preload("res://scenes/player/player.tscn")
const GUION_INTERACTUABLE := preload("res://scripts/interactuable.gd")
const GUION_PUERTA := preload("res://scripts/puerta.gd")
const GUION_TERMINAL := preload("res://scripts/terminal_trivia.gd")
const GUION_NPC := preload("res://scripts/npc.gd")
const ARTE := "res://art/"

@export var plano := "res://data/oficina_01.json"

@onready var fondo: Node2D = $Fondo
@onready var entidades: Node2D = $Entidades
@onready var hud: CanvasLayer = $HUD

var _d := {}


func _ready() -> void:
	_d = leer_plano(plano)
	if _d.is_empty():
		push_error("No he podido leer el plano: " + plano)
		return

	var mundo: Array = _d.get("mundo", [1600, 900])
	_montar_suelos(mundo)
	_montar_muros()
	_montar_objetos()
	_montar_npcs()
	_montar_jugador(mundo)
	hud.call("configurar", str(_d.get("nombre", "")),
		str(_d.get("insignia", "")), str(_d.get("objetivo_hecho", "")))
	print("Piso montado: %s  (%d objetos, %d muros)"
		% [str(_d.get("nombre", "?")), entidades.get_child_count(),
		   _d.get("muros", []).size()])


## Lee el plano. Devuelve {} si no se puede: quien llama no arranca la sala a medias.
static func leer_plano(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		push_error("Falta el plano " + ruta)
		return {}
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {}
	var texto := f.get_as_text()
	f.close()
	var datos = JSON.parse_string(texto)
	if not (datos is Dictionary):
		push_error("El plano " + ruta + " no es un JSON de objeto.")
		return {}
	return datos


# ------------------------------------------------------------------- el suelo

func _montar_suelos(mundo: Array) -> void:
	var base := Sprite2D.new()
	base.name = "Suelo"
	base.texture = load(ARTE + str(_d.get("suelo", "suelo_oficina.png")))
	base.position = Vector2(float(mundo[0]) / 2.0, float(mundo[1]) / 2.0)
	fondo.add_child(base)

	# Alfombras: van en el fondo, debajo de todo, y no colisionan.
	for a in _d.get("alfombras", []):
		var alf := Sprite2D.new()
		alf.texture = load(ARTE + str(a["arte"]))
		alf.position = Vector2(float(a["pos"][0]), float(a["pos"][1]))
		fondo.add_child(alf)


# -------------------------------------------------------------------- los muros

func _montar_muros() -> void:
	for m in _d.get("muros", []):
		var r: Array = m["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var lado := str(m.get("lado", "arriba"))

		var cuerpo := StaticBody2D.new()
		cuerpo.collision_layer = 1
		cuerpo.collision_mask = 0
		cuerpo.position = rect.get_center()

		var forma := CollisionShape2D.new()
		var caja := RectangleShape2D.new()
		caja.size = rect.size
		forma.shape = caja
		cuerpo.add_child(forma)

		# Los muros de 64x64 son uniformes a lo largo de su eje: estirarlos no
		# deforma nada, asi que un muro de 1600 px es un solo sprite escalado. Por
		# eso no hace falta un TileMap para una sala rectangular.
		var horizontal := lado == "arriba" or lado == "abajo"
		var dib := Sprite2D.new()
		dib.texture = load(ARTE + ("muro_h.png" if horizontal else "muro_v.png"))
		dib.scale = Vector2(rect.size.x, rect.size.y) / 64.0
		dib.flip_v = lado == "abajo"
		dib.flip_h = lado == "derecha"
		cuerpo.add_child(dib)

		fondo.add_child(cuerpo)


# ------------------------------------------------------------------ el mobiliario

func _montar_objetos() -> void:
	var i := 0
	for o in _d.get("objetos", []):
		if not (o is Dictionary):
			continue
		var oo: Dictionary = o
		var nodo := Node2D.new()
		nodo.name = str(oo.get("id", "obj_%d" % i))
		var pos: Array = oo.get("pos", [0, 0])
		nodo.position = Vector2(float(pos[0]), float(pos[1]))
		entidades.add_child(nodo)

		var dib := Sprite2D.new()
		dib.name = "Dibujo"
		var ruta := ARTE + str(oo["arte"])
		if not ResourceLoader.exists(ruta):
			push_error("Falta el arte " + ruta + " que pide el objeto " + nodo.name)
			continue
		dib.texture = load(ruta)
		# Un color de marcado para objetos que comparten dibujo: los tres casos del
		# mural son la misma pantalla, y sin una senal el jugador no sabe cual esta
		# leyendo hasta que la abre. Se pinta una etiqueta en la base, como el lomo de
		# un archivador: tenir el panel entero se nota poco y ensucia el dibujo.
		if oo.has("tinte"):
			var color := Color(str(oo["tinte"]))
			var etiqueta := ColorRect.new()
			etiqueta.name = "Etiqueta"
			var ancho := dib.texture.get_width() * dib.scale.x
			etiqueta.size = Vector2(ancho, 7)
			etiqueta.position = Vector2(-ancho / 2.0, -5.0)
			etiqueta.color = color
			nodo.add_child(etiqueta)
		dib.position = Vector2(0, -dib.texture.get_height() / 2.0)
		nodo.add_child(dib)

		if oo.has("col"):
			nodo.add_child(_colision(oo))

		if oo.has("titulo"):
			nodo.add_child(_zona(oo, dib))

		# Los retos llevan marcador flotante. Va aqui y no en el JSON porque no es
		# contenido: es la senal de "esto se hace", y tiene que ser igual en los
		# cuatro pisos sin que nadie tenga que acordarse de anadirla.
		if oo.has("trivia"):
			var marca := _marca_reto(dib)
			marca.ready.connect(_latir_marca.bind(marca))
			nodo.add_child(marca)

		i += 1


## El rombo dorado que flota encima de un puesto de reto.
func _marca_reto(dib: Sprite2D) -> Sprite2D:
	var marca := Sprite2D.new()
	marca.name = "Marca"
	marca.texture = load(ARTE + "marca_reto.png")
	marca.scale = Vector2(2, 2)
	# Encima del mueble, no encima de su centro: el dibujo sube desde la base.
	var alto := dib.texture.get_height() * dib.scale.y
	marca.position = Vector2(0, -alto - 26.0)
	return marca


## El sube y baja del marcador. Se arranca en diferido, cuando el nodo ya esta en el
## arbol: un tween creado antes no lo procesa nadie y se queda en el primer fotograma.
func _latir_marca(marca: Sprite2D) -> void:
	if not is_instance_valid(marca):
		return
	var y := marca.position.y
	var tw := marca.create_tween().set_loops()
	tw.tween_property(marca, "position:y", y - 9.0, 0.95).set_trans(Tween.TRANS_SINE)
	tw.tween_property(marca, "position:y", y, 0.95).set_trans(Tween.TRANS_SINE)


func _colision(o: Dictionary) -> StaticBody2D:
	var c: Array = o["col"]
	var cuerpo := StaticBody2D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0

	var forma := CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = Vector2(float(c[0]), float(c[1]))
	forma.shape = caja
	# Apoyada en la base del mueble, no centrada en el dibujo: por los pies es por
	# donde te topas con una mesa.
	forma.position = Vector2(float(o.get("col_dx", 0.0)), -float(c[1]) / 2.0)
	cuerpo.add_child(forma)
	return cuerpo


# ------------------------------------------------------------- la gente del piso

## Monta los companeros de oficina del plano ("npcs").
##
## Van aparte de los muebles porque no son muebles: no llevan "col", se mueven, y
## algunos hablan. Pero comparten con ellos lo importante -el y-sort de
## Entidades-, asi que el jugador los tapa y ellos tapan al jugador igual que una
## mesa.
##
## Hablar no tiene codigo propio: si el plano les pone "titulo" y "texto", se les
## cuelga la MISMA zona de dialogo que usan las pantallas y los carteles
## (scripts/interactuable.gd). Por eso el prompt, el aclarado y el panel salen
## identicos sin escribir una linea nueva.
func _montar_npcs() -> void:
	var i := 0
	for n in _d.get("npcs", []):
		if not (n is Dictionary):
			continue
		var nn: Dictionary = n
		var ruta := ARTE + str(nn.get("arte", ""))
		if not ResourceLoader.exists(ruta):
			push_error("Falta la hoja del companero " + ruta)
			continue

		var npc := CharacterBody2D.new()
		npc.name = str(nn.get("id", "npc_%d" % i))
		var pos: Array = nn.get("pos", [0, 0])
		npc.position = Vector2(float(pos[0]), float(pos[1]))
		npc.collision_layer = 1
		npc.collision_mask = 1
		npc.set_script(GUION_NPC)

		var dib := Sprite2D.new()
		dib.name = "Sprite"
		dib.texture = load(ruta)
		dib.hframes = 7
		dib.vframes = 5
		dib.scale = Vector2(2, 2)
		dib.position = Vector2(0, -32)
		npc.add_child(dib)

		var forma := CollisionShape2D.new()
		var circulo := CircleShape2D.new()
		circulo.radius = 13.0
		forma.shape = circulo
		forma.position = Vector2(0, -10)
		npc.add_child(forma)

		if nn.has("titulo"):
			npc.add_child(_zona(nn, dib))

		# Configurar ANTES de entrar al arbol: _ready() lee de aqui hacia donde mira.
		npc.call("configurar", nn)
		entidades.add_child(npc)
		i += 1


## La zona que el jugador tiene que tener a tiro para poder pulsar E. Es un circulo
## puesto por delante del mueble, a la altura de su parte de arriba, que es donde
## esta lo que se mira: la pantalla, el cartel, la puerta.
func _zona(o: Dictionary, dib: Sprite2D) -> Area2D:
	var zona := Area2D.new()
	zona.name = "Zona"
	zona.collision_layer = 2
	zona.collision_mask = 0

	var es_puerta := bool(o.get("puerta", false))
	# Un objeto con "trivia" no abre un panel de texto: abre el minijuego. Es la
	# unica diferencia entre una pantalla informativa y la mesa del examen, y por eso
	# es un campo del plano y no un id especial escrito en el codigo.
	var es_trivia := o.has("trivia")
	var guion := GUION_PUERTA if es_puerta else (
		GUION_TERMINAL if es_trivia else GUION_INTERACTUABLE)
	zona.set_script(guion)
	zona.set("id", str(o.get("id", "")))
	zona.set("titulo", str(o.get("titulo", "")))
	zona.set("verbo", str(o.get("verbo", "Abrir" if es_puerta else "Revisar")))
	if es_puerta:
		zona.set("insignia", str(o.get("insignia", "")))
		zona.set("texto_bloqueado", str(o.get("texto_bloqueado", "")))
		zona.set("texto_abierto", str(o.get("texto_abierto", "")))
		zona.set("ir_a", str(o.get("ir_a", "")))
	elif es_trivia:
		zona.set("trivia", str(o.get("trivia", "")))
		zona.set("clave", str(o.get("clave", "")))
		zona.set("motor", str(o.get("motor", "trivia")))
	else:
		zona.set("texto", str(o.get("texto", "")))

	# La casilla, no la hoja entera: un companero tiene una textura de 112x160 con 35
	# dibujos dentro, y midiendo la textura su zona de dialogo saldria del tamano de
	# un sofa. Y la escala, porque el dibujo de la gente va al doble.
	var alto := dib.texture.get_height() / float(maxi(dib.vframes, 1)) * dib.scale.y
	var ancho := dib.texture.get_width() / float(maxi(dib.hframes, 1)) * dib.scale.x
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	# El radio por defecto: lo que mide el mueble mas un paso de holgura, para no
	# tener que pegarse a la pared. El JSON lo puede fijar con "radio".
	circulo.radius = float(o.get("radio", maxf(ancho, alto) * 0.45 + 44.0))
	forma.shape = circulo
	forma.position = Vector2(0, -alto * 0.55)
	zona.add_child(forma)
	return zona


# ------------------------------------------------------------------- el jugador

func _montar_jugador(mundo: Array) -> void:
	var jugador := JUGADOR.instantiate()
	var ini: Array = _d.get("inicio", [float(mundo[0]) / 2.0, float(mundo[1]) / 2.0])
	jugador.position = Vector2(float(ini[0]), float(ini[1]))

	var cam := jugador.get_node_or_null("Camara")
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(mundo[0])
		cam.limit_bottom = int(mundo[1])
		# El zoom del plano, o 1. Los pisos de la torre son de una pantalla justa
		# (1280x720 = la ventana), asi que se ve el piso entero de una vez y no hay
		# que pasear la camara por una sala vacia. La ciudad del Acto 2 dira un zoom
		# mas abierto en su propio JSON.
		var z := float(_d.get("zoom", 1.0))
		cam.zoom = Vector2(z, z)

	entidades.add_child(jugador)

	# El aviso de "[E] Revisar" va al HUD. Se conecta la senal por nombre y no con
	# un tipo concreto, para que el jugador no tenga que conocer al HUD.
	if jugador.has_signal("aviso"):
		jugador.connect("aviso", Callable(hud, "aviso"))


# ------------------------------------------------------------------ la ventana

## F11 alterna pantalla completa. No es un adorno: esto se enseña a gente, y una
## ventana con marco y barra de titulo delante de un cliente se nota.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo or tecla.physical_keycode != KEY_F11:
		return
	var completa := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if completa else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
