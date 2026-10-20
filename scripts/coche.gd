extends CharacterBody2D

## EL COCHE DEL JUGADOR.
##
## No anda: conduce. Hay aceleracion, frenada, inercia y un volante que solo gira si
## el coche se mueve, que es lo que hace que se sienta un coche y no un personaje con
## una piel de coche.
##
## Los ejes son los de siempre (mover_arriba/abajo/izquierda/derecha), asi que se
## conduce con las mismas teclas con las que se anda en la torre: el jugador no tiene
## que aprender dos controles para el mismo juego.
##
## El dibujo apunta HACIA ARRIBA y `rotation = 0` en Godot es el eje -Y, asi que el
## nodo y el sprite coinciden sin correcciones.

const ACELERACION := 340.0
const FRENO := 520.0
const ROZAMIENTO := 190.0
const VELOCIDAD_MAX := 430.0
const MARCHA_ATRAS := -150.0
const GIRO := 2.5
## Por debajo de esta velocidad el volante no gira: un coche parado no gira sobre si
## mismo, y sin esto se podia girar en el sitio como un tanque.
const VELOCIDAD_MINIMA_GIRO := 26.0

var velocidad := 0.0
## Se apaga mientras hay un panel abierto, para no seguir rodando por detras.
var puede_conducir := true


func _physics_process(delta: float) -> void:
	var acelera := puede_conducir and Input.is_action_pressed("mover_arriba")
	var frena := puede_conducir and Input.is_action_pressed("mover_abajo")
	var izquierda := puede_conducir and Input.is_action_pressed("mover_izquierda")
	var derecha := puede_conducir and Input.is_action_pressed("mover_derecha")

	if acelera:
		velocidad = minf(velocidad + ACELERACION * delta, VELOCIDAD_MAX)
	elif frena:
		velocidad = maxf(velocidad - FRENO * delta, MARCHA_ATRAS)
	else:
		velocidad = move_toward(velocidad, 0.0, ROZAMIENTO * delta)

	# El volante: cuanto mas rapido, mas abierto el giro (y al reves).
	if absf(velocidad) > VELOCIDAD_MINIMA_GIRO:
		var factor := clampf(absf(velocidad) / 200.0, 0.35, 1.0)
		var sentido := signf(velocidad)
		if izquierda:
			rotation -= GIRO * delta * factor * sentido
		if derecha:
			rotation += GIRO * delta * factor * sentido

	velocity = Vector2.UP.rotated(rotation) * velocidad
	move_and_slide()

	# Chocar no para el coche en seco sino que lo frena: rebotar como una pelota se
	# siente peor que un golpe.
	if get_slide_collision_count() > 0:
		velocidad *= 0.35


func velocidad_actual() -> float:
	return absf(velocidad)
