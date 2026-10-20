extends Node2D

## UN PEATON DE LA CIUDAD.
##
## Reutiliza las hojas de personaje de la torre (7x5, la fila 0 es caminar hacia
## abajo), asi que la gente de la calle es la misma gente del edificio: mismo estilo,
## cero arte nuevo.
##
## Camina de un punto a otro de la acera, se para un momento al llegar y vuelve. Ese
## "se para" es lo que hace que la calle no parezca una cinta de gente.

const VELOCIDAD := 46.0
const PAUSA := 1.6
const CELDAS_ANCHO := 7
const CELDAS_ALTO := 5
const FOTOGRAMAS_CAMINAR := 7

var ruta: Array = []
var _indice := 0
var _espera := 0.0
var _tiempo := 0.0
var _fila := 0

@onready var _dib: Sprite2D = $Dibujo


func _ready() -> void:
	_dib.hframes = CELDAS_ANCHO
	_dib.vframes = CELDAS_ALTO
	_dib.frame = 1


func _process(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		return
	if ruta.is_empty():
		return
	var objetivo: Vector2 = ruta[_indice % ruta.size()]
	var hacia := objetivo - position
	if hacia.length() < 8.0:
		_indice += 1
		_espera = PAUSA
		return

	position += hacia.normalized() * VELOCIDAD * delta
	# La fila del dibujo segun hacia donde va: 0 abajo, 1 arriba, 2 izquierda, 3 derecha.
	if absf(hacia.x) > absf(hacia.y):
		_fila = 3 if hacia.x > 0 else 2
	else:
		_fila = 0 if hacia.y > 0 else 1

	# El ciclo de andar, en la fila que toque.
	_tiempo += delta
	var paso := int(_tiempo * 9.0) % FOTOGRAMAS_CAMINAR
	_dib.frame_coords = Vector2i(paso, _fila)
