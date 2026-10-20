extends "res://scripts/personaje_base.gd"

## UN COMPANERO DE OFICINA.
##
## Se mueve entre puntos del plano y dibuja la misma hoja que el jugador, asi que no
## desentona: mismo tamano, mismo estilo, mismas animaciones. Si el plano no le da
## ruta, se queda quieto mirando a donde diga "mira".
##
## Hablar no esta aqui: la zona de dialogo es un Area2D hija con scripts/interactuable.gd
## puesta por nivel.gd, la MISMA que usan las pantallas y los carteles. Asi "hablar con
## alguien" no tiene codigo propio: es mirar algo que resulta ser una persona.

## Puntos por los que pasea, en el orden del plano. Vacio = se queda parado.
var ruta: Array = []
var velocidad := 58.0

## A donde mira cuando esta parado, en coordenadas del mundo. null = de frente.
var mira_punto = null

var _i := 0
var _espera := 0.0
var _mirando := Vector2.DOWN
var _sin_avance := 0.0
var _ultima := Vector2.ZERO

## Lo que se queda en cada punto antes de ir al siguiente.
const ESPERA_PUNTO := 1.1
## Segundos empujando un mueble sin avanzar antes de saltarse el punto. Sin esto, un
## companero que se choca con una mesa se queda clavado para siempre y el piso
## pierde la vida que le estabas poniendo.
const ATRASCO := 1.6


func _ready() -> void:
	if mira_punto is Vector2:
		var d: Vector2 = mira_punto - global_position
		if d.length() > 1.0:
			_mirando = d.normalized()
	_ultima = global_position
	pintar(_mirando, 0.0, 0.0)


## Lo que trae el plano: velocidad, ruta y hacia donde mira.
func configurar(datos: Dictionary) -> void:
	velocidad = float(datos.get("velocidad", 58.0))
	ruta = []
	for p in datos.get("pasea", []):
		if p is Array and p.size() == 2:
			ruta.append(Vector2(float(p[0]), float(p[1])))
	var m = datos.get("mira", null)
	if m is Array and m.size() == 2:
		mira_punto = Vector2(float(m[0]), float(m[1]))


func _physics_process(delta: float) -> void:
	if ruta.is_empty():
		velocity = Vector2.ZERO
		pintar(_mirando, 0.0, delta)
		return

	if _espera > 0.0:
		_espera = maxf(_espera - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		pintar(_mirando, 0.0, delta)
		return

	var destino: Vector2 = ruta[_i]
	var d := destino - global_position
	if d.length() < 5.0:
		if ruta.size() == 1:
			# Un solo punto significa "vete ahi y quedate". Sin esto, al llegar se
			# queda oscilando entre "he llegado" y "espero en el punto", que es lo
			# mismo que estar clavado pero sin decirlo.
			velocity = Vector2.ZERO
			pintar(_mirando, 0.0, delta)
			return
		_i = (_i + 1) % ruta.size()
		_espera = ESPERA_PUNTO
		return

	_mirando = d.normalized()
	velocity = _mirando * velocidad
	move_and_slide()

	if global_position.distance_to(_ultima) < 1.0:
		_sin_avance += delta
		if _sin_avance > ATRASCO:
			_sin_avance = 0.0
			_i = (_i + 1) % ruta.size()
	else:
		_sin_avance = 0.0
	_ultima = global_position

	pintar(_mirando, 1.0, delta)
