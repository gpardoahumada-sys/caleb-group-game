extends CanvasLayer

## EL PANEL DE INFORMACION.
##
## Una sola ventana para todo el juego: la pantalla del auditorio, el mostrador, los
## carteles y los avisos de puerta la usan tal cual. Por eso el texto llega siempre
## de fuera (del JSON del piso) y aqui no hay ni una linea de contenido.
##
## Se cierra con E o Escape. La espera de IGNORAR_APERTURA existe porque la MISMA
## pulsacion de E que abre el panel llegaria a este _unhandled_input en el mismo
## fotograma y lo cerraria en el acto: el jugador veria un parpadeo y nada mas.

signal cerrado

const IGNORAR_APERTURA := 0.18

@onready var veladura: Control = $Veladura
@onready var marco: PanelContainer = $Veladura/Marco
@onready var _titulo: Label = $Veladura/Marco/Margen/Columnas/Titulo
@onready var _cuerpo: RichTextLabel = $Veladura/Marco/Margen/Columnas/Cuerpo
@onready var _mas: Label = $Veladura/Marco/Margen/Columnas/Mas
@onready var _pie: Label = $Veladura/Marco/Margen/Columnas/Pie

var _abierto := false
var _espera := 0.0


func _ready() -> void:
	add_to_group("panel_info")
	veladura.visible = false


func esta_abierto() -> bool:
	return _abierto


func abrir(titulo: String, cuerpo: String) -> void:
	_titulo.text = titulo
	_cuerpo.text = cuerpo
	# Se vuelve al principio del texto: si no, el segundo cartel que leas empieza
	# por donde se quedo el primero.
	_cuerpo.scroll_to_line(0)
	veladura.visible = true
	_abierto = true
	_espera = IGNORAR_APERTURA
	_ajustar_alto.call_deferred()


## El panel se ajusta al texto que lleva dentro.
##
## La caja NO tiene alto fijo: las anclas la dejan crecer desde el centro, y el
## cuerpo tiene fit_content, asi que el PanelContainer mide el contenido y se
## ajusta solo. Con el alto fijado a mano, un saludo de cinco lineas salia en una
## caja de 552 px con dos tercios vacios, y parecia que faltaba contenido.
##
## Lo unico que hay que hacer aqui es el TOPE: si el texto es muy largo, el panel se
## comeria la pantalla. Pasadas LINEAS_MAX se deja de ajustar al contenido y se
## corta a esas lineas, que es cuando aparecen la barra de scroll y el aviso de
## "hay mas".
const LINEAS_MAX := 24
## Alto de una linea a 14 px. Solo se usa para el tope: el alto normal lo calcula
## el contenedor con fit_content.
const ALTO_LINEA := 19.5

func _ajustar_alto() -> void:
	if not _abierto:
		return
	var lineas := _cuerpo.get_line_count()
	if lineas > LINEAS_MAX:
		# No existe max_lines_visible en RichTextLabel: el tope se pone como altura
		# minima de la etiqueta. Con fit_content apagado, la etiqueta se queda en esa
		# altura y el texto de mas sigue ahi, detras de la barra de scroll.
		_cuerpo.fit_content = false
		_cuerpo.custom_minimum_size = Vector2(0, float(LINEAS_MAX) * ALTO_LINEA)
		_cuerpo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		_cuerpo.fit_content = true
		_cuerpo.custom_minimum_size = Vector2.ZERO
		_cuerpo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	veladura.visible = false
	cerrado.emit()


func _process(delta: float) -> void:
	if _espera > 0.0:
		_espera = maxf(_espera - delta, 0.0)
	# Aviso de que hay mas texto abajo. La barra de scroll sola no basta: en un
	# cartel largo, quien no mira a la derecha se queda sin leer el final y cree que
	# el texto esta cortado.
	var barra := _cuerpo.get_v_scroll_bar()
	_mas.visible = _abierto and barra.max_value > barra.page \
		and barra.value < barra.max_value - barra.page


func _unhandled_input(evento: InputEvent) -> void:
	if not _abierto or _espera > 0.0:
		return
	if evento.is_action_pressed("interactuar") or evento.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
