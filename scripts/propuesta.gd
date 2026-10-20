extends CanvasLayer

## EL CONSTRUCTOR DE PROPUESTAS.
##
## Un brief ficticio y siete modulos de servicio: hay que quedarse con TRES. La gracia
## no esta en acertar los tres, esta en que se puede elegir de mas o de menos, que son
## justo los dos errores que pide evitar el documento:
##
##   - cuatro o mas  -> propuesta SOBREDIMENSIONADA: el cliente se asusta y el precio
##                      se va antes de haber demostrado nada;
##   - uno o dos     -> FALTA DE ALCANCE: no hay con que cumplir lo prometido.
##
## Por eso no usa el motor de arrastrar: alli tres huecos obligan a soltar tres piezas,
## y con esa forma los dos errores son imposibles de cometer. Aqui se elige libremente
## y el jugador se puede equivocar de las dos maneras.
##
## Nota = 100 * (aciertos - sobrantes) / 3. Un modulo de mas cuesta lo mismo que uno
## que falta, porque las dos cosas arruinan la propuesta igual.

signal terminada(nota: float)

const MAXIMO := 3
const ORO := Color(0.83, 0.635, 0.29)
const BIEN := Color(0.35, 0.72, 0.45)
const MAL := Color(0.80, 0.36, 0.34)
const FONDO_TARJETA := Color(0.15, 0.20, 0.26)
const FONDO_ELEGIDA := Color(0.26, 0.21, 0.11)
const TEXTO := Color(0.88, 0.91, 0.95)
const TEXTO_TENUE := Color(0.72, 0.77, 0.84)

@onready var veladura: Control = $Veladura
@onready var _cabecera: Label = $Veladura/Marco/Margen/Columnas/Cabecera
@onready var _brief: Label = $Veladura/Marco/Margen/Columnas/Brief
@onready var _rejilla: GridContainer = $Veladura/Marco/Margen/Columnas/Rejilla
@onready var _contador: Label = $Veladura/Marco/Margen/Columnas/Contador
@onready var _boton: Button = $Veladura/Marco/Margen/Columnas/Pie/Boton
@onready var _veredicto: Label = $Veladura/Marco/Margen/Columnas/Veredicto
@onready var _pie: Label = $Veladura/Marco/Margen/Columnas/Pie/Ayuda

var _datos := {}
var _clave := ""
var _modulos: Array = []
var _botones: Array = []
var _abierto := false
var _enviado := false
## Nota de la ULTIMA partida, aunque sea peor que la guardada: el progreso se queda
## con la mejor, asi que sin esto no hay forma de saber como fue el ultimo intento.
var ultima_nota := -1.0


func _ready() -> void:
	add_to_group("propuesta")
	veladura.visible = false
	_boton.pressed.connect(_enviar)
	_estilo_boton(_boton, ORO)


func esta_abierto() -> bool:
	return _abierto


func abrir(ruta: String, clave: String) -> void:
	if not FileAccess.file_exists(ruta):
		push_error("No existe la propuesta " + ruta)
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	if not (datos is Dictionary) or not (datos.get("modulos") is Array) \
			or (datos["modulos"] as Array).size() < 4:
		push_error("La propuesta " + ruta + " no tiene la forma esperada.")
		return

	_datos = datos
	_clave = clave
	_modulos = datos["modulos"]
	_abierto = true
	_enviado = false
	veladura.visible = true

	_cabecera.text = str(datos.get("titulo", "Propuesta")).to_upper()
	_brief.text = str(datos.get("instrucciones", ""))
	_veredicto.text = ""
	_boton.disabled = false
	_montar()
	_actualizar_contador()


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	veladura.visible = false


func _montar() -> void:
	for c in _rejilla.get_children():
		c.queue_free()
	_botones = []
	for m in _modulos:
		var b := Button.new()
		b.toggle_mode = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = str(m.get("texto", ""))
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", TEXTO)
		b.add_theme_color_override("font_pressed_color", ORO)
		b.add_theme_color_override("font_disabled_color", TEXTO)
		b.add_theme_stylebox_override("normal", _caja(FONDO_TARJETA))
		b.add_theme_stylebox_override("hover",
			_caja(FONDO_TARJETA.lightened(0.10), ORO.darkened(0.45)))
		b.add_theme_stylebox_override("pressed", _caja(FONDO_ELEGIDA, ORO))
		b.toggled.connect(_actualizar_contador)
		_rejilla.add_child(b)
		_botones.append(b)


func _elegidos() -> Array:
	var salida: Array = []
	for i in _botones.size():
		if bool((_botones[i] as Button).button_pressed):
			salida.append(i)
	return salida


## El contador dice en que lado del error esta el jugador antes de enviar: sin esto,
## el que se pasa de modulos no lo sabe hasta que ya perdio la nota.
func _actualizar_contador(_x := false) -> void:
	if _enviado or not _abierto:
		return
	var n := _elegidos().size()
	var aviso := "  · falta alcance" if n < MAXIMO else (
		"" if n == MAXIMO else "  · sobredimensionada")
	_contador.text = "%d de %d módulos elegidos%s" % [n, MAXIMO, aviso]
	_contador.add_theme_color_override("font_color", ORO if n == MAXIMO else TEXTO_TENUE)


func _enviar() -> void:
	if _enviado:
		return
	_enviado = true
	var elegidos := _elegidos()

	var aciertos := 0
	var sobrantes := 0
	var faltan := 0
	for i in _modulos.size():
		var debe := bool((_modulos[i] as Dictionary).get("correcto", false))
		var puesto := elegidos.has(i)
		if debe and puesto:
			aciertos += 1
		elif debe and not puesto:
			faltan += 1
		elif puesto and not debe:
			sobrantes += 1

	# Cada tarjeta se queda marcada: verde las que hacian falta, rojo las que sobran.
	for i in _botones.size():
		var b: Button = _botones[i]
		var debe := bool((_modulos[i] as Dictionary).get("correcto", false))
		b.disabled = true
		if debe:
			b.add_theme_stylebox_override("disabled", _caja(Color(0.17, 0.31, 0.21), BIEN))
		elif elegidos.has(i):
			b.add_theme_stylebox_override("disabled", _caja(Color(0.31, 0.17, 0.17), MAL))
		else:
			b.add_theme_stylebox_override("disabled", _caja(FONDO_TARJETA.darkened(0.3)))

	var nota := clampf(100.0 * float(aciertos - sobrantes) / float(MAXIMO), 0.0, 100.0)
	ultima_nota = nota
	GameState.apuntar_puntaje(_clave, nota)

	var lineas: Array = []
	lineas.append("Elegiste %d módulos: %d de los 3 que hacen falta. Nota: %d%%." % [
		elegidos.size(), aciertos, int(round(nota))])
	if faltan > 0:
		lineas.append("Falta alcance: %d módulo(s) imprescindible(s) se quedaron fuera." % faltan)
	if sobrantes > 0:
		lineas.append("Sobredimensionada: %d módulo(s) que el brief no pide." % sobrantes)
	if aciertos == MAXIMO and sobrantes == 0:
		lineas.clear()
		lineas.append("Propuesta equilibrada: ni un módulo de más, ni uno de menos.")
	lineas.append(str(_datos.get("explica_ok", "") if nota >= GameState.NOTA_MINIMA
		else _datos.get("explica_mal", "")))

	_veredicto.text = "\n".join(lineas)
	_veredicto.add_theme_color_override("font_color", BIEN if nota >= GameState.NOTA_MINIMA else MAL)
	_boton.disabled = true
	_pie.text = "[E] cerrar y vuelve a abrirlo para intentarlo otra vez"
	terminada.emit(nota)


func _unhandled_input(evento: InputEvent) -> void:
	if not _abierto:
		return
	if evento.is_action_pressed("ui_cancel") or (
			_enviado and evento.is_action_pressed("interactuar")):
		cerrar()
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


func _estilo_boton(b: Button, color: Color) -> void:
	var base := _caja(color.darkened(0.55), color)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", _caja(color.darkened(0.42), color))
	b.add_theme_stylebox_override("pressed", _caja(color.darkened(0.65), color))
	b.add_theme_color_override("font_color", color.lightened(0.25))
	b.add_theme_color_override("font_hover_color", color.lightened(0.45))
