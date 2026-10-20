extends Node2D

## UN COCHE DEL TRAFICO.
##
## Da vueltas a una manzana siguiendo una lista de puntos, y se para si el semaforo de
## su eje esta en rojo y le queda cerca. Nada mas: no hay IA de trafico, porque en una
## ciudad que se ve a vista de pajaro lo que se nota es que los coches circulan por su
## carril y respetan el semaforo, no que esquiven baches.
##
## La vuelta a la manzana va en sentido horario y desplazada a la derecha del eje de la
## calle: es lo que hace que vayan por SU carril.

const VELOCIDAD := 150.0
const FRENADA := 320.0
const ACELERACION := 190.0
## A esta distancia del cruce, si el semaforo esta en rojo, empieza a frenar.
const DISTANCIA_SEMAFORO := 165.0

## Puntos de la vuelta, en orden. Los pone ciudad.gd al montar el trafico.
var ruta: Array = []
var semaforos: Array = []
var velocidad := VELOCIDAD
var _indice := 0
## Se apaga si el juego esta en pausa o en un panel; el trafico se congela con el resto.
var activo := true


func _process(delta: float) -> void:
	if ruta.is_empty():
		return
	var objetivo: Vector2 = ruta[_indice % ruta.size()]
	var hacia := objetivo - global_position
	if hacia.length() < 14.0:
		_indice += 1
		return

	var deseada := VELOCIDAD
	if _semaforo_en_rojo_delante(hacia) and hacia.length() < DISTANCIA_SEMAFORO:
		deseada = 0.0

	if deseada > velocidad:
		velocidad = minf(velocidad + ACELERACION * delta, deseada)
	else:
		velocidad = maxf(velocidad - FRENADA * delta, deseada)

	if not activo or velocidad <= 0.5:
		return
	var paso := minf(velocidad * delta, hacia.length())
	global_position += hacia.normalized() * paso
	# El dibujo mira hacia arriba: se le suma 90 grados para que apunte al sentido de
	# la marcha.
	rotation = hacia.angle() + PI / 2.0


## ¿Hay un semaforo de mi eje, en rojo, delante de mi?
func _semaforo_en_rojo_delante(hacia: Vector2) -> bool:
	var horizontal := absf(hacia.x) > absf(hacia.y)
	for s in semaforos:
		if not (s is Dictionary):
			continue
		var eje := str(s.get("eje", ""))
		if (eje == "h") != horizontal:
			continue
		var pos: Vector2 = s.get("pos", Vector2.ZERO)
		var distancia := pos - global_position
		# Solo cuenta el que esta delante y en mi carril.
		if distancia.dot(hacia) <= 0.0:
			continue
		if distancia.length() > DISTANCIA_SEMAFORO:
			continue
		if str(s.get("estado", "verde")) != "verde":
			return true
	return false
