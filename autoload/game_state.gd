extends Node

## EL ESTADO DE LA PARTIDA COMERCIAL.
##
## Es un autoload: vive por encima de las escenas, asi que sobrevive a cambiar de
## piso, salir a la ciudad y volver a la torre. Es lo unico que el juego necesita
## recordar entre escena y escena.
##
## Que guarda, y para que:
##
##   - insignias  que acreditaciones has conseguido ("identidad", "catalogo"...).
##                Son la llave: las puertas del edificio preguntan por ellas.
##   - leidos     que terminales, pantallas y paneles has consultado ya. Sirve para
##                dos cosas: saber si te falta algo para la insignia, y que el
##                jugador vea donde ya ha estado (el prompt cambia a "Repasar").
##   - puntajes   la nota de cada minijuego y trivia (0-100). Alimenta la metrica
##                "Nivel de Conocimiento" del Acto 3.
##   - contratos  el valor simbolico de los acuerdos cerrados en el Acto 2.
##   - satisfaccion  la confianza conseguida con cada cliente (0-100).
##
## Se guarda en user://progreso.json, no en la carpeta del proyecto: no se pierde
## al cerrar el juego y no ensucia el repositorio.

const FICHERO := "user://progreso.json"

## QUE HACE FALTA PARA CADA INSIGNIA, piso por piso.
##
## Una insignia se gana cuando has consultado TODO lo de "leer" y has aprobado
## TODAS las pruebas de "pruebas". Las pruebas son claves de puntaje: una trivia, un
## minijuego de arrastrar, o dos a la vez -la Oficina 1 pide el Mapa de Aliados y la
## Trivia de Cultura-. Toda la regla del edificio -que abre el ascensor y que no- sale
## de esta tabla: anadir un requisito es anadir un id aqui, y ni la puerta ni el HUD
## se tocan.
##
## Vive aqui y no repartido por las puertas porque ya son varios sitios los que
## preguntan "¿que me falta?": con una copia en cada uno, el cartel del ascensor y la
## linea de objetivo acabarian diciendo cosas distintas.
const PISOS := {
	"identidad": {
		"leer": ["pantalla", "recepcion"],
		"pruebas": ["mapa_aliados", "trivia_cultura"],
		"resumen": "",
	},
	"catalogo": {
		"leer": ["terminal_1", "terminal_2", "terminal_3", "terminal_4"],
		"pruebas": ["clasificador", "trivia_catalogo"],
		"resumen": "las cuatro terminales del piso",
	},
	"casos": {
		"leer": ["caso_1", "caso_2", "caso_3"],
		"pruebas": ["propuesta"],
		"resumen": "los tres casos del mural",
	},
	"acreditacion": {
		"leer": [],
		"pruebas": ["pitch_comite"],
		"resumen": "",
	},
}

## Con cuanto se aprueba. El 80% no es un numero al azar: es el que pide el diseño
## del piso ("superar el 80% otorga la insignia"), y vale para todas las trivias.
const NOTA_MINIMA := 80.0

## Como se llama cada requisito cuando hay que escribirlo en una frase.
const NOMBRES := {
	"pantalla": "la pantalla",
	"recepcion": "el mostrador",
	"terminal_1": "la terminal de transformación digital",
	"terminal_2": "la terminal de datos e IA",
	"terminal_3": "la terminal de cloud y ciberseguridad",
	"terminal_4": "la terminal de servicios gestionados",
	"trivia_catalogo": "la trivia de portafolio",
	"clasificador": "el Clasificador de Dolores",
	"mapa_aliados": "el Mapa de Aliados",
	"trivia_cultura": "la Trivia de Cultura",
	"caso_1": "el caso de banca",
	"caso_2": "el caso de retail",
	"caso_3": "el caso de salud",
	"propuesta": "el constructor de propuestas",
	"pitch_comite": "el pitch ante el comité",
}

## Se emite al apuntar una lectura que no estaba. El HUD la escucha para reescribir
## la linea de objetivo en cuanto consultas algo, sin tener que preguntar cada
## fotograma.
signal lectura_apuntada(id: String)

## Se emite al empezar una partida limpia. El HUD lo escucha para no quedarse
## ensenando el contador y el objetivo de la partida de antes.
signal progreso_reiniciado

## Se emite al ganar una insignia. El HUD la escucha para ensenar el aviso: asi el
## que la concede no tiene que saber que existe un HUD.
signal insignia_obtenida(id: String)

## Se emite al entregarte un objeto. El HUD la escucha para ensenar la llave: el
## objeto se guarda desde el minijuego, que no sabe que existe un HUD.
signal objeto_obtenido(id: String)

var insignias := {}
var leidos := {}
var puntajes := {}
var contratos := 0
var satisfaccion := {}
## Objetos que te han entregado en la narrativa (la Llave del Auto Corporativo). No
## son insignias: una insignia te acredita, un objeto se usa. El Acto 2 mirara aqui
## para dejar salir a la calle.
var inventario: Array = []


func _ready() -> void:
	cargar()


## Empieza una partida limpia. No toca nada de disco hasta el guardar().
func nuevo_juego() -> void:
	insignias.clear()
	leidos.clear()
	puntajes.clear()
	satisfaccion.clear()
	inventario.clear()
	contratos = 0
	guardar()
	progreso_reiniciado.emit()


# --------------------------------------------------------------- lo consultado

func ya_leido(id: String) -> bool:
	if id == "":
		return false
	return bool(leidos.get(id, false))


## Apunta que has consultado `id`. Devuelve si era la PRIMERA vez: consultar dos
## veces el mismo cartel no puede volver a dar insignia ni volver a sumar.
##
## Y aqui es donde se comprueba si con esta lectura ya cae alguna insignia. Se hace
## en el mismo sitio que apunta la lectura para que no haya dos listas de "que
## falta" que se puedan desincronizar.
func marcar_leido(id: String) -> bool:
	if id == "" or ya_leido(id):
		return false
	leidos[id] = true
	_comprobar_insignias()
	guardar()
	lectura_apuntada.emit(id)
	return true


## El nombre de pantalla de un requisito, o el id tal cual si no esta en la tabla.
func nombre_de(id: String) -> String:
	return str(NOMBRES.get(id, id))


## Los ids que aun te faltan por consultar para la insignia `insignia`.
func faltan_para(insignia: String) -> Array:
	var faltan: Array = []
	var piso = PISOS.get(insignia, null)
	if not (piso is Dictionary):
		return faltan
	for r in piso.get("leer", []):
		if not ya_leido(str(r)):
			faltan.append(str(r))
	return faltan


## "la pantalla del auditorio y el mostrador de recepción", con coma y "y" como se
## escribe. Cadena vacia si no falta nada.
##
## Se monta a mano y no con join(): join() quiere un PackedStringArray y aqui lo que
## se maneja es un Array de nombres.
func faltan_texto(insignia: String) -> String:
	var faltan := faltan_para(insignia)
	if faltan.is_empty():
		return ""
	var texto := ""
	for i in range(faltan.size()):
		if i > 0:
			texto += " y " if i == faltan.size() - 1 else ", "
		texto += nombre_de(str(faltan[i]))
	return texto


## Las claves de puntaje que pide esta insignia: una trivia, un minijuego o dos.
func pruebas_de(insignia: String) -> Array:
	var piso = PISOS.get(insignia, null)
	if not (piso is Dictionary):
		return []
	return piso.get("pruebas", [])


## ¿Estan TODAS las pruebas del piso aprobadas? Si el piso no pide ninguna, la
## respuesta es que si: asi el que pregunta no tiene que saber en que piso esta.
func prueba_superada(insignia: String) -> bool:
	for clave in pruebas_de(insignia):
		if puntaje_de(str(clave)) < NOTA_MINIMA:
			return false
	return true


## Las pruebas que aun estan suspensas.
func faltan_pruebas(insignia: String) -> Array:
	var faltan: Array = []
	for clave in pruebas_de(insignia):
		if puntaje_de(str(clave)) < NOTA_MINIMA:
			faltan.append(str(clave))
	return faltan


## "el Mapa de Aliados y la Trivia de Cultura", con coma y "y" como se escribe.
func faltan_pruebas_texto(insignia: String) -> String:
	var faltan := faltan_pruebas(insignia)
	var texto := ""
	for i in range(faltan.size()):
		if i > 0:
			texto += " y " if i == faltan.size() - 1 else ", "
		texto += nombre_de(str(faltan[i]))
	return texto


## La frase del HUD: que te falta, en palabras. Vacia si ya lo tienes todo.
##
## Con muchos requisitos NO se enumeran uno por uno: la linea del HUD es un vistazo,
## no un indice, y "consulta la terminal de transformación digital, la terminal de
## datos e IA, la terminal de cloud..." se sale de la pantalla y no se lee. A partir
## de tres se usa el "resumen" corto del piso; el detalle exacto lo sigue dando el
## cartel de la puerta.
func objetivo_texto(insignia: String) -> String:
	var partes: Array = []
	var faltan := faltan_para(insignia)
	if not faltan.is_empty():
		var resumen := resumen_de(insignia)
		if faltan.size() >= 3 and resumen != "":
			partes.append("consulta " + resumen)
		else:
			partes.append("consulta " + faltan_texto(insignia))
	if not faltan_pruebas(insignia).is_empty():
		partes.append("supera " + faltan_pruebas_texto(insignia))
	if partes.is_empty():
		return ""
	if partes.size() == 1:
		return str(partes[0])
	# Con un punto medio y no con " y ": en un piso que pide leer Y aprobar, encadenar
	# dos "y" seguidas ("consulta la pantalla y el mostrador y supera...") se lee mal
	# y ademas no cabe en la linea del HUD.
	return "%s · %s" % [str(partes[0]), str(partes[1])]


## El resumen corto del piso, para la linea de objetivo cuando falta mucho.
func resumen_de(insignia: String) -> String:
	var piso = PISOS.get(insignia, null)
	if not (piso is Dictionary):
		return ""
	return str(piso.get("resumen", ""))


# ------------------------------------------------------------------ insignias

func tiene_insignia(id: String) -> bool:
	return bool(insignias.get(id, false))


## Concede una insignia. Devuelve si era nueva; si ya la tenias no hace nada (ni
## vuelve a avisar), que es lo que permite llamarlo sin preguntar antes.
func dar_insignia(id: String) -> bool:
	if id == "" or tiene_insignia(id):
		return false
	insignias[id] = true
	guardar()
	insignia_obtenida.emit(id)
	return true


func cuantas_insignias() -> int:
	return insignias.size()


# ------------------------------------------------------------------ inventario

## Los objetos que te han entregado, con su nombre de pantalla.
const OBJETOS := {
	"llave_auto": "Llave del Auto Corporativo",
}


func tiene_objeto(id: String) -> bool:
	return inventario.has(id)


## Apunta un objeto en el inventario. Devuelve si era nuevo: entregar dos veces la
## misma llave no puede duplicarla ni volver a avisar.
func dar_objeto(id: String) -> bool:
	if id == "" or tiene_objeto(id):
		return false
	inventario.append(id)
	guardar()
	objeto_obtenido.emit(id)
	return true


func nombre_objeto(id: String) -> String:
	return str(OBJETOS.get(id, id))


## Recorre la tabla y concede las insignias cuyos requisitos ya se cumplen. Se llama
## tras CADA lectura y tras CADA nota: da igual en que orden se hagan las cosas, que
## el piso no se queda a medias por haber empezado por la trivia.
func _comprobar_insignias() -> void:
	for insignia in PISOS:
		if tiene_insignia(str(insignia)):
			continue
		if faltan_para(str(insignia)).is_empty() and prueba_superada(str(insignia)):
			dar_insignia(str(insignia))


# ------------------------------------------------------------------- puntajes

## La nota de un minijuego o trivia. Se queda con la MEJOR de las intentonas: en
## un juego de formacion repetir para aprender no puede bajar la nota.
func apuntar_puntaje(clave: String, nota: float) -> void:
	if clave == "":
		return
	var mejor := maxf(float(puntajes.get(clave, 0.0)), clampf(nota, 0.0, 100.0))
	puntajes[clave] = mejor
	_comprobar_insignias()
	guardar()


func puntaje_de(clave: String) -> float:
	return float(puntajes.get(clave, 0.0))


## La media de todos los puntajes apuntados: es la metrica "Nivel de Conocimiento"
## del informe final. Sin puntajes todavia devuelve 0, no un error.
func conocimiento_medio() -> float:
	if puntajes.is_empty():
		return 0.0
	var suma := 0.0
	for k in puntajes:
		suma += float(puntajes[k])
	return suma / float(puntajes.size())


# ------------------------------------------------------------------ contratos

func firmar_contrato(valor: int, cliente: String, confianza: int) -> void:
	contratos = maxi(contratos + valor, 0)
	satisfaccion[cliente] = clampi(confianza, 0, 100)
	guardar()


func contratos_en_millones() -> String:
	## El valor va en miles de dolares simbolicos; esto solo lo formatea.
	return "%d" % contratos


# --------------------------------------------------------------------- disco

func guardar() -> void:
	var datos := {
		"insignias": insignias,
		"leidos": leidos,
		"puntajes": puntajes,
		"contratos": contratos,
		"satisfaccion": satisfaccion,
		"inventario": inventario,
	}
	var f := FileAccess.open(FICHERO, FileAccess.WRITE)
	if f == null:
		push_warning("No he podido guardar el progreso en " + FICHERO)
		return
	f.store_string(JSON.stringify(datos, "\t"))
	f.close()


## Lee el progreso de disco. Todo lo que falte se queda como estaba: un fichero de
## una version anterior -o a medio escribir- no puede dejar el juego sin arrancar.
func cargar() -> void:
	if not FileAccess.file_exists(FICHERO):
		return
	var f := FileAccess.open(FICHERO, FileAccess.READ)
	if f == null:
		return
	var texto := f.get_as_text()
	f.close()
	var leido = JSON.parse_string(texto)
	if not (leido is Dictionary):
		push_warning("El progreso guardado no se entiende; se empieza de cero.")
		return
	if leido.get("insignias") is Dictionary:
		insignias = leido["insignias"]
	if leido.get("leidos") is Dictionary:
		leidos = leido["leidos"]
	if leido.get("puntajes") is Dictionary:
		puntajes = leido["puntajes"]
	if leido.get("satisfaccion") is Dictionary:
		satisfaccion = leido["satisfaccion"]
	if leido.get("inventario") is Array:
		inventario = leido["inventario"]
	contratos = int(leido.get("contratos", 0))
