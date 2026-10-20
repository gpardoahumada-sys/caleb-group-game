extends CanvasLayer

## EL CLASIFICADOR DE DOLORES: la cinta transportadora.
##
## Llegan quejas de empresas, una detras de otra, y hay que mandar cada una al area
## de solucion que le toca ANTES de que se acabe el tiempo. Es el unico minijuego del
## edificio con reloj, y por eso no usa el motor de arrastrar: con un cronometro
## encima, arrastrar es una pelea. Aqui se responde con un clic en el area o con las
## teclas 1-4, que es lo que se hace cuando hay prisa.
##
## La nota es aciertos entre documentos. Un documento que se pasa de tiempo cuenta
## como fallado: en una cinta de verdad, lo que no se clasifica se cae de la cinta.
##
## Las areas y los documentos vienen del JSON (data/clasificador_dolores.json), asi
## que cambiar el catalogo de quejas es editar un fichero de texto.

signal terminada(nota: float)

const IGNORAR_APERTURA := 0.2
## Lo que se queda el veredicto en pantalla antes del siguiente documento.
const PAUSA_VEREDICTO := 0.45
## A partir de aqui la barra se pone roja y late. Es el aviso de que el documento se
## va a caer: sin el, el reloj se agota sin que el jugador se entere.
const UMBRAL_PELIGRO := 3.0

const FONDO_AREA := Color(0.15, 0.20, 0.26)
const FONDO_AREA_BUENA := Color(0.20, 0.42, 0.26)
const FONDO_AREA_MALA := Color(0.45, 0.20, 0.20)
const BIEN := Color(0.35, 0.72, 0.45)
const MAL := Color(0.80, 0.36, 0.34)
const ORO := Color(0.83, 0.635, 0.29)

@onready var veladura: Control = $Veladura
@onready var _cabecera: Label = $Veladura/Marco/Margen/Columnas/Cabecera
@onready var _instrucciones: Label = $Veladura/Marco/Margen/Columnas/Instrucciones
@onready var _cinta: Control = $Veladura/Marco/Margen/Columnas/Cinta
@onready var _documento: Panel = $Veladura/Marco/Margen/Columnas/Cinta/Documento
@onready var _texto: Label = $Veladura/Marco/Margen/Columnas/Cinta/Documento/Texto
@onready var _barra: ProgressBar = $Veladura/Marco/Margen/Columnas/Barra
@onready var _areas: HBoxContainer = $Veladura/Marco/Margen/Columnas/Areas
@onready var _veredicto: Label = $Veladura/Marco/Margen/Columnas/Veredicto
@onready var _pie: Label = $Veladura/Marco/Margen/Columnas/Pie

var _datos := {}
var _clave := ""
var _documentos: Array = []
var _areas_json: Array = []
var _botones := {}          # id de area -> Button
var _i := 0
var _aciertos := 0
var _restante := 0.0
var _segundos := 9.0
var _abierto := false
var _espera := 0.0
var _pendiente_avance := false
var _en_resultado := false
var _en_peligro := false
var _relleno_normal: StyleBoxFlat
var _relleno_peligro: StyleBoxFlat


func _ready() -> void:
	add_to_group("clasificador")
	veladura.visible = false
	# La barra del reloj, en dorado y sin numero encima: lo que se mira es cuanto
	# queda, no el porcentaje.
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.10, 0.13, 0.17)
	fondo.set_corner_radius_all(3)
	_relleno_normal = StyleBoxFlat.new()
	_relleno_normal.bg_color = ORO
	_relleno_normal.set_corner_radius_all(3)
	_relleno_peligro = StyleBoxFlat.new()
	_relleno_peligro.bg_color = MAL
	_relleno_peligro.set_corner_radius_all(3)
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", _relleno_normal)


func esta_abierto() -> bool:
	return _abierto


func abrir(ruta: String, clave: String) -> void:
	if not FileAccess.file_exists(ruta):
		push_error("No existe el clasificador " + ruta)
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	if not (datos is Dictionary) or not (datos.get("documentos") is Array) \
			or not (datos.get("areas") is Array):
		push_error("El clasificador " + ruta + " no tiene la forma esperada.")
		return

	_datos = datos
	_clave = clave
	_documentos = datos["documentos"]
	_areas_json = datos["areas"]
	_segundos = float(datos.get("segundos_por_documento", 9.0))
	_i = 0
	_aciertos = 0
	_en_resultado = false
	_abierto = true
	_espera = IGNORAR_APERTURA
	# Si se cerro a mitad de un veredicto, el avance quedaba pendiente y al reabrir
	# se quedaba re-poniendo el mismo documento en bucle sin aceptar respuestas.
	_pendiente_avance = false
	veladura.visible = true

	_cabecera.text = str(datos.get("titulo", "Clasificador")).to_upper()
	_instrucciones.text = str(datos.get("instrucciones", ""))
	_veredicto.text = ""
	_montar_areas()
	_siguiente()


func _montar_areas() -> void:
	for c in _areas.get_children():
		c.queue_free()
	_botones = {}
	for a in _areas_json:
		var boton := Button.new()
		boton.text = str(a.get("texto", ""))
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boton.custom_minimum_size = Vector2(0, 72)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.focus_mode = Control.FOCUS_NONE
		boton.add_theme_font_size_override("font_size", 14)
		boton.add_theme_color_override("font_color", Color(0.9, 0.93, 0.97))
		boton.add_theme_stylebox_override("normal", _caja(FONDO_AREA))
		boton.add_theme_stylebox_override("hover", _caja(FONDO_AREA.lightened(0.12)))
		boton.add_theme_stylebox_override("pressed", _caja(FONDO_AREA.lightened(0.2)))
		var id := str(a.get("id", ""))
		boton.pressed.connect(_elegir.bind(id))
		_areas.add_child(boton)
		_botones[id] = boton


## Saca el siguiente documento por la cinta.
func _siguiente() -> void:
	if _i >= _documentos.size():
		_terminar()
		return
	var doc: Dictionary = _documentos[_i]
	_texto.text = str(doc.get("texto", ""))
	_pie.text = "documento %d de %d · %d bien · clic en el área o teclas [1-4]" % [
		_i + 1, _documentos.size(), _aciertos]
	_restante = _segundos
	_barra.value = 100.0
	_en_peligro = false
	_barra.add_theme_stylebox_override("fill", _relleno_normal)
	_barra.modulate.a = 1.0
	_veredicto.text = ""
	# Entra deslizando desde la derecha, como si viniera de la cinta. Se animan los
	# offsets y no `position` porque el documento esta anclado al centro: tocar
	# `position` a mano se pelea con las anclas y acaba descolocado al redimensionar.
	const DESPLAZAMIENTO := 240.0
	_documento.offset_left = -300.0 + DESPLAZAMIENTO
	_documento.offset_right = 300.0 + DESPLAZAMIENTO
	var tw := create_tween()
	tw.tween_property(_documento, "offset_left", -300.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_documento, "offset_right", 300.0, 0.3
		).set_trans(Tween.TRANS_SINE)
	_espera = IGNORAR_APERTURA


func _process(delta: float) -> void:
	if _espera > 0.0:
		_espera = maxf(_espera - delta, 0.0)
		# El veredicto dura un momento y entonces entra el documento siguiente. Se
		# hace aqui y no con un temporizador suelto para que al cerrar el minijuego a
		# media partida no quede nada disparando documentos a una cinta invisible.
		if _espera <= 0.0 and _pendiente_avance:
			_pendiente_avance = false
			_siguiente()
		return
	if not _abierto or _en_resultado:
		return
	_restante -= delta
	_barra.value = clampf(100.0 * _restante / maxf(_segundos, 0.1), 0.0, 100.0)
	# Aviso de urgencia: rojo y latido en los ultimos segundos.
	var peligro := _restante <= UMBRAL_PELIGRO
	if peligro != _en_peligro:
		_en_peligro = peligro
		_barra.add_theme_stylebox_override("fill",
			_relleno_peligro if peligro else _relleno_normal)
	_barra.modulate.a = (0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 110.0))
		if _en_peligro else 1.0)
	# Cuando se acaba el tiempo: el documento se cae de la cinta.
	if _restante <= 0.0:
		_responder("", true)


func _elegir(area: String) -> void:
	if not _abierto or _en_resultado or _espera > 0.0:
		return
	_responder(area, false)


func _responder(area: String, se_paso: bool) -> void:
	var doc: Dictionary = _documentos[_i]
	var correcta := str(doc.get("area", ""))
	var acierto := (not se_paso) and area == correcta
	if acierto:
		_aciertos += 1

	# Se marca el area que era la buena, y la que se pulso si fue otra.
	for id in _botones:
		var boton: Button = _botones[id]
		if id == correcta:
			boton.add_theme_stylebox_override("normal", _caja(FONDO_AREA_BUENA, BIEN))
		elif id == area:
			boton.add_theme_stylebox_override("normal", _caja(FONDO_AREA_MALA, MAL))

	if se_paso:
		_veredicto.text = "Se acabó el tiempo. Iba a: " + nombre_area(correcta)
		_veredicto.add_theme_color_override("font_color", MAL)
		_barra.value = 0.0
	elif acierto:
		_veredicto.text = "Bien: " + nombre_area(correcta)
		_veredicto.add_theme_color_override("font_color", BIEN)
	else:
		_veredicto.text = "No: iba a " + nombre_area(correcta)
		_veredicto.add_theme_color_override("font_color", MAL)

	_i += 1
	_espera = PAUSA_VEREDICTO
	_pendiente_avance = true


func nombre_area(id: String) -> String:
	for a in _areas_json:
		if str(a.get("id", "")) == id:
			return str(a.get("texto", id))
	return id


func _terminar() -> void:
	_en_resultado = true
	_abierto = true
	var total := _documentos.size()
	var nota := 100.0 * float(_aciertos) / float(maxi(total, 1))
	GameState.apuntar_puntaje(_clave, nota)

	_cabecera.text = str(_datos.get("titulo", "Clasificador")).to_upper() + " · resultado"
	_texto.text = "%d de %d en su área — %d%%" % [_aciertos, total, int(round(nota))]
	_barra.value = 100.0
	_veredicto.text = (str(_datos.get("explica_ok", "")) if nota >= GameState.NOTA_MINIMA
		else str(_datos.get("explica_mal", "")))
	_veredicto.add_theme_color_override("font_color", ORO)
	_pie.text = "ciérralo y vuelve a abrirlo para reintentarlo · [E] cerrar"
	terminada.emit(nota)


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	_pendiente_avance = false
	veladura.visible = false


# ------------------------------------------------------------------- la entrada

func _unhandled_input(evento: InputEvent) -> void:
	if not _abierto:
		return
	if evento.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("interactuar") and _en_resultado:
		cerrar()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and _espera <= 0.0 and not _en_resultado:
		var tecla := evento as InputEventKey
		if tecla.pressed and not tecla.echo:
			var n := tecla.keycode - KEY_1
			if n >= 0 and n < _areas_json.size():
				_elegir(str((_areas_json[n] as Dictionary).get("id", "")))
				get_viewport().set_input_as_handled()


func _caja(fondo: Color, borde := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	if borde.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = borde
	s.set_corner_radius_all(5)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s
