extends "res://scripts/personaje_base.gd"

## EL COMERCIAL.
##
## Movimiento cenital de ocho direcciones con algo de inercia (arrancar y frenar no
## es instantaneo: da peso sin llegar a resbalar), hoja de cuatro filas -abajo,
## arriba, izquierda, derecha- y una zona de alcance que es la que detecta los
## paneles, pantallas y puertas del piso.
##
## NO es el jugador del juego de terror. Aquel llevaba armas, magia, vida,
## experiencia y linterna, y arrastrarlo aqui habria sido cargar con 90 KB de cosas
## que este juego no usa. Esto es lo que hace falta y nada mas: caminar, mirar y
## hablar. Si algun dia hace falta correr, se anade aqui y se acaba.

signal aviso(texto: String)

const VELOCIDAD := 180.0
const ACELERACION := 1500.0
const ROZAMIENTO := 2000.0

## Se pone a true mientras hay un panel abierto: el personaje se queda quieto en
## vez de seguir andando detras del texto.
var bloqueado := false

var _mirando := Vector2.DOWN
var _objetivo: Node = null
var _texto := ""
var _panel: Node = null
## Segundos que hay que esperar antes de poder volver a pulsar la E. Existe por un
## fallo de verdad que se cazo con la prueba: el panel se cerraba en el
## _unhandled_input de la MISMA pulsacion que lo abrio, y en ese mismo fotograma
## is_action_just_pressed seguia valiendo true, asi que el jugador lo volvia a
## abrir en el acto. Se veia como un panel que no se cierra nunca.
var _bloqueo_e := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var zona: Area2D = $Zona


func _ready() -> void:
	add_to_group("jugador")


func _physics_process(delta: float) -> void:
	_bloqueo_e = maxf(_bloqueo_e - delta, 0.0)
	if bloqueado or _ui_abierta():
		velocity = velocity.move_toward(Vector2.ZERO, ROZAMIENTO * delta)
		move_and_slide()
		_animar(0.0, delta)
		return

	var entrada := Input.get_vector("mover_izquierda", "mover_derecha",
		"mover_arriba", "mover_abajo")
	if entrada.length_squared() > 0.01:
		velocity = velocity.move_toward(entrada * VELOCIDAD, ACELERACION * delta)
		## La direccion del dibujo la manda el movimiento y no el ultimo vector: si
		## no, soltar la tecla dejaria al personaje mirando a donde ya no vas.
		_mirando = entrada.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ROZAMIENTO * delta)
	move_and_slide()

	_animar(entrada.length(), delta)
	_buscar_objetivo()
	if _bloqueo_e <= 0.0 and Input.is_action_just_pressed("interactuar") \
			and is_instance_valid(_objetivo):
		_objetivo.call("interactuar", self)


# ------------------------------------------------------------ lo que hay cerca

## De todo lo que se solapa con la zona de alcance, se queda con lo mas cercano: si
## estas entre la puerta y el cartel, la E abre lo que tienes delante.
func _buscar_objetivo() -> void:
	var mejor: Node = null
	var mejor_d := INF
	for a in zona.get_overlapping_areas():
		if not a.has_method("interactuar"):
			continue
		var n := a as Node2D
		if n == null:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = a

	if mejor != _objetivo:
		# El que deja de estar a tiro se apaga y el nuevo se aclara: sin esto, en un
		# piso con muebles no hay forma de saber que la pantalla se toca y una silla
		# no, salvo pegandose a cada cosa.
		if is_instance_valid(_objetivo) and _objetivo.has_method("destacar"):
			_objetivo.call("destacar", false)
		_objetivo = mejor
		if is_instance_valid(_objetivo) and _objetivo.has_method("destacar"):
			_objetivo.call("destacar", true)
		_anunciar()


## El texto de "[E] Revisar" del HUD. Se emite solo cuando CAMBIA: el HUD no
## necesita enterarse sesenta veces por segundo de lo mismo.
func _anunciar() -> void:
	var texto := ""
	if is_instance_valid(_objetivo) and _objetivo.has_method("prompt"):
		texto = str(_objetivo.call("prompt"))
	if texto != _texto:
		_texto = texto
		aviso.emit(texto)


# --------------------------------------------------------------------- el panel

func abrir_panel(titulo: String, texto: String) -> void:
	var panel := _el_panel()
	if panel == null:
		push_warning("No hay panel de informacion en la escena.")
		return
	panel.call("abrir", titulo, texto)
	bloqueado = true
	# El prompt se apaga mientras lees: si no, se queda debajo del texto.
	if _texto != "":
		_texto = ""
		aviso.emit("")


func _el_panel() -> Node:
	if _panel == null or not is_instance_valid(_panel):
		_panel = get_tree().get_first_node_in_group("panel_info")
		if _panel != null and _panel.has_signal("cerrado"):
			_panel.connect("cerrado", _al_cerrar_panel)
	return _panel


## ¿Hay alguna ventana abierta -un panel de texto o un minijuego-? Se pregunta a los
## grupos en vez de guardar una bandera: asi un minijuego nuevo solo tiene que
## apuntarse a su grupo y el jugador deja de andar por detras sin tocar esto.
const GRUPOS_DE_INTERFAZ := ["trivia", "arrastrar", "clasificador", "propuesta", "comite"]

func _ui_abierta() -> bool:
	var panel := _el_panel()
	if panel != null and bool(panel.call("esta_abierto")):
		return true
	for grupo in GRUPOS_DE_INTERFAZ:
		var ui := get_tree().get_first_node_in_group(grupo)
		if ui != null and ui.has_method("esta_abierto") and bool(ui.call("esta_abierto")):
			return true
	return false


func _al_cerrar_panel() -> void:
	bloqueado = false
	_bloqueo_e = 0.25
	# Al salir del panel puede que el cartel que acabas de leer ya diga otra cosa
	# ("Repasar" en vez de "Revisar"): se vuelve a preguntar.
	_objetivo = null
	_buscar_objetivo()


# ----------------------------------------------------------------- el dibujo

func _animar(ratio: float, delta: float) -> void:
	pintar(_mirando, ratio, delta)
