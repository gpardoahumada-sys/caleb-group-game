extends CanvasLayer

## EL MOTOR DE ARRASTRAR. Uno solo para tres minijuegos del edificio.
##
## Lo usan el Mapa de Aliados (perfiles al rol que les toca), el Clasificador de
## Dolores (quejas al area correcta) y el Constructor de Propuestas (que modulos
## entran en la propuesta). Por eso no hay tres minijuegos escritos, sino uno con
## tres ficheros de datos.
##
## Sirve para DOS formas de pensar, y la diferencia esta en los datos:
##
##   - ASIGNAR: cada pieza lleva "destino" con el id del hueco que le toca. Es el
##     organigrama: Preventa va con "arma la propuesta", y nada mas.
##   - ELEGIR: las piezas llevan "correcta": true/false y los huecos son anonimos.
##     Es el constructor de propuestas: los tres modulos que sirven, en el orden que
##     quieras.
##
## La nota es aciertos entre huecos. No se penalizan los fallos por separado: con
## seis piezas y tres huecos, acertar dos de tres ya es un 66 y no llega al 80, que
## es justo lo que se pide.

signal terminada(nota: float)

## Lo que se ignora la E de la apertura, para que la misma pulsacion que abre el
## minijuego no lo cierre en el primer fotograma.
const IGNORAR_APERTURA := 0.2

const FONDO_PIEZA := Color(0.16, 0.21, 0.27)
const FONDO_HUECO := Color(0.10, 0.13, 0.17)
const BIEN := Color(0.35, 0.72, 0.45)
const MAL := Color(0.80, 0.36, 0.34)
const ORO := Color(0.83, 0.635, 0.29)


## UNA PIEZA que se coge con el raton. Se usa el sistema de arrastrar del propio
## motor (get_drag_data / can_drop_data) en vez de mover el nodo a mano: asi el
## arrastre se dibuja, se cancela con Esc y no se queda pegado si el raton sale de
## la ventana, que es lo que pasa cuando se hace a mano.
class Pieza extends PanelContainer:
	var id := ""
	var texto := ""

	func _get_drag_data(_pos: Vector2):
		var vista := Label.new()
		vista.text = texto
		vista.add_theme_font_size_override("font_size", 15)
		set_drag_preview(vista)
		return {"pieza": id}


## UN HUECO donde soltar. Es anonimo: lo que decide si esta bien es la pieza, no el
## hueco, porque en el constructor de propuestas los tres modulos buenos caben en
## cualquiera de los tres sitios.
class Hueco extends PanelContainer:
	var numero := 0
	signal soltada(hueco, datos)

	func _can_drop_data(_pos: Vector2, datos) -> bool:
		return datos is Dictionary and datos.has("pieza") and get_child_count() == 1

	func _drop_data(_pos: Vector2, datos) -> void:
		soltada.emit(self, datos)


@onready var veladura: Control = $Veladura
@onready var _cabecera: Label = $Veladura/Marco/Margen/Columnas/Cabecera
@onready var _instrucciones: Label = $Veladura/Marco/Margen/Columnas/Instrucciones
@onready var _izquierda: VBoxContainer = $Veladura/Marco/Margen/Columnas/Cuerpo/Izquierda
@onready var _derecha: VBoxContainer = $Veladura/Marco/Margen/Columnas/Cuerpo/Derecha
@onready var _explicacion: Label = $Veladura/Marco/Margen/Columnas/Explicacion
@onready var _pie: Label = $Veladura/Marco/Margen/Columnas/Pie

var _datos := {}
var _clave := ""
var _piezas := {}          # id -> Dictionary del JSON
var _colocadas := {}       # numero de hueco -> id de pieza
var _huecos: Array = []    # los nodos Hueco, en orden
var _abierto := false
var _espera := 0.0
var _en_resultado := false


func _ready() -> void:
	add_to_group("arrastrar")
	veladura.visible = false


func esta_abierto() -> bool:
	return _abierto


func abrir(ruta: String, clave: String) -> void:
	if not FileAccess.file_exists(ruta):
		push_error("No existe el minijuego " + ruta)
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	if not (datos is Dictionary) or not (datos.get("piezas") is Array) \
			or not (datos.get("huecos") is Array):
		push_error("El minijuego " + ruta + " no tiene la forma esperada.")
		return

	_datos = datos
	_clave = clave
	_piezas = {}
	_colocadas = {}
	_huecos = []
	_en_resultado = false
	_abierto = true
	_espera = IGNORAR_APERTURA
	veladura.visible = true
	_montar()


func _montar() -> void:
	for c in _izquierda.get_children():
		c.queue_free()
	for c in _derecha.get_children():
		c.queue_free()

	_cabecera.text = str(_datos.get("titulo", "Minijuego")).to_upper()
	_instrucciones.text = str(_datos.get("instrucciones", ""))
	_explicacion.text = ""
	_explicacion.visible = false
	_pie.text = "arrastra cada pieza a su sitio · [Esc] salir"

	_izquierda.add_child(_rotulo(str(_datos.get("izquierda", "Piezas"))))
	for p in _datos["piezas"]:
		var pieza := Pieza.new()
		pieza.id = str(p.get("id", ""))
		pieza.texto = str(p.get("texto", ""))
		pieza.add_theme_stylebox_override("panel", _caja(FONDO_PIEZA))
		pieza.custom_minimum_size = Vector2(0, 46)
		var etiqueta := Label.new()
		etiqueta.text = pieza.texto
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.add_theme_font_size_override("font_size", 14)
		etiqueta.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95))
		pieza.add_child(etiqueta)
		_izquierda.add_child(pieza)
		_piezas[pieza.id] = p

	_derecha.add_child(_rotulo(str(_datos.get("derecha", "Propuesta"))))
	for i in range(_datos["huecos"].size()):
		var hueco := Hueco.new()
		hueco.numero = i
		hueco.add_theme_stylebox_override("panel", _caja(FONDO_HUECO, ORO.darkened(0.35)))
		hueco.custom_minimum_size = Vector2(0, 52)
		var dentro := Label.new()
		dentro.name = "Dentro"
		# Si el hueco trae su propio texto se enseña: en el Mapa de Aliados el jugador
		# tiene que leer QUE puesto es para saber a quién arrastra. Si no trae texto
		# -el constructor de propuestas, con tres huecos iguales- se numera.
		var rotulo := str(_datos["huecos"][i].get("texto", ""))
		dentro.text = rotulo if rotulo != "" else "  %d  ·  arrastra aquí" % (i + 1)
		dentro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dentro.add_theme_font_size_override("font_size", 14)
		dentro.add_theme_color_override("font_color", Color(0.52, 0.58, 0.66))
		hueco.add_child(dentro)
		hueco.soltada.connect(_al_soltar)
		_derecha.add_child(hueco)
		_huecos.append(hueco)


func _rotulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", ORO)
	return l


func _al_soltar(hueco, datos) -> void:
	if _en_resultado:
		return
	var id := str(datos.get("pieza", ""))
	if not _piezas.has(id):
		return

	# La pieza se va de la lista de la izquierda: una pieza no puede estar en dos
	# sitios, y dejarla alli permitiria colocarla otra vez y falsear la nota.
	for p in _izquierda.get_children():
		if p is Pieza and p.id == id:
			p.queue_free()
			break

	_colocadas[hueco.numero] = id
	var dentro := hueco.get_node_or_null("Dentro") as Label
	if dentro != null:
		dentro.text = str(_piezas[id].get("texto", ""))
		dentro.add_theme_color_override("font_color", Color(0.9, 0.93, 0.97))
		hueco.add_theme_stylebox_override("panel", _caja(FONDO_PIEZA, ORO))

	if _colocadas.size() == _huecos.size():
		_terminar()


func _terminar() -> void:
	_en_resultado = true
	var aciertos := 0
	for numero in _colocadas:
		var pieza: Dictionary = _piezas[_colocadas[numero]]
		var correcta: bool
		if pieza.has("correcta"):
			correcta = bool(pieza["correcta"])
		else:
			correcta = str(pieza.get("destino", "")) == str(
				_datos["huecos"][int(numero)].get("id", ""))
		if correcta:
			aciertos += 1
		var hueco: Node = _huecos[int(numero)]
		hueco.add_theme_stylebox_override("panel",
			_caja(FONDO_PIEZA, BIEN if correcta else MAL))

	var total := _huecos.size()
	var nota := 100.0 * float(aciertos) / float(total)
	GameState.apuntar_puntaje(_clave, nota)

	_cabecera.text = str(_datos.get("titulo", "Minijuego")).to_upper() + " · resultado"
	_explicacion.text = "%d de %d en su sitio — %d%%.  %s" % [
		aciertos, total, int(round(nota)),
		str(_datos.get("explica_ok", "")) if nota >= GameState.NOTA_MINIMA
		else str(_datos.get("explica_mal", ""))]
	_explicacion.visible = _explicacion.text != ""
	_pie.text = "ciérralo y vuelve a abrirlo para reintentarlo · [E] cerrar"
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
	if evento.is_action_pressed("interactuar") and _en_resultado:
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
