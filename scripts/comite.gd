extends CanvasLayer

## EL PITCH ANTE EL COMITÉ: el examen final.
##
## No es una trivia con preguntas sueltas, es un ARBOL: lo que respondes decide cual es
## la siguiente objecion. Si contestas con relleno («somos los mejores»), el director
## insiste y te da otra oportunidad; si bajas el precio, la conversacion se acaba ahi
## mismo, porque en ese momento deja de hablarse de valor.
##
## De ahi las dos reglas de puntuacion, que son lo que el documento pide ensenar:
##
##   1. Cada respuesta suma puntos por valor comercial. El maximo del arbol son 12.
##   2. Si en cualquier momento ofreces descuento, la nota se queda en 50 como techo:
##      se puede aprobar el resto del pitch, pero no la guerra de precios.
##
## Al aprobar, el Gerente General entrega la Llave del Auto Corporativo, que se guarda
## en el inventario de GameState y es lo que abre la calle.

signal terminada(nota: float)

const ORO := Color(0.83, 0.635, 0.29)
const BIEN := Color(0.35, 0.72, 0.45)
const MAL := Color(0.80, 0.36, 0.34)
const TEXTO := Color(0.90, 0.93, 0.97)
const TENUE := Color(0.62, 0.68, 0.76)
const FONDO_RESPUESTA := Color(0.15, 0.20, 0.26)

@onready var veladura: Control = $Veladura
@onready var _cabecera: Label = $Veladura/Marco/Margen/Columnas/Cabecera
@onready var _quien: Label = $Veladura/Marco/Margen/Columnas/Quien
@onready var _linea: Label = $Veladura/Marco/Margen/Columnas/Caja/Linea
@onready var _respuestas: VBoxContainer = $Veladura/Marco/Margen/Columnas/Respuestas
@onready var _etiqueta_confianza: Label = $Veladura/Marco/Margen/Columnas/Confianza/Texto
@onready var _barra: ProgressBar = $Veladura/Marco/Margen/Columnas/Confianza/Barra
@onready var _veredicto: Label = $Veladura/Marco/Margen/Columnas/Veredicto

var _datos := {}
var _clave := ""
var _nodos := {}
var _actual := ""
var _puntos := 0
var _precio := false
var _paso := 0
var _abierto := false
var _en_resultado := false
## Nota de la ultima partida: el progreso guarda la mejor, asi que sin esto no se sabe
## como fue el ultimo intento.
var ultima_nota := -1.0


func _ready() -> void:
	add_to_group("comite")
	veladura.visible = false
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.20, 0.24, 0.30)
	fondo.set_corner_radius_all(3)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = ORO
	relleno.set_corner_radius_all(3)
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", relleno)


func esta_abierto() -> bool:
	return _abierto


func abrir(ruta: String, clave: String) -> void:
	if not FileAccess.file_exists(ruta):
		push_error("No existe el guion del comité " + ruta)
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	if not (datos is Dictionary) or not (datos.get("nodos") is Dictionary):
		push_error("El guion " + ruta + " no tiene la forma esperada.")
		return

	_datos = datos
	_clave = clave
	_nodos = datos["nodos"]
	_actual = str(datos.get("inicio", ""))
	if not _nodos.has(_actual):
		push_error("El guion " + ruta + " empieza en un nodo que no existe.")
		return

	_puntos = 0
	_precio = false
	_paso = 0
	_en_resultado = false
	_abierto = true
	veladura.visible = true
	_veredicto.text = ""
	_mostrar()


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	veladura.visible = false


## Pinta la objecion actual: quien la lanza, que dice y las respuestas posibles.
func _mostrar() -> void:
	var nodo: Dictionary = _nodos[_actual]
	_paso += 1
	_cabecera.text = "COMITÉ COMERCIAL · objeción %d" % _paso
	_quien.text = str(nodo.get("quien", ""))
	_linea.text = str(nodo.get("texto", ""))

	for c in _respuestas.get_children():
		c.queue_free()
	var opciones: Array = nodo.get("opciones", [])
	for i in opciones.size():
		var o: Dictionary = opciones[i]
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, str(o.get("texto", ""))]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", TEXTO)
		b.add_theme_stylebox_override("normal", _caja(FONDO_RESPUESTA))
		b.add_theme_stylebox_override("hover",
			_caja(FONDO_RESPUESTA.lightened(0.10), ORO.darkened(0.45)))
		b.pressed.connect(_elegir.bind(i))
		_respuestas.add_child(b)

	_actualizar_confianza()


func _actualizar_confianza() -> void:
	var maximo := maxf(float(_datos.get("maximo", 12)), 1.0)
	var valor := clampf(100.0 * float(_puntos) / maximo, 0.0, 100.0)
	_barra.value = valor
	_etiqueta_confianza.text = "Confianza del comité: %d%%" % int(round(valor))


func _elegir(i: int) -> void:
	if _en_resultado or not _abierto:
		return
	var nodo: Dictionary = _nodos[_actual]
	var opciones: Array = nodo.get("opciones", [])
	if i < 0 or i >= opciones.size():
		return
	var o: Dictionary = opciones[i]
	_puntos += int(o.get("puntos", 0))
	if bool(o.get("precio", false)):
		_precio = true

	var siguiente := str(o.get("va_a", ""))
	# Cadena vacia = se acabo el pitch: es como se marca el ultimo nodo en el JSON.
	if siguiente == "" or not _nodos.has(siguiente):
		_terminar()
		return
	_actual = siguiente
	_mostrar()


func _terminar() -> void:
	_en_resultado = true
	var maximo := maxf(float(_datos.get("maximo", 12)), 1.0)
	var nota := 100.0 * float(_puntos) / maximo
	# El techo por guerra de precios se aplica DESPUES de calcular: da igual lo bien que
	# hayas defendido el resto, si regalaste margen la nota no pasa de 50.
	if _precio:
		nota = minf(nota, 50.0)
	nota = clampf(nota, 0.0, 100.0)
	ultima_nota = nota
	GameState.apuntar_puntaje(_clave, nota)

	for c in _respuestas.get_children():
		c.queue_free()

	# El marco se cierra sobre el veredicto: al desaparecer las respuestas quedaban
	# doscientos pixeles de nada al fondo, y una ventana que encoge se lee como "se
	# acabo" mucho mejor que una llena de hueco.
	var marco: Panel = $Veladura/Marco
	var tw := create_tween()
	tw.tween_property(marco, "offset_top", -196.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(marco, "offset_bottom", 196.0, 0.25
		).set_trans(Tween.TRANS_SINE)

	var aprobado := nota >= GameState.NOTA_MINIMA
	var cabeza := "APROBADO · %d%%" % int(round(nota)) if aprobado else (
		"NO APROBADO · %d%%" % int(round(nota)))
	var cuerpo := ""
	if _precio:
		cuerpo = str(_datos.get("nota_precio", ""))
	elif aprobado:
		cuerpo = str(_datos.get("nota_ok", ""))
	else:
		cuerpo = str(_datos.get("nota_mal", ""))

	var cierre := ""
	if aprobado:
		# La llave se guarda de verdad: es lo que el Acto 2 va a mirar para dejarte
		# salir del edificio.
		GameState.dar_objeto("llave_auto")
		cierre = "\n\nEl Gerente General te entrega la Llave del Auto Corporativo y la " \
			+ "Acreditación Comercial de Terreno. La puerta de la calle ya no te la " \
			+ "cierra nadie."

	_veredicto.text = "%s\n%s%s" % [cabeza, cuerpo, cierre]
	_veredicto.add_theme_color_override("font_color", BIEN if aprobado else MAL)
	_cabecera.text = "COMITÉ COMERCIAL · veredicto"
	_quien.text = ""
	_linea.text = "«%s»" % ("Bien defendido. Traiga la propuesta a la próxima reunión."
		if aprobado else "Gracias por su tiempo.")
	_actualizar_confianza()
	terminada.emit(nota)


func _unhandled_input(evento: InputEvent) -> void:
	if not _abierto:
		return
	if evento.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
		return
	if _en_resultado and evento.is_action_pressed("interactuar"):
		cerrar()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and not _en_resultado:
		var tecla := evento as InputEventKey
		if tecla.pressed and not tecla.echo:
			var n := tecla.keycode - KEY_1
			if n >= 0 and n < _respuestas.get_child_count():
				_elegir(n)
				get_viewport().set_input_as_handled()


func _caja(fondo: Color, borde := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	if borde.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = borde
	s.set_corner_radius_all(5)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s
