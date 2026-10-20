extends CanvasLayer

## EL MOTOR DE TRIVIA. Uno solo para las cuatro trivias del edificio.
##
## Las preguntas NO estan aqui: llegan en un JSON por parametro (data/trivia_*.json).
## Asi cambiar una pregunta es editar un fichero de texto, que es lo que hace falta
## en un juego que se entrega a un cliente y se retoca hasta el dia de la demo.
##
## Formato del JSON:
##   {
##     "titulo": "Trivia de portafolio",
##     "preguntas": [
##       {"pregunta": "...", "opciones": ["a","b","c","d"], "correcta": 1,
##        "explica": "por que es esa"}
##     ]
##   }
##
## Se responde con el raton o con las teclas 1-4 (hay que poder jugarlo sin soltar
## el teclado: el personaje se mueve con WASD). La nota es el porcentaje de
## aciertos, y con NOTA_MINIMA o mas se gana la insignia del piso - pero eso lo
## decide GameState con su tabla, no este script: aqui solo se apunta la nota.

signal terminada(nota: float)

## Lo que se ignora la E de la apertura, para que la misma pulsacion que abre la
## trivia no la cierre en el primer fotograma.
const IGNORAR_APERTURA := 0.2

const FONDO_BOTON := Color(0.13, 0.17, 0.22)
const FONDO_HOVER := Color(0.19, 0.24, 0.31)
const BIEN := Color(0.35, 0.72, 0.45)
const MAL := Color(0.80, 0.36, 0.34)
const ORO := Color(0.83, 0.635, 0.29)

@onready var veladura: Control = $Veladura
@onready var _cabecera: Label = $Veladura/Marco/Margen/Columnas/Cabecera
@onready var _pregunta: Label = $Veladura/Marco/Margen/Columnas/Pregunta
@onready var _opciones: VBoxContainer = $Veladura/Marco/Margen/Columnas/Opciones
@onready var _explicacion: Label = $Veladura/Marco/Margen/Columnas/Explicacion
@onready var _pie: Label = $Veladura/Marco/Margen/Columnas/Pie

var _preguntas: Array = []
var _titulo := ""
## Como se llama cada item en la cabecera: "pregunta" en una trivia, "objeción" en
## el pitch del comité. Viene del JSON porque el motor es el mismo.
var _etiqueta := "pregunta"
var _clave := ""
var _i := 0
var _aciertos := 0
var _respondida := false
var _en_resultado := false
var _abierto := false
var _espera := 0.0


func _ready() -> void:
	add_to_group("trivia")
	veladura.visible = false


func esta_abierto() -> bool:
	return _abierto


## Abre la trivia de un fichero. ruta es un res://...json.
func abrir(ruta: String, clave: String) -> void:
	if not FileAccess.file_exists(ruta):
		push_error("No existe la trivia " + ruta)
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	if not (datos is Dictionary) or not (datos.get("preguntas") is Array):
		push_error("La trivia " + ruta + " no tiene la forma esperada.")
		return
	var lista: Array = datos["preguntas"]
	if lista.is_empty():
		push_error("La trivia " + ruta + " no tiene preguntas.")
		return

	_preguntas = lista
	_titulo = str(datos.get("titulo", "Trivia"))
	_etiqueta = str(datos.get("etiqueta_pregunta", "pregunta"))
	_clave = clave
	_i = 0
	_aciertos = 0
	_respondida = false
	_en_resultado = false
	_abierto = true
	_espera = IGNORAR_APERTURA
	veladura.visible = true
	_mostrar()


func _mostrar() -> void:
	for b in _opciones.get_children():
		b.queue_free()
	var q: Dictionary = _preguntas[_i]
	_cabecera.text = "%s · %s %d de %d" % [_titulo.to_upper(), _etiqueta,
		_i + 1, _preguntas.size()]
	_pregunta.text = str(q.get("pregunta", ""))
	_explicacion.text = ""
	_explicacion.visible = false
	_pie.text = "responde con el ratón o con [1-4]"

	var opciones: Array = q.get("opciones", [])
	for i in range(opciones.size()):
		var b := Button.new()
		b.text = "%d.   %s" % [i + 1, str(opciones[i])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 42)
		# Sin foco: si el boton se queda con el foco, la barra espaciadora -que en
		# este juego tambien es interactuar- dispararia el boton en vez de hablar.
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
		b.add_theme_stylebox_override("normal", _caja(FONDO_BOTON))
		b.add_theme_stylebox_override("hover", _caja(FONDO_HOVER))
		b.add_theme_stylebox_override("pressed", _caja(FONDO_HOVER))
		b.pressed.connect(_responder.bind(i))
		_opciones.add_child(b)


func _responder(i: int) -> void:
	if _respondida or _en_resultado:
		return
	_respondida = true
	var q: Dictionary = _preguntas[_i]
	var correcta := int(q.get("correcta", 0))
	if i == correcta:
		_aciertos += 1

	# Los botones se pintan en vez de desaparecer: en un juego de formacion, ver cual
	# era la buena es la mitad del aprendizaje.
	for k in range(_opciones.get_child_count()):
		var b := _opciones.get_child(k) as Button
		b.disabled = true
		if k == correcta:
			b.add_theme_stylebox_override("disabled", _caja(BIEN.darkened(0.55), BIEN))
		elif k == i:
			b.add_theme_stylebox_override("disabled", _caja(MAL.darkened(0.55), MAL))
		else:
			b.add_theme_stylebox_override("disabled", _caja(FONDO_BOTON.darkened(0.35)))

	var explica := str(q.get("explica", ""))
	_explicacion.text = explica
	_explicacion.visible = explica != ""
	_pie.text = "[E] siguiente" if _i + 1 < _preguntas.size() else "[E] ver el resultado"


func _siguiente() -> void:
	if not _respondida:
		return
	_i += 1
	_respondida = false
	if _i >= _preguntas.size():
		_terminar()
	else:
		_mostrar()


func _terminar() -> void:
	_en_resultado = true
	for b in _opciones.get_children():
		b.queue_free()

	var total := _preguntas.size()
	var nota := 100.0 * float(_aciertos) / float(total)
	GameState.apuntar_puntaje(_clave, nota)

	_cabecera.text = _titulo.to_upper() + " · resultado"
	_pregunta.text = "%d de %d correctas — %d%%" % [_aciertos, total, int(round(nota))]
	_explicacion.text = ("Aprobado. La insignia del piso es tuya." if nota >= GameState.NOTA_MINIMA
		else "Necesitas el %d%%. Puedes repetirla las veces que quieras." % int(GameState.NOTA_MINIMA))
	_explicacion.visible = true
	_pie.text = "[E] cerrar"
	terminada.emit(nota)


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	veladura.visible = false


# ------------------------------------------------------------------- la entrada

func _process(delta: float) -> void:
	if _espera > 0.0:
		_espera = maxf(_espera - delta, 0.0)


func _unhandled_input(evento: InputEvent) -> void:
	if not _abierto or _espera > 0.0:
		return

	if evento.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
		return

	# Las teclas 1-4 responden. Se leen del evento y no del mapa de entrada para no
	# meter cuatro acciones nuevas en project.godot.
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		if tecla.pressed and not tecla.echo:
			var n := tecla.keycode - KEY_1
			if n >= 0 and n <= 3 and not _respondida and not _en_resultado:
				if n < _opciones.get_child_count():
					_responder(n)
					get_viewport().set_input_as_handled()
					return

	if evento.is_action_pressed("interactuar"):
		if _en_resultado:
			cerrar()
		elif _respondida:
			_siguiente()
		get_viewport().set_input_as_handled()


func _caja(fondo: Color, borde := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	if borde.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = borde
	s.set_corner_radius_all(4)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
