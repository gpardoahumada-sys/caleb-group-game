#!/usr/bin/env python3
"""Genera el arte de Caleb Group: Torre Caleb Group.

Todo el arte del juego sale de aqui, de forma determinista: si hay que cambiar la
paleta o el tamaño de una pieza, se toca este fichero y se vuelve a ejecutar. No
depende de ningun pack externo, asi que el proyecto se puede abrir en cualquier
maquina y se ve igual.

La UNICA excepcion es la hoja del personaje protagonista: viene del pack de Andreas
(art/fuente_andreas/) y la monta tools/andreas.py en el mismo art/player_hoja.png.
Este generador no la toca.

    python tools/generar_arte.py

Escribe en res://art/. Se ejecuta desde la raiz del proyecto.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw

ART = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art")

# --------------------------------------------------------------------- paleta
SUELO = (38, 48, 61)
SUELO_LINEA = (32, 41, 53)
SUELO_RUIDO = (44, 55, 70)
MURO = (26, 35, 46)
MURO_TAPA = (20, 27, 36)
MURO_LUZ = (58, 74, 94)
ORO = (212, 162, 74)
ORO_OSCURO = (150, 110, 45)
TEAL = (47, 163, 163)
TEAL_OSCURO = (28, 104, 106)
BLANCO = (232, 238, 245)
GRIS = (150, 162, 178)
MADERA = (107, 74, 52)
MADERA_CLARA = (138, 97, 68)
METAL = (92, 104, 118)
METAL_CLARO = (124, 138, 155)
NEGRO_PANTALLA = (12, 20, 28)


def asegurar(ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    return ruta


def guardar(img, nombre):
    ruta = asegurar(os.path.join(ART, nombre))
    img.save(ruta)
    print("  ", nombre, img.size)


# ------------------------------------------------------------------ el suelo
## La sombra de las paredes y los charcos de luz del techo son lo que convierte
## 1280x720 de moqueta en una sala: dan relieve sin modelar nada en 3D.
def suelo(ancho=1280, alto=720):
    """Moqueta de oficina vista desde arriba.

    Tres capas, y cada una resuelve algo:
      - la CUADRICULA de losetas, que da escala y hace legible la distancia que
        recorres;
      - el GRANO, que evita que la superficie se lea como un rectangulo de color
        plano (se nota sobre todo al mover al personaje);
      - la SOMBRA de los bordes y los CHARCOS de luz, que es lo que hace que la
        sala parezca una sala.
    """
    img = Image.new("RGB", (ancho, alto), SUELO)
    d = ImageDraw.Draw(img)
    for x in range(0, ancho, 64):
        d.line([(x, 0), (x, alto)], fill=SUELO_LINEA)
    for y in range(0, alto, 64):
        d.line([(0, y), (ancho, y)], fill=SUELO_LINEA)

    rnd = random.Random(7)
    for _ in range((ancho * alto) // 420):
        x = rnd.randrange(ancho)
        y = rnd.randrange(alto)
        d.rectangle([x, y, x + 1, y + 1], fill=SUELO_RUIDO)

    # Los charcos de luz: tres focos en la fila de arriba y otros mas suaves
    # abajo, que es donde estaria el techo de un lobby.
    luz = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    for cx in (ancho // 6, ancho // 2, ancho * 5 // 6):
        _charco(luz, cx, int(alto * 0.30), 250, 130, alfa=26)
        _charco(luz, cx, int(alto * 0.72), 250, 130, alfa=18)

    # La sombra de contacto: el degradado tiene que EMPEZAR donde acaba la pared
    # (64 px hacia dentro). Antes arrancaba en el borde del mapa, y como la pared
    # tapa justo esos 64 px, cuando la sombra se veia ya estaba casi a cero: no se
    # notaba nada.
    sombra = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sombra)
    desde = 64
    borde = 96
    for j in range(borde):
        a = int(92 * (1.0 - j / borde) ** 2.0)
        if a <= 0:
            continue
        y0 = desde + j
        y1 = alto - 1 - desde - j
        x0 = desde + j
        x1 = ancho - 1 - desde - j
        ds.line([(0, y0), (ancho, y0)], fill=(6, 8, 12, a))
        ds.line([(0, y1), (ancho, y1)], fill=(6, 8, 12, a))
        ds.line([(x0, 0), (x0, alto)], fill=(6, 8, 12, a))
        ds.line([(x1, 0), (x1, alto)], fill=(6, 8, 12, a))

    out = Image.alpha_composite(img.convert("RGBA"), luz)
    out = Image.alpha_composite(out, sombra)
    return out.convert("RGB")


def _charco(capa, cx, cy, rx, ry, alfa=24, pasos=14):
    """Un foco de luz difuso: elipses concentricas, cada vez mas opacas hacia el
    centro. No hay gradientes en ImageDraw y esto basta para lo que se ve.

    El alfa va POR ANILLO y creciente hacia dentro: como cada elipse interior tapa
    a la anterior, lo que queda es un escalonado de opacidad. Si se pusiera el mismo
    alfa a todas -que es lo primero que sale-, el centro quedaria con el alfa de la
    ultima, o sea casi nada, y el foco no se veria.
    """
    d = ImageDraw.Draw(capa)
    for i in range(pasos, 0, -1):
        t = i / pasos
        a = int(alfa * (1.0 - t) ** 1.6)
        if a <= 0:
            continue
        d.ellipse([cx - rx * t, cy - ry * t, cx + rx * t, cy + ry * t],
                  fill=(255, 248, 232, a))


def tamano_mundo():
    """El tamano del suelo sale de los planos y no de un numero escrito aqui: si un
    piso cambia de tamano, la moqueta no puede quedarse con el de antes."""
    ancho, alto = 1280, 720
    carpeta = os.path.join(os.path.dirname(ART), "data")
    if os.path.isdir(carpeta):
        for f in sorted(os.listdir(carpeta)):
            if not f.endswith(".json"):
                continue
            try:
                with open(os.path.join(carpeta, f), encoding="utf-8") as fh:
                    m = json.load(fh).get("mundo")
            except (OSError, ValueError):
                continue
            if isinstance(m, list) and len(m) == 2:
                ancho = max(ancho, int(m[0]))
                alto = max(alto, int(m[1]))
    return ancho, alto


def alfombra(ancho=520, alto=340):
    """Alfombra de recepcion: la zona del mostrador se lee distinta del pasillo."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, ancho - 1, alto - 1], 18, fill=TEAL_OSCURO)
    d.rounded_rectangle([14, 14, ancho - 15, alto - 15], 12, outline=ORO_OSCURO, width=3)
    d.rounded_rectangle([26, 26, ancho - 27, alto - 27], 8, fill=(34, 78, 84))
    return img


# ------------------------------------------------------------------ los muros
def muro_horizontal(nombre="muro_h.png"):
    """Muro que mira hacia abajo (el de arriba de la sala): luz en el borde bajo."""
    img = Image.new("RGB", (64, 64), MURO)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 7], fill=MURO_TAPA)
    d.rectangle([0, 52, 63, 58], fill=MURO_LUZ)
    d.rectangle([0, 59, 63, 60], fill=ORO_OSCURO)
    d.rectangle([0, 61, 63, 63], fill=MURO_TAPA)
    return img


def muro_vertical(nombre="muro_v.png"):
    """Muro que mira hacia la derecha (el de la izquierda): luz en el borde derecho."""
    img = muro_horizontal().rotate(90, expand=True)
    return img


# ------------------------------------------------------------- el mobiliario
def escritorio(ancho=176, alto=88):
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Sombra al suelo.
    d.ellipse([8, alto - 18, ancho - 8, alto - 2], fill=(20, 26, 34, 120))
    # Tablero.
    d.rounded_rectangle([0, 0, ancho - 1, alto - 26], 8, fill=MADERA)
    d.rounded_rectangle([0, 0, ancho - 1, 12], 8, fill=MADERA_CLARA)
    # Monitor de frente, mirando al jugador.
    d.rounded_rectangle([ancho // 2 - 30, 14, ancho // 2 + 30, 48], 4, fill=(30, 36, 44))
    d.rounded_rectangle([ancho // 2 - 26, 18, ancho // 2 + 26, 44], 2,
                         fill=(52, 120, 132))
    d.rectangle([ancho // 2 - 3, 48, ancho // 2 + 3, 54], fill=(30, 36, 44))
    d.rounded_rectangle([ancho // 2 - 12, 54, ancho // 2 + 12, 58], 2, fill=(30, 36, 44))
    # Papeles y taza.
    d.rectangle([16, 20, 46, 38], fill=BLANCO)
    d.line([(20, 26), (42, 26)], fill=GRIS)
    d.line([(20, 31), (36, 31)], fill=GRIS)
    d.ellipse([ancho - 44, 22, ancho - 20, 40], fill=BLANCO)
    d.ellipse([ancho - 40, 24, ancho - 24, 36], fill=(74, 48, 34))
    # Cuerpo del escritorio.
    d.rectangle([6, alto - 26, ancho - 7, alto - 6], fill=MADERA)
    return img


def mostrador(ancho=280, alto=104):
    """Recepcion: el mueble donde te reciben.

    Antes era una losa: la tapa medía 22 px y el frente 70, o sea que se leia como
    un banco bajo y no como un mostrador. Y ademas contradecia a los escritorios,
    que si tienen la tapa grande y el frente fino -que es como se ve un mueble
    desde arriba-. Ahora es el mismo idioma: tapa grande con lo que hay encima, y
    un frente mas alto que el de un escritorio, que es lo que lo hace mostrador.
    """
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, alto - 16, ancho - 10, alto - 2], fill=(20, 26, 34, 140))

    # La tapa.
    d.rounded_rectangle([0, 0, ancho - 1, alto - 34], 8, fill=(48, 60, 76))
    d.rounded_rectangle([0, 0, ancho - 1, 14], 8, fill=(64, 78, 96))

    # El frente, alto y oscuro, con el filo dorado de la marca.
    d.rectangle([4, alto - 36, ancho - 5, alto - 8], fill=(34, 43, 56))
    d.rectangle([4, alto - 36, ancho - 5, alto - 33], fill=ORO)
    cx = ancho // 2
    d.ellipse([cx - 12, alto - 30, cx + 12, alto - 12], outline=ORO, width=2)
    d.line([(cx - 5, alto - 21), (cx + 5, alto - 21)], fill=ORO, width=2)

    # Lo que hay encima de un mostrador: pantalla, papeles y telefono.
    d.rounded_rectangle([44, 16, 112, 48], 4, fill=(30, 36, 44))
    d.rounded_rectangle([48, 20, 108, 44], 2, fill=(52, 120, 132))
    d.rectangle([76, 48, 82, 54], fill=(30, 36, 44))
    d.rectangle([16, 18, 34, 42], fill=BLANCO)
    d.line([(19, 24), (31, 24)], fill=GRIS)
    d.line([(19, 29), (28, 29)], fill=GRIS)
    d.ellipse([228, 18, 258, 42], fill=BLANCO)
    d.ellipse([234, 22, 252, 38], fill=(74, 48, 34))
    return img


def pantalla(ancho=260, alto=150):
    """La pantalla gigante del auditorio: el primer interactuable de la partida."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, ancho - 1, alto - 1], 6, fill=(16, 22, 30))
    d.rounded_rectangle([4, 4, ancho - 5, alto - 5], 3, fill=NEGRO_PANTALLA)
    # Lo que se ve en la pantalla: barras y una linea, para que parezca un panel de
    # datos y no un rectangulo azul.
    d.rectangle([4, 4, ancho - 5, 20], fill=(24, 56, 62))
    for i in range(6):
        x = 18 + i * 16
        h = 18 + int(26 * abs(math.sin(i * 1.1)))
        d.rectangle([x, alto - 24 - h, x + 9, alto - 24], fill=TEAL)
    d.line([(150, alto - 40), (170, alto - 58), (190, alto - 34), (214, alto - 70),
            (238, alto - 48)], fill=ORO, width=2)
    # Brillo diagonal del cristal.
    d.polygon([(4, 4), (70, 4), (4, 60)], fill=(255, 255, 255, 16))
    return img


def planta(ancho=56, alto=74):
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, alto - 14, ancho - 2, alto - 1], fill=(20, 26, 34, 120))
    # Maceta.
    d.polygon([(14, alto - 30), (ancho - 14, alto - 30), (ancho - 18, alto - 4),
               (18, alto - 4)], fill=(96, 72, 58))
    d.rectangle([12, alto - 32, ancho - 12, alto - 28], fill=(120, 92, 72))
    # Hojas: tres manojos de elipses.
    cx = ancho // 2
    for dx, dy, r, c in [(-10, -8, 15, (52, 112, 88)), (10, -10, 14, (61, 132, 100)),
                         (0, -20, 16, (72, 150, 112)), (-4, -2, 13, (44, 98, 78))]:
        d.ellipse([cx + dx - r, alto - 34 + dy - r, cx + dx + r, alto - 34 + dy + r],
                  fill=c)
    return img


def ascensor(ancho=140, alto=112):
    """Las puertas del ascensor: el cerrojo del Acto 1."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, ancho - 1, alto - 1], fill=(30, 38, 48))
    d.rectangle([6, 6, ancho - 7, alto - 7], fill=METAL)
    # Las dos hojas.
    d.rectangle([10, 10, ancho // 2 - 1, alto - 10], fill=METAL_CLARO)
    d.rectangle([ancho // 2 + 1, 10, ancho - 11, alto - 10], fill=METAL_CLARO)
    d.line([(ancho // 2 - 1, 10), (ancho // 2 - 1, alto - 11)], fill=(60, 70, 82), width=2)
    d.line([(ancho // 2 + 1, 10), (ancho // 2 + 1, alto - 11)], fill=(60, 70, 82), width=2)
    # Panel de botones con la flecha hacia arriba en dorado.
    d.rounded_rectangle([ancho - 26, alto // 2 - 16, ancho - 14, alto // 2 + 16], 3,
                        fill=(24, 30, 38))
    d.polygon([(ancho - 20, alto // 2 - 8), (ancho - 14, alto // 2), (ancho - 26,
                                                                      alto // 2)],
              fill=ORO)
    # Marco superior con el numero de planta (un punto en vez de un numero: el
    # numero en texto se pone en la escena, para poder cambiarlo sin tocar el arte).
    d.rectangle([ancho // 2 - 22, 2, ancho // 2 + 22, 12], fill=(18, 24, 30))
    return img


def mesa_reunion(ancho=320, alto=170):
    """Mesa ovalada con sillas. Antes tenia radio 40 y salia como una bañera: el
    radio tiene que ser pequeño delante del alto o la forma se vuelve un tubo."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([16, alto - 26, ancho - 16, alto - 4], fill=(20, 26, 34, 130))
    # Sillas de arriba y de abajo, asomando por detras y por delante del tablero.
    for i in range(4):
        x = 44 + i * 62
        d.rounded_rectangle([x, 6, x + 44, 34], 10, fill=(40, 48, 58))
        d.rounded_rectangle([x, alto - 54, x + 44, alto - 24], 10, fill=(48, 57, 69))
    # Tablero: elipse achatada, no capsula.
    d.ellipse([4, 22, ancho - 5, alto - 44], fill=(58, 44, 36))
    d.ellipse([10, 28, ancho - 11, alto - 50], fill=(84, 62, 48))
    # Lo que hay encima: portatiles y papeles.
    for i in range(3):
        x = 60 + i * 70
        d.rounded_rectangle([x, 62, x + 34, 82], 3, fill=(34, 40, 50))
        d.rectangle([x + 4, 65, x + 30, 78], fill=(46, 78, 88))
    d.rectangle([150, 58, 180, 70], fill=(226, 232, 240))
    d.ellipse([96, 86, 118, 98], fill=(226, 232, 240))
    return img


# ------------------------------------------------ el personaje (4x4, 32x32)
def personaje():
    """Hoja del comercial: 4 filas (abajo, arriba, izquierda, derecha) x 4 pasos.

    32x32 por casilla. Se dibuja con formas planas y un contorno oscuro: a 64 px
    en pantalla (escala 2) se lee bien y no parece un muñeco de plastico.
    """
    C = 32
    hoja = Image.new("RGBA", (C * 4, C * 4), (0, 0, 0, 0))
    TRAJE = (43, 58, 85)
    TRAJE_OSC = (28, 40, 62)
    CAMISA = (232, 238, 245)
    PIEL = (224, 180, 143)
    PELO = (42, 33, 24)
    ZAPATO = (24, 24, 28)
    BORDE = (18, 22, 30)

    for fila in range(4):          # abajo, arriba, izquierda, derecha
        for paso in range(4):      # -1, 0, +1, 0
            img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            fase = [0, 1, 0, -1][paso]
            cx = C // 2
            # Sombra.
            d.ellipse([cx - 9, 26, cx + 9, 30], fill=(0, 0, 0, 90))
            # Piernas: dos rectangulos que se separan segun la fase.
            izq = 1 + fase
            der = 1 - fase
            d.rectangle([cx - 7, 20 + izq, cx - 2, 27], fill=TRAJE_OSC)
            d.rectangle([cx + 1, 20 + der, cx + 6, 27], fill=TRAJE_OSC)
            d.rectangle([cx - 7, 26 + izq, cx - 2, 29], fill=ZAPATO)
            d.rectangle([cx + 1, 26 + der, cx + 6, 29], fill=ZAPATO)
            # Torso con chaqueta y hombros.
            d.rounded_rectangle([cx - 9, 9, cx + 8, 23], 4, fill=TRAJE)
            d.rounded_rectangle([cx - 9, 9, cx + 8, 23], 4, outline=BORDE)
            # Cabeza.
            d.ellipse([cx - 7, 1, cx + 6, 14], fill=PELO)
            if fila == 0:      # de frente: cara y corbata
                d.ellipse([cx - 5, 5, cx + 4, 14], fill=PIEL)
                d.rectangle([cx - 2, 12, cx + 1, 18], fill=TEAL)
                d.rectangle([cx - 5, 5, cx + 4, 8], fill=PELO)
                d.point([(cx - 3, 10)], fill=(30, 30, 34))
                d.point([(cx + 2, 10)], fill=(30, 30, 34))
                d.rectangle([cx - 5, 10, cx + 4, 10], fill=PIEL)
            elif fila == 1:    # de espaldas: se le ve la nuca
                d.ellipse([cx - 5, 4, cx + 4, 13], fill=PELO)
                d.rectangle([cx - 1, 9, cx + 0, 14], fill=TRAJE_OSC)
            elif fila == 2:    # hacia la izquierda: la cara asoma por la izquierda
                d.ellipse([cx - 6, 3, cx + 5, 14], fill=PIEL)
                d.ellipse([cx - 3, 1, cx + 6, 12], fill=PELO)
                d.point([(cx - 4, 9)], fill=(30, 30, 34))
                # Cuello de la camisa y brazo del lado que se ve.
                d.polygon([(cx - 2, 12), (cx + 2, 12), (cx, 16)], fill=CAMISA)
                d.rectangle([cx + 1, 13, cx + 8, 19], fill=TRAJE_OSC)
            else:              # hacia la derecha
                d.ellipse([cx - 6, 3, cx + 5, 14], fill=PIEL)
                d.ellipse([cx - 6, 1, cx + 3, 12], fill=PELO)
                d.point([(cx + 3, 9)], fill=(30, 30, 34))
                d.polygon([(cx - 2, 12), (cx + 2, 12), (cx, 16)], fill=CAMISA)
                d.rectangle([cx - 8, 13, cx - 1, 19], fill=TRAJE_OSC)
            hoja.paste(img, (paso * C, fila * C))
    return hoja


def terminal(ancho=104, alto=150):
    """Las Terminales de Conocimiento de la Oficina 2: un kiosco con pantalla.

    Alta y estrecha a proposito: desde arriba, un mostrador y un kiosco se
    distinguen por la forma, no por el color.
    """
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, alto - 14, ancho - 6, alto - 2], fill=(20, 26, 34, 140))
    # Cuerpo.
    d.rounded_rectangle([8, 26, ancho - 9, alto - 6], 6, fill=(42, 53, 68))
    d.rounded_rectangle([12, 30, ancho - 13, alto - 10], 4, fill=(34, 43, 56))
    # Pantalla inclinada, mirando al jugador.
    d.rounded_rectangle([4, 4, ancho - 5, 62], 6, fill=(24, 30, 38))
    d.rounded_rectangle([9, 9, ancho - 10, 57], 3, fill=(38, 104, 112))
    d.polygon([(9, 9), (34, 9), (9, 34)], fill=(120, 200, 210, 70))
    # Filas de texto falsas y el filo dorado de la marca.
    for i in range(3):
        d.rectangle([14, 16 + i * 10, ancho - 20 - i * 8, 20 + i * 10],
                    fill=(150, 226, 232))
    d.rectangle([8, 66, ancho - 9, 70], fill=ORO_OSCURO)
    # Teclado.
    d.rounded_rectangle([22, 78, ancho - 23, 96], 3, fill=(26, 32, 41))
    for f in range(3):
        d.line([(26, 82 + f * 5), (ancho - 27, 82 + f * 5)], fill=(70, 84, 102))
    return img


def puesto_reto(ancho=150, alto=190):
    """El PUESTO DE RETO: donde se hace la trivia o el minijuego.

    Antes los retos eran un escritorio o una mesa, iguales que los decorativos, y no
    habia forma de distinguirlos: el jugador tenia que pegarse a cada mueble y probar
    la E. Esta pieza es un atril con el emblema dorado bien grande, alto y estrecho,
    para que se lea como "aqui se hace algo" desde el otro lado de la sala.
    """
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = ancho // 2
    # Sombra y peana.
    d.ellipse([10, alto - 16, ancho - 10, alto - 2], fill=(18, 24, 32, 150))
    d.rounded_rectangle([cx - 34, alto - 34, cx + 34, alto - 8], 6, fill=(28, 36, 47))
    # Cuerpo, inclinado hacia el jugador.
    d.polygon([(cx - 46, 96), (cx + 46, 96), (cx + 56, alto - 30), (cx - 56, alto - 30)],
              fill=(46, 58, 74))
    d.rectangle([cx - 52, 92, cx + 52, 98], fill=ORO_OSCURO)
    # La pantalla, grande y encendida.
    d.rounded_rectangle([cx - 60, 14, cx + 60, 88], 8, fill=(20, 26, 34))
    d.rounded_rectangle([cx - 54, 20, cx + 54, 82], 5, fill=(33, 96, 104))
    d.polygon([(cx - 54, 20), (cx - 20, 20), (cx - 54, 56)], fill=(140, 214, 222, 70))
    # El emblema: el rombo dorado que repite el marcador flotante.
    d.polygon([(cx, 34), (cx + 18, 51), (cx, 68), (cx - 18, 51)], fill=ORO)
    d.polygon([(cx, 40), (cx + 11, 51), (cx, 62), (cx - 11, 51)], fill=ORO_OSCURO)
    # Filo dorado del cuerpo.
    d.line([(cx - 48, 108), (cx - 56, alto - 34)], fill=ORO_OSCURO, width=2)
    d.line([(cx + 48, 108), (cx + 56, alto - 34)], fill=ORO_OSCURO, width=2)
    return img


def marca_reto(ancho=26, alto=34):
    """El marcador que flota encima de un reto y sube y baja.

    Es lo que hace que un reto se vea desde lejos, sin tener que dibujar un cartel.
    Lleva un rabito abajo para que se entienda que señala al mueble y no que es un
    adorno suelto.
    """
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = ancho // 2
    d.polygon([(cx, 0), (ancho - 1, 13), (cx, 26), (0, 13)], fill=ORO)
    d.polygon([(cx, 3), (ancho - 4, 13), (cx, 23), (3, 13)], fill=(24, 30, 38))
    d.polygon([(cx, 7), (ancho - 8, 13), (cx, 19), (7, 13)], fill=ORO)
    d.polygon([(cx - 4, 24), (cx + 4, 24), (cx, alto - 1)], fill=ORO)
    return img


def puerta_cristal(ancho=170, alto=116):
    """La puerta de cristal de la entrada: el cerrojo que abre el Acto 2."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, ancho - 1, alto - 1], fill=(38, 46, 56))
    d.rectangle([6, 6, ancho - 7, alto - 7], fill=(150, 176, 190))
    # Las dos hojas de cristal, con su reflejo diagonal.
    d.rectangle([10, 12, ancho // 2 - 2, alto - 8], fill=(120, 158, 176))
    d.rectangle([ancho // 2 + 2, 12, ancho - 11, alto - 8], fill=(120, 158, 176))
    d.polygon([(14, 12), (46, 12), (14, 70)], fill=(196, 220, 230, 90))
    d.polygon([(ancho // 2 + 6, 12), (ancho // 2 + 38, 12), (ancho // 2 + 6, 70)],
              fill=(196, 220, 230, 90))
    # Manillares.
    d.rectangle([ancho // 2 - 10, alto // 2, ancho // 2 - 4, alto // 2 + 30], fill=(60, 70, 82))
    d.rectangle([ancho // 2 + 4, alto // 2, ancho // 2 + 10, alto // 2 + 30], fill=(60, 70, 82))
    # Dintel dorado de la marca.
    d.rectangle([0, 0, ancho - 1, 6], fill=ORO_OSCURO)
    return img


def icono():
    """El icono del proyecto: el monograma de la torre sobre fondo corporativo."""
    svg = """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="20" fill="#26303d"/>
  <rect x="40" y="30" width="48" height="72" rx="4" fill="#1a2330" stroke="#d4a24a" stroke-width="2"/>
  <g fill="#2fa3a3">
    <rect x="48" y="40" width="10" height="10"/><rect x="70" y="40" width="10" height="10"/>
    <rect x="48" y="56" width="10" height="10"/><rect x="70" y="56" width="10" height="10"/>
    <rect x="48" y="72" width="10" height="10"/><rect x="70" y="72" width="10" height="10"/>
  </g>
  <rect x="57" y="86" width="14" height="16" fill="#d4a24a"/>
</svg>
"""
    ruta = os.path.join(os.path.dirname(ART), "icon.svg")
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(svg)
    print("   icon.svg")


def main():
    os.makedirs(ART, exist_ok=True)
    print("Generando arte en", ART)
    ancho, alto = tamano_mundo()
    print("   suelo a", ancho, "x", alto)
    guardar(suelo(ancho, alto), "suelo_oficina.png")
    guardar(alfombra(), "alfombra.png")
    guardar(alfombra(360, 232), "alfombra_pequena.png")
    guardar(muro_horizontal(), "muro_h.png")
    guardar(muro_vertical(), "muro_v.png")
    guardar(escritorio(), "escritorio.png")
    guardar(mostrador(), "mostrador.png")
    guardar(pantalla(), "pantalla.png")
    guardar(planta(), "planta.png")
    guardar(ascensor(), "ascensor.png")
    guardar(mesa_reunion(), "mesa_reunion.png")
    guardar(puerta_cristal(), "puerta_cristal.png")
    guardar(terminal(), "terminal.png")
    guardar(puesto_reto(), "puesto_reto.png")
    guardar(marca_reto(), "marca_reto.png")
    # OJO: la hoja del PERSONAJE no se genera aqui. Viene del pack de Andreas y la
    # monta tools/andreas.py, que escribe el mismo art/player_hoja.png. Si se
    # llamara aqui a personaje(), este generador pisaria al personaje de verdad.
    icono()
    print("Listo.")


if __name__ == "__main__":
    main()
