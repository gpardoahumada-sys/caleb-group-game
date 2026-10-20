extends "res://scripts/interactuable.gd"

## LA TERMINAL DE TRIVIA.
##
## Es un objeto que se mira como cualquier otro -hereda de interactuable.gd el
## prompt, el aclarado y el id-, pero en vez de abrir un panel de texto abre la
## trivia. Por eso hereda en vez de copiar: el aclarado y el "[E] ..." tienen que
## ser exactamente los mismos que los de una pantalla normal, o el jugador nota que
## esa mesa se comporta distinto sin saber por que.

## El JSON de preguntas: res://data/trivia_catalogo.json
var trivia := ""
## La clave con la que se apunta la nota en GameState (y la que mira la insignia).
var clave := ""
## Que motor abre: "trivia" (preguntas) o "arrastrar" (colocar piezas). Los dos
## viven en el mismo arbol de la escena y exponen abrir(ruta, clave), asi que esta
## terminal no sabe cual de los dos es.
var motor := "trivia"


func prompt() -> String:
	if clave != "" and GameState.puntaje_de(clave) >= GameState.NOTA_MINIMA:
		return "[E] Repetir"
	return "[E] " + verbo


func interactuar(_jugador: Node) -> void:
	var t := get_tree().get_first_node_in_group(motor)
	if t == null or not t.has_method("abrir"):
		push_warning("Esta escena no tiene montado el motor '%s' para %s" % [motor, trivia])
		return
	t.call("abrir", trivia, clave)
