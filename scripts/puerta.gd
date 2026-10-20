extends Area2D

## UNA PUERTA CON REQUISITO: el ascensor y la salida a la calle.
##
## No se abre ni se cierra: lo unico que hace es CONTAR. Si tienes la insignia te
## dice a donde lleva; si no, te dice que te falta. El cambio real de escena lo
## pondra el piso siguiente en el hito 5, cuando exista a donde ir.
##
## El texto bloqueado admite "{faltan}", que se cambia por la lista de lo que te
## queda por consultar. Asi el cartel no hay que reescribirlo cuando se anada un
## requisito nuevo a GameState.REQUISITOS_IDENTIDAD.

var id := ""
var titulo := ""
## Insignia que hace falta para pasar.
var insignia := ""
var texto_bloqueado := ""
var texto_abierto := ""
var verbo := "Abrir"
## La escena a la que lleva esta puerta cuando la abres. Vacio = la puerta solo
## cuenta a donde iria, que es lo que hace mientras el piso de arriba no existe.
var ir_a := ""


func prompt() -> String:
	if insignia == "" or GameState.tiene_insignia(insignia):
		return "[E] " + verbo
	return "[E] Probar"


func interactuar(jugador: Node) -> void:
	# Una puerta sin insignia esta siempre abierta: es la del ascensor que baja, que
	# no tiene por que pedir nada. Sin esta salida, esa puerta quedaria cerrada para
	# siempre, porque tiene_insignia("") siempre es falso.
	if insignia == "" or GameState.tiene_insignia(insignia):
		# Con la insignia y una escena a la que ir, la puerta no cuenta nada: ABRE.
		# El texto de "abierta" se queda para cuando no hay a donde ir todavia -el
		# piso de arriba sin construir-, y entonces la puerta lo explica en vez de
		# dejar al jugador mirando una pantalla que no hace nada.
		if ir_a != "" and ResourceLoader.exists(ir_a):
			get_tree().change_scene_to_file(ir_a)
			return
		jugador.call("abrir_panel", titulo, texto_abierto)
		return

	var cuerpo := texto_bloqueado
	if cuerpo.contains("{faltan}"):
		cuerpo = cuerpo.replace("{faltan}", GameState.faltan_texto(insignia))
	jugador.call("abrir_panel", titulo, cuerpo)


# ------------------------------------------------------- como se ve la puerta
#
# El estado se VE en el mundo: cerrada va apagada y gris, y en cuanto consigues la
# insignia se enciende. Es la diferencia entre un cartel que hay que ir a leer y
# saber de un vistazo que el ascensor ya te deja pasar.

## Cuanto se apaga el dibujo mientras la puerta esta cerrada.
const APAGADA := Color(0.74, 0.77, 0.82)

## El color de reposo: blanco si ya la tienes, APAGADA si no.
var _base := Color.WHITE


func _ready() -> void:
	# Se escucha la insignia en vez de preguntar cada fotograma: la puerta se
	# enciende en el mismo instante en que la ganas, aunque estes al otro lado del
	# piso.
	GameState.insignia_obtenida.connect(_al_ganar_insignia)
	_refrescar_estado()


func _al_ganar_insignia(_id: String) -> void:
	_refrescar_estado()


func _refrescar_estado() -> void:
	_base = Color.WHITE if (insignia == "" or GameState.tiene_insignia(insignia)) else APAGADA
	var dib := _dibujo()
	if dib != null:
		dib.modulate = _base


## Lo llama el jugador cuando la puerta pasa a ser -o deja de ser- lo que tiene
## delante: se aclara un poco para que se vea que responde a la E.
func destacar(activo: bool) -> void:
	var dib := _dibujo()
	if dib == null:
		return
	dib.modulate = _base.lightened(0.3) if activo else _base


func _dibujo() -> Sprite2D:
	return get_parent().get_node_or_null("Dibujo") as Sprite2D
