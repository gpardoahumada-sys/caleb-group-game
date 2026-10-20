extends Area2D

## ALGO QUE SE MIRA: una pantalla, un cartel, una terminal.
##
## Es el ladrillo de contenido de todo el edificio. El plano JSON crea uno por cada
## objeto que traiga "titulo", y le pone estos campos. Consultarlo apunta el id en
## GameState, que es lo que luego cuenta para la insignia del piso.

var id := ""
var titulo := ""
## Texto del panel. Acepta BBCode ([b], [i], [color=...]).
var texto := ""
## Lo que dice el HUD antes de pulsar: "[E] Revisar", "[E] Leer", "[E] Inspeccionar".
var verbo := "Revisar"


## Lo que se lee en el HUD cuando lo tienes a tiro. Si ya lo consultaste, lo dice:
## asi el jugador sabe por donde ha pasado sin tener que abrir nada.
func prompt() -> String:
	if GameState.ya_leido(id):
		return "[E] Repasar"
	return "[E] " + verbo


func interactuar(jugador: Node) -> void:
	GameState.marcar_leido(id)
	jugador.call("abrir_panel", titulo, texto)


# ------------------------------------------------------- como se ve el objeto

## Lo llama el jugador cuando esto pasa a ser -o deja de ser- lo que tiene delante.
## Sin esta senal, en un piso lleno de muebles no hay forma de saber que la pantalla
## y el mostrador se pueden tocar y las sillas no: hay que pegarse a cada cosa y
## probar. Un aclarado suave basta y no rompe el tono sobrio del edificio.
func destacar(activo: bool) -> void:
	var dib := get_parent().get_node_or_null("Dibujo") as Sprite2D
	if dib == null:
		return
	dib.modulate = Color(1.18, 1.14, 1.02) if activo else Color.WHITE
