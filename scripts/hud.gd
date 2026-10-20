extends CanvasLayer

## EL HUD DEL COMERCIAL.
##
## Solo tres cosas, y las tres son informacion de estado, no de adorno:
##   - en que piso estas y cuantas insignias llevas,
##   - que tienes delante y con que tecla ([E] Revisar),
##   - el aviso de insignia nueva, que sale tres segundos y se va.
##
## Escucha GameState.insignia_obtenida en vez de que las puertas y los paneles le
## avisen a mano: asi el que concede una insignia no tiene que saber que existe
## un HUD.

@onready var _titulo: Label = $Cinta/Titulo
@onready var _insignias: Label = $Cinta/Insignias
@onready var _llave: Label = $Cinta/Llave
@onready var _objetivo: Label = $Cinta/Objetivo
@onready var _prompt: Label = $Prompt
@onready var _aviso: Label = $CapaAviso/Aviso

var _tween: Tween = null
## Que insignia se juega en este piso y que se pone en el objetivo cuando ya la
## tienes. Las dos cosas llegan del plano (data/oficina_XX.json), no del codigo: el
## texto de un juego de formacion se retoca mucho.
var _insignia := ""
var _hecho := ""
## Objetivo literal, para escenas que no van por insignias (la ciudad). Si viene
## vacio, el objetivo se calcula con la tabla de pisos como siempre.
var _objetivo_libre := ""


func _ready() -> void:
	_prompt.text = ""
	_aviso.modulate.a = 0.0
	GameState.insignia_obtenida.connect(_al_ganar_insignia)
	GameState.objeto_obtenido.connect(_al_objeto)
	GameState.lectura_apuntada.connect(_al_leer)
	GameState.progreso_reiniciado.connect(_refrescar_todo)
	_refrescar_insignias()
	_refrescar_objetivo()


## Al empezar de cero cambian las dos cosas a la vez: el contador y el objetivo.
func _refrescar_todo() -> void:
	_refrescar_insignias()
	_refrescar_objetivo()


## El nombre del piso, arriba a la izquierda, y lo que hay que hacer en el.
func configurar(nombre: String, insignia := "", hecho := "", objetivo_libre := "") -> void:
	_titulo.text = nombre.to_upper()
	_insignia = insignia
	_hecho = hecho
	_objetivo_libre = objetivo_libre
	_refrescar_insignias()
	_refrescar_objetivo()


## Lo que hay delante: "[E] Revisar". Cadena vacia = no hay nada.
func aviso(texto: String) -> void:
	_prompt.text = texto


func _refrescar_insignias() -> void:
	_insignias.text = "INSIGNIAS  %d" % GameState.cuantas_insignias()
	# La llave no es una insignia mas: es el objeto que te entrega el comite, y se
	# queda a la vista porque es lo que abre la calle.
	_llave.text = ("LLAVE DEL AUTO  ✓" if GameState.tiene_objeto("llave_auto") else "")


## La linea de objetivo: que te falta, en palabras, siempre a la vista. En un juego
## de formacion esto no es un adorno, es lo que evita que el jugador se quede
## dando vueltas sin saber que se espera de el.
func _refrescar_objetivo() -> void:
	if _objetivo_libre != "":
		_objetivo.text = "OBJETIVO · " + _objetivo_libre
		return
	if _insignia == "":
		_objetivo.text = ""
		return
	if GameState.tiene_insignia(_insignia):
		_objetivo.text = "OBJETIVO · " + (_hecho if _hecho != "" else "piso completado")
		return
	var que := GameState.objetivo_texto(_insignia)
	if que == "":
		_objetivo.text = ""
	else:
		_objetivo.text = "OBJETIVO · " + que


func _al_leer(_id: String) -> void:
	_refrescar_objetivo()


## La llave aparece en el HUD en cuanto el comite la entrega, sin esperar a la
## siguiente insignia.
func _al_objeto(_id: String) -> void:
	_refrescar_insignias()


func _al_ganar_insignia(id: String) -> void:
	_refrescar_insignias()
	_refrescar_objetivo()
	_aviso.text = NOMBRES.get(id, id.to_upper())
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_aviso.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_aviso, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(2.4)
	_tween.tween_property(_aviso, "modulate:a", 0.0, 0.7)


const NOMBRES := {
	"identidad": "INSIGNIA DE IDENTIDAD CALEB GROUP",
	"catalogo": "CATALOGO COMERCIAL DE BOLSILLO",
	"casos": "PORTAFOLIO DE CASOS DE EXITO",
	"acreditacion": "ACREDITACION COMERCIAL DE TERRENO",
}
