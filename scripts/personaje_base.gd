extends CharacterBody2D

## LO QUE COMPARTEN EL JUGADOR Y LA GENTE DE LA OFICINA.
##
## La hoja viene del pack de Andreas y la monta tools/andreas.py: 5 filas de 7
## columnas de 16x32 -abajo, arriba, izquierda, derecha y reposo-. El jugador y los
## companeros la dibujan igual porque, si cada uno tuviera su copia de esta cuenta,
## en cuanto se tocara una el otro seguiria andando con la fila de antes. No da
## error: se ve mal, que es peor.
##
## Lo unico que cambia entre los dos es a que velocidad se pasan los frames y quien
## decide hacia donde mira.

const COLUMNAS := 7
const FILA_REPOSO := 4
const FRAMES_REPOSO := 4

## Frames de caminar por segundo.
var fps_paso := 11.0
## Frames de la respiracion parado, de frente.
var fps_reposo := 3.0

var _reloj := 0.0


## Pinta la hoja. `mirando` es la direccion (no hace falta normalizada) y `ratio`
## lo que se esta moviendo, de 0 a 1: por debajo de 0.1 se considera quieto.
func pintar(mirando: Vector2, ratio: float, delta: float) -> void:
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	_reloj += delta
	if ratio > 0.1:
		sprite.frame = fila_de(mirando) * COLUMNAS + (int(_reloj * fps_paso) % COLUMNAS)
	elif mirando.y > 0.0 and absf(mirando.x) < 0.5:
		# Parado y de frente: respira. Es la unica direccion que el pack trae con
		# animacion de reposo; de lado o de espaldas se queda en su primera pose,
		# que ya es una pose quieta.
		sprite.frame = FILA_REPOSO * COLUMNAS + (int(_reloj * fps_reposo) % FRAMES_REPOSO)
	else:
		sprite.frame = fila_de(mirando) * COLUMNAS


## Fila de la hoja: 0 abajo, 1 arriba, 2 izquierda, 3 derecha. Manda el eje en el
## que mas se mueve, para que en diagonal no tiemble entre dos filas.
static func fila_de(v: Vector2) -> int:
	if absf(v.x) >= absf(v.y):
		return 3 if v.x > 0.0 else 2
	return 0 if v.y > 0.0 else 1
