# Caleb Group

Serious game de formación comercial. El jugador es un Consultor Comercial
Estratégico recién incorporado a **Caleb Group**: primero se acredita recorriendo
los cuatro pisos de la torre (Acto 1) y después sale a la ciudad a vender a tres
clientes estratégicos (Acto 2).

Cenital 2D, sin combate: caminar, mirar y decidir.

---

## Estado

Lo que hay montado y jugable:

- **Oficina 1 · Recepción y Cultura** completa, con las tres mecánicas del
  documento: la pantalla del auditorio (propósito, visión, historia, cobertura y
  modelo de trabajo), el **Mapa de Aliados** —organigrama de arrastrar con los cinco
  perfiles— y la **Trivia de Cultura**. La insignia del piso exige las dos lecturas
  y las dos pruebas.
- **Oficina 2 · Centro de Oferta y Metodología** completa: las cuatro terminales de
  conocimiento, el **Clasificador de Dolores** (cinta transportadora con reloj) y la
  trivia de portafolio. La insignia pide cinta y trivia.
- **La ciudad (Acto 2, en construcción)**: distrito corporativo de 3300x1660 con
  coche manejable, tráfico que circula por su carril y respeta los semáforos, gente
  caminando por las aceras, y los cuatro edificios con puerta: la Torre Caleb Group
  (vuelve al lobby) y los tres clientes —**FinBank Corp**, **OmniRetail SA** y
  **MediHealth SA**—. La negociación con cada cliente aún no está.
- **Gente en la oficina**: la recepcionista detrás del mostrador y compañeros que
  pasean, todos con las mismas animaciones que el jugador. Los que tienen `titulo`
  en el plano **se pueden hablar** con la E, y usan el mismo panel que los carteles.
- **Motor de trivia** (`scenes/minijuegos/trivia.tscn`): las preguntas viven en
  `data/trivia_*.json`, así que las cuatro trivias del documento son cuatro
  ficheros de texto, no cuatro minijuegos. Se responde con ratón o con 1-4.
- **Motor de clasificador** (`scenes/minijuegos/clasificador.tscn`): el único con
  reloj. Los documentos y las áreas salen de `data/clasificador_dolores.json`; se
  responde con clic en el área o con 1-4, porque arrastrar contra el cronómetro es
  una pelea. Un documento que se pasa de tiempo cuenta como fallado.
- **Motor de propuesta** (`scenes/minijuegos/propuesta.tscn`): un brief y siete
  módulos de servicio; hay que quedarse con tres. Se puede elegir de más o de menos,
  que son los dos errores que el documento pide evitar — con el motor de arrastrar
  (tres huecos, tres piezas) ninguno de los dos se podía cometer. Nota =
  `100 · (aciertos − sobrantes) / 3`.
- **Oficina 3 · Casos de éxito**: el mural con los tres casos —cada pantalla con su
  franja de color— y el **Constructor de Propuestas**.
- **Motor de comité** (`scenes/minijuegos/comite.tscn`): el pitch final es un
  **árbol de diálogo**, no una lista de preguntas. Lo que respondes decide cuál es la
  siguiente objeción: el relleno abre una repregunta del mismo director, y ofrecer
  descuento corta la reunión en seco. Nota = `100 · puntos / 12`, con **techo de 50**
  si en algún momento se regaló margen.
- **Oficina 4 · Comité comercial**: el pitch con objeciones de los tres directores.
  Al aprobar, el Gerente General entrega la **Llave del Auto Corporativo** —que se
  guarda en el inventario y se ve en el HUD— y la Acreditación Comercial de Terreno,
  que es lo que abre la puerta de la calle del lobby.
- **Motor de arrastrar** (`scenes/minijuegos/arrastrar.tscn`): colocar piezas en
  huecos, con datos en JSON. Sirve para los tres minijuegos de "poner cada cosa en
  su sitio" del documento —Mapa de Aliados, Clasificador de Dolores y Constructor de
  Propuestas— y para dos formas de pensar: asignar (cada pieza tiene su hueco) o
  elegir (las tres buenas caben en cualquiera de los tres).
- **El edificio se recorre entero**: cuatro pisos, cuatro insignias y la puerta de
  la calle que se abre al final.
- **El ascensor navega de verdad**: con la insignia carga el piso siguiente.
- Sistema de **insignias** por piso, con requisitos declarados en una sola tabla
  (`GameState.PISOS`): qué hay que leer (`leer`) y qué pruebas hay que aprobar
  (`pruebas`, una lista: un piso puede pedir dos).
- **Línea de objetivo** en el HUD: dice en todo momento qué te falta y se reescribe
  sola; con muchos requisitos usa un resumen corto para no salirse de pantalla.
- **Lo que se puede tocar se aclara** cuando lo tienes a tiro, y la puerta cerrada
  va apagada y se enciende al ganar la insignia.
- **Los retos se ven desde lejos**: cada prueba tiene su propio **puesto de atril**
  con emblema dorado y un **marcador flotante** que sube y baja. Antes eran
  escritorios iguales que los decorativos y no había forma de saber cuál respondía a
  la E. El marcador lo pone `nivel.gd` a todo objeto con `trivia`, así que un reto
  nuevo lo hereda sin acordarse de nada.
- Panel de información único, reutilizado por todo el contenido.
- Progreso guardado en `user://progreso.json`.

Lo que falta:

| Hito | Qué | Estado |
|---|---|---|
| M2 | Motor de trivia (JSON) | **hecho** |
| M4 | Puerta con insignia que carga escena | **hecho** |
| M3 | Motor de arrastrar-a-su-sitio | **hecho** |
| M5 | Oficinas 1, 2, 3 y 4 | **hecho** |
| M6 | Ciudad, coche y los 3 clientes con diálogos | pendiente |
| M7 | Pantalla del Directorio con las métricas | pendiente |

---

## Cómo se ejecuta

Abrir el proyecto en Godot 4.7 y darle a jugar, o desde la terminal:

```
Godot_v4.7.2-stable_win64.exe --path C:/Users/Memiflax/Documents/caleb-group-game
```

Controles: **WASD / flechas** para moverte, **E / Espacio** para interactuar,
**E / Esc** para cerrar un panel, **F11** pantalla completa.

### Herramientas

```
# Prueba del piso 1: entrada, colisiones, paneles, insignia, HUD, aclarado y
# navegacion al piso siguiente. Sale con codigo 1 si falla.
godot --headless --path . res://tools/prueba.tscn

# Prueba del piso 2: terminales, trivia (aprobar y suspender) e insignia.
godot --headless --path . res://tools/prueba_02.tscn

# LA PARTIDA ENTERA: los cuatro pisos, las cuatro insignias y la puerta de la calle.
# Es la que detecta lo que ninguna prueba de piso ve.
godot --headless --path . res://tools/prueba_todo.tscn

# Capturas del juego, jugandolo por codigo
godot --path . res://tools/captura.tscn
godot --path . res://tools/captura_pisos.tscn
```

Las pruebas existen porque hay cosas que se rompen **en silencio**: el mapa de
teclas escrito en `project.godot`, las puertas que dependen de una insignia, la
línea de objetivo (que se calcula a partir de lo leído) y el umbral de la trivia.
Un cambio ahí no da error, simplemente deja de funcionar. Hoy son 20 + 11 + una
partida completa de punta a punta que recorre los cuatro pisos y comprueba que
quedan las cuatro insignias —esa última es la que caza una insignia mal escrita en
la tabla o un ascensor que apunta a una escena que no existe.

Ojo con una trampa que ya ha mordido: `change_scene_to_file` **libera la escena
actual**, así que una herramienta que sea la escena actual se muere a mitad de
prueba en cuanto el ascensor cambia de piso. Las dos pruebas y el capturador hacen
`get_tree().current_scene = null` para sobrevivir a ese cambio.

---

## Cómo está montado

```
project.godot            mapa de teclas, escena de arranque, autoload GameState
autoload/game_state.gd   insignias, leídos, puntajes, contratos, satisfacción
scripts/nivel.gd         monta un piso a partir de su JSON
scripts/player.gd        movimiento, hoja de 4 direcciones, zona de alcance
scripts/interactuable.gd algo que se mira (pantalla, cartel, terminal)
scripts/puerta.gd        algo que pide una insignia (ascensor, salida)
scripts/panel_info.gd    la ventana de texto
scripts/hud.gd           piso, contador de insignias, prompt, aviso de insignia
data/oficina_01.json     el plano del piso 1: muros, muebles, textos
scenes/building/         un .tscn por piso (5 líneas: Fondo, Entidades, HUD, Panel)
art/                     todo generado por tools/generar_arte.py
tools/                   generador de arte, prueba, capturas
```

### El piso se monta desde el JSON, no a mano

`scripts/nivel.gd` lee `data/oficina_01.json` y construye la sala. La razón es el
Acto 1 entero: los cuatro pisos son la misma lógica con otro plano. Cuatro `.tscn`
casi iguales se desincronizan en cuanto se cambia una pared; cuatro JSON no.

Convención de coordenadas, la única que hay que recordar:

- `pos` de un objeto es **donde apoya en el suelo** (centro de su base), no su
  centro. El dibujo se sube solo a partir de ahí, y así el orden de dibujado sale
  bien sin trucos: el comercial tapa un escritorio si sus pies están más abajo.
- `col` es la caja de colisión, también apoyada en esa base.
- `rect` de un muro es `[x, y, ancho, alto]` con origen en la esquina superior
  izquierda del mundo.
- `mundo` debe medir **1280x720** (la ventana) para que el piso se vea entero de
  una vez. Si algún día un piso es más grande, se le pone `"zoom"` al JSON.

### Añadir un contenido nuevo

Cualquier cosa que se lea es un objeto del JSON con `titulo` y `texto` (admite
BBCode). Nada de código:

```json
{
  "id": "terminal_casos",
  "arte": "pantalla.png",
  "pos": [980, 420],
  "radio": 120,
  "verbo": "Consultar",
  "titulo": "Casos de éxito",
  "texto": "[b]Banca[/b]\nReducción del 40% en tiempos de respuesta."
}
```

Si el `id` está en `GameState.REQUISITOS_IDENTIDAD`, leerlo cuenta para la
insignia; si no, es contenido suelto.

### El arte

Todo sale de `tools/generar_arte.py` (Pillow), de forma determinista. Cambiar la
paleta o el tamaño de una pieza es tocar ese fichero y volver a ejecutarlo:

```
python tools/generar_arte.py
```

El suelo no es una textura plana: lleva la cuadrícula de losetas, grano, la
**sombra de contacto pegada a las paredes** y tres focos de luz del techo. Esas dos
últimas capas son las que hacen que la sala se lea como una sala y no como un
rectángulo de color, y las dos tenían el mismo fallo al principio: empezaban donde
la pared ya las tapaba, así que no se veían. El tamaño del suelo se lee de
`data/*.json`, no está escrito en el generador.

No hay packs externos, así que el proyecto se abre igual en cualquier máquina.

**La excepción es el personaje.** La hoja del protagonista viene del pack de Andreas
(16×32 por casilla) y la monta `tools/andreas.py`, que une las cinco animaciones
sueltas —abajo, arriba, izquierda, derecha y reposo— en una sola hoja de 7×5 filas.
Los ficheros originales están en `art/fuente_andreas/`; el generador de arte no toca
`player_hoja.png` a propósito.

```
python tools/andreas.py     # rehace art/player_hoja.png desde el pack
python tools/npc_hojas.py   # los compañeros: la misma hoja, recoloreada
```

**Los compañeros no son arte nuevo**: son la hoja de Andreas con el traje, el pelo y
la piel remapeados por grupos de color, conservando su sombreado. Caminan con las
mismas animaciones, así que no desentonan. Lo que sí hay que respetar al tocar ese
generador es que la camisa blanca no caiga en el grupo de la piel: se separan por
temperatura (piel = rojo menos azul alto), o los compañeros salen con el pecho
descolorido.
