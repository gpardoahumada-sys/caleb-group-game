"""
ARTE DE LA CIUDAD (Acto 2).

Todo se dibuja aqui, con Pillow y sin packs externos, igual que el arte de la torre:
asi el proyecto se abre igual en cualquier maquina y los cambios de color son editar
una constante.

Lo que se genera:

    asfalto.png, acera.png, cesped.png   texturas repetibles del suelo
    linea.png                            la raya discontinua de la calzada
    coche.png, coche_npc*.png            coches vistos desde arriba (el del jugador mira
                                         hacia arriba, que es como Godot rota el nodo)
    semaforo_*.png                       el semaforo en sus tres estados
    arbol.png                            arbol de acera
    torre.png, banco.png, retail.png,
    salud.png, bloque.png                los edificios, ya al tamano que se colocan

    python tools/generar_ciudad.py
"""

import math
import os

from PIL import Image, ImageDraw

SALIDA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      "art", "ciudad")

# Paleta: la misma familia que la torre, un punto mas fria para que la calle se lea
# como "fuera del edificio" y no como otro piso.
ASFALTO = (33, 39, 48)
ASFALTO_CLARO = (40, 47, 58)
ACERA = (62, 72, 86)
ACERA_JUNTA = (48, 57, 70)
CESPED = (40, 66, 52)
CESPED_CLARO = (48, 78, 60)
ORO = (212, 162, 74)
ORO_OSCURO = (150, 112, 46)
TEAL = (47, 163, 163)
TEAL_OSCURO = (30, 106, 108)
BLANCO = (226, 232, 238)
ROJO = (198, 74, 66)
AMBAR = (222, 164, 66)
VERDE = (86, 190, 118)
CRISTAL = (58, 96, 116)
CRISTAL_OSCURO = (34, 56, 72)
HORMIGON = (86, 96, 110)
HORMIGON_OSCURO = (62, 70, 82)
TEJADO = (44, 52, 64)


def guardar(img, nombre):
    os.makedirs(SALIDA, exist_ok=True)
    img.save(os.path.join(SALIDA, nombre))
    print("  ", nombre, img.size)


def grano(img, cantidad=900, alfa=10):
    """Un polvo de ruido para que una superficie plana no se vea plana."""
    d = ImageDraw.Draw(img, "RGBA")
    import random
    rnd = random.Random(7)
    for _ in range(cantidad):
        x = rnd.randrange(img.width)
        y = rnd.randrange(img.height)
        d.point((x, y), fill=(255, 255, 255, alfa))
    return img


# --------------------------------------------------------------------- el suelo

def asfalto(lado=128):
    img = Image.new("RGBA", (lado, lado), ASFALTO)
    d = ImageDraw.Draw(img, "RGBA")
    import random
    rnd = random.Random(3)
    # Manchas de rodadura: unas bandas apenas mas claras.
    for _ in range(18):
        x = rnd.randrange(lado)
        y = rnd.randrange(lado)
        d.ellipse([x, y, x + rnd.randrange(18, 46), y + rnd.randrange(10, 26)],
                  fill=(ASFALTO_CLARO[0], ASFALTO_CLARO[1], ASFALTO_CLARO[2], 40))
    return grano(img, 1400, 12)


def acera(lado=64):
    img = Image.new("RGBA", (lado, lado), ACERA)
    d = ImageDraw.Draw(img, "RGBA")
    # Losas: cuatro cuadrados por textura.
    paso = lado // 2
    for i in range(3):
        for j in range(3):
            d.rectangle([i * paso, j * paso, i * paso + paso - 1, j * paso + paso - 1],
                        outline=ACERA_JUNTA, width=1)
    return grano(img, 400, 8)


def cesped(lado=64):
    img = Image.new("RGBA", (lado, lado), CESPED)
    d = ImageDraw.Draw(img, "RGBA")
    import random
    rnd = random.Random(11)
    for _ in range(60):
        x = rnd.randrange(lado)
        y = rnd.randrange(lado)
        d.line([(x, y), (x + 1, y - rnd.randrange(2, 5))], fill=CESPED_CLARO, width=1)
    return img


def linea(ancho=8, alto=34):
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, ancho - 1, alto - 1], fill=(226, 226, 214, 150))
    return img


# -------------------------------------------------------------------- los coches

def coche(color, ancho=44, alto=76, jugador=True):
    """Coche visto desde arriba, mirando HACIA ARRIBA.

    Hacia arriba porque en Godot `rotation = 0` es el eje -Y, asi que el nodo del
    coche y su dibujo coinciden sin correcciones y el giro no se pelea con nada.
    """
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    cx = ancho // 2

    # Sombra.
    d.rounded_rectangle([3, 6, ancho - 3, alto - 2], 14, fill=(10, 14, 20, 110))
    # Carroceria.
    d.rounded_rectangle([2, 2, ancho - 3, alto - 6], 13, fill=color)
    # Morro y capo, un punto mas claros.
    claro = tuple(min(255, c + 26) for c in color[:3])
    d.rounded_rectangle([5, 4, ancho - 6, 26], 10, fill=claro)
    # Parabrisas y luna trasera.
    d.rounded_rectangle([7, 22, ancho - 8, 40], 7, fill=CRISTAL_OSCURO)
    d.rounded_rectangle([7, 50, ancho - 8, 62], 6, fill=CRISTAL_OSCURO)
    # Techo.
    d.rectangle([8, 40, ancho - 9, 50], fill=color)
    # Ruedas.
    for y in (18, alto - 24):
        d.rounded_rectangle([0, y, 4, y + 16], 2, fill=(18, 20, 24))
        d.rounded_rectangle([ancho - 5, y, ancho - 1, y + 16], 2, fill=(18, 20, 24))
    # Faros y pilotos.
    d.rectangle([7, 2, 14, 5], fill=(248, 240, 200))
    d.rectangle([ancho - 15, 2, ancho - 8, 5], fill=(248, 240, 200))
    d.rectangle([7, alto - 8, 13, alto - 5], fill=(196, 62, 54))
    d.rectangle([ancho - 14, alto - 8, ancho - 8, alto - 5], fill=(196, 62, 54))
    if jugador:
        # Una franja dorada: el coche del jugador tiene que reconocerse de un vistazo
        # entre el trafico.
        d.rectangle([4, 58, ancho - 5, 61], fill=ORO)
    return img


def semaforo(estado, ancho=26, alto=68):
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([1, alto - 8, ancho - 1, alto - 1], fill=(10, 14, 20, 120))
    d.rectangle([ancho // 2 - 2, 20, ancho // 2 + 2, alto - 4], fill=HORMIGON_OSCURO)
    d.rounded_rectangle([3, 2, ancho - 3, 38], 4, fill=(24, 28, 34))
    luces = [(9, ROJO), (21, AMBAR), (33, VERDE)]
    for y, color in luces:
        encendida = (estado == "rojo" and color == ROJO) or \
                    (estado == "ambar" and color == AMBAR) or \
                    (estado == "verde" and color == VERDE)
        relleno = color if encendida else tuple(int(c * 0.22) for c in color)
        d.ellipse([ancho // 2 - 6, y, ancho // 2 + 6, y + 12], fill=relleno)
    return img


def plaza(lado=64):
    """El suelo de la parcela: pavimento, no cesped.

    Una manzana entera de hierba con un edificio en medio se lee como un parque, no
    como una ciudad. El verde se queda para los parterres.
    """
    img = Image.new("RGBA", (lado, lado), (54, 60, 72))
    d = ImageDraw.Draw(img, "RGBA")
    paso = lado // 2
    for i in range(3):
        for j in range(3):
            d.rectangle([i * paso, j * paso, i * paso + paso - 1, j * paso + paso - 1],
                        outline=(44, 50, 61), width=1)
    return grano(img, 300, 10)


def aparcamiento(ancho=420, alto=150):
    """Plazas de aparcamiento: lo que hace que un hueco vacio parezca urbano."""
    img = Image.new("RGBA", (ancho, alto), (46, 52, 63, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(10, ancho - 10, 52):
        d.line([(x, 12), (x, alto - 12)], fill=(200, 200, 190, 120), width=2)
    return img


def arbol(ancho=60, alto=68):
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    cx = ancho // 2
    d.ellipse([6, alto - 12, ancho - 4, alto - 2], fill=(12, 18, 16, 120))
    d.rectangle([cx - 3, 40, cx + 3, alto - 8], fill=(58, 44, 34))
    d.ellipse([4, 4, ancho - 4, 48], fill=(46, 92, 62))
    d.ellipse([9, 12, ancho - 12, 42], fill=(56, 110, 74))
    d.ellipse([16, 8, 30, 26], fill=(70, 130, 88))
    return img


# ----------------------------------------------------------------- los edificios

def _tejado(img, d, caja, tono=TEJADO):
    """El tejado de un edificio: el cuerpo oscuro, el pretil claro y el grano."""
    d.rectangle(caja, fill=tono)
    d.rectangle([caja[0], caja[1], caja[2], caja[1] + 10], fill=tuple(
        min(255, c + 18) for c in tono))
    d.rectangle(caja, outline=tuple(min(255, c + 30) for c in tono), width=2)


def _fachada(d, caja, color, ventanas, filas=2, columnas=None, alfa=255):
    """La fachada se ve como una banda al pie del edificio, con ventanas.

    Es el mismo truco que las mesas de la torre: un poco de frente para que el volumen
    se entienda sin salir de la cenital.
    """
    x0, y0, x1, y1 = caja
    d.rectangle([x0, y1 - filas * 26, x1, y1], fill=color)
    if columnas is None:
        columnas = max(3, int((x1 - x0) // 70))
    ancho = (x1 - x0) / columnas
    for f in range(filas):
        for c in range(columnas):
            vx = x0 + c * ancho + ancho * 0.22
            vy = y1 - filas * 26 + f * 26 + 6
            d.rectangle([vx, vy, vx + ancho * 0.56, vy + 13],
                        fill=(ventanas[0], ventanas[1], ventanas[2], alfa))


def _equipos(d, caja, cantidad=3, semilla=1):
    """Climatizadores y respiraderos en el tejado.

    No son adorno: sin ellos un tejado es una losa de color, y desde arriba todas las
    azoteas se parecen. Es lo que hace que un edificio se lea como edificio.
    """
    import random
    rnd = random.Random(semilla)
    x0, y0, x1, y1 = caja
    for _ in range(cantidad):
        w = rnd.randrange(46, 78)
        h = rnd.randrange(36, 58)
        x = rnd.randrange(int(x0 + 24), int(max(x0 + 25, x1 - w - 24)))
        y = rnd.randrange(int(y0 + 24), int(max(y0 + 25, y1 - h - 24)))
        d.rounded_rectangle([x, y, x + w, y + h], 4, fill=HORMIGON_OSCURO)
        d.ellipse([x + w * 0.28, y + h * 0.24, x + w * 0.72, y + h * 0.76],
                  fill=(28, 33, 40))


def torre(ancho=620, alto=520):
    """La Torre Caleb Group: el edificio del que sales y al que vuelves."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([6, 10, ancho - 6, alto - 2], 10, fill=(10, 14, 20, 130))
    _tejado(img, d, (0, 0, ancho - 1, alto - 60))
    # Almenas del pretil.
    for x in range(14, ancho - 20, 46):
        d.rectangle([x, 4, x + 18, 12], fill=HORMIGON)
    # El logo: el rombo dorado, el mismo del emblema de los retos.
    cx, cy = ancho // 2, 190
    d.polygon([(cx, cy - 78), (cx + 76, cy), (cx, cy + 78), (cx - 76, cy)], fill=ORO)
    d.polygon([(cx, cy - 46), (cx + 44, cy), (cx, cy + 46), (cx - 44, cy)], fill=TEJADO)
    # Climatizadores y lucernarios en el tejado.
    for x in (54, 150, ancho - 200, ancho - 104):
        d.rounded_rectangle([x, 56, x + 64, 104], 4, fill=HORMIGON_OSCURO)
        d.ellipse([x + 18, 70, x + 46, 92], fill=(30, 34, 40))
    # Fachada de cristal, dos plantas.
    _fachada(d, (0, 0, ancho - 1, alto - 1), (36, 46, 58), CRISTAL, filas=2)
    d.rectangle([0, alto - 60, ancho - 1, alto - 58], fill=ORO_OSCURO)
    # Entrada.
    d.rectangle([cx - 52, alto - 34, cx + 52, alto - 2], fill=(28, 36, 46))
    d.rectangle([cx - 52, alto - 34, cx + 52, alto - 2], outline=ORO, width=2)
    return img


def banco(ancho=620, alto=460):
    """FinBank: piedra, columnas y cristal frio."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([6, 10, ancho - 6, alto - 2], 8, fill=(10, 14, 20, 130))
    _tejado(img, d, (0, 0, ancho - 1, alto - 56), (48, 56, 70))
    # Columnata: la seña de identidad de un banco.
    for x in range(30, ancho - 40, 74):
        d.rectangle([x, 26, x + 12, alto - 56], fill=HORMIGON)
        d.rectangle([x - 4, 26, x + 16, 34], fill=(110, 120, 134))
    _equipos(d, (0, 90, ancho - 1, alto - 70), 3, 21)
    _fachada(d, (0, 0, ancho - 1, alto - 1), (44, 52, 66), (86, 132, 168), filas=2)
    d.rectangle([ancho // 2 - 46, alto - 40, ancho // 2 + 46, alto - 2], fill=(30, 38, 50))
    d.rectangle([ancho // 2 - 46, alto - 40, ancho // 2 + 46, alto - 2],
                outline=ORO_OSCURO, width=2)
    return img


def retail(ancho=620, alto=460):
    """OmniRetail: nave ancha con lucernario y mucho cristal turquesa."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([6, 10, ancho - 6, alto - 2], 8, fill=(10, 14, 20, 130))
    _tejado(img, d, (0, 0, ancho - 1, alto - 54), (40, 48, 60))
    # El lucernario: una franja de cristal en el tejado.
    d.rounded_rectangle([60, 44, ancho - 60, 128], 8, fill=TEAL_OSCURO)
    d.rounded_rectangle([60, 44, ancho - 60, 128], 8, outline=TEAL, width=2)
    for x in range(80, ancho - 70, 60):
        d.line([(x, 48), (x, 124)], fill=(70, 190, 190, 90), width=2)
    _equipos(d, (0, 140, ancho - 1, alto - 70), 3, 33)
    _fachada(d, (0, 0, ancho - 1, alto - 1), (40, 50, 62), (70, 176, 176), filas=2)
    # Toldo de la entrada.
    d.rectangle([ancho // 2 - 90, alto - 46, ancho // 2 + 90, alto - 26], fill=TEAL)
    d.rectangle([ancho // 2 - 90, alto - 46, ancho // 2 + 90, alto - 26],
                outline=ORO_OSCURO, width=2)
    return img


def salud(ancho=620, alto=460):
    """MediHealth: blanco, limpio y una cruz dorada."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([6, 10, ancho - 6, alto - 2], 8, fill=(10, 14, 20, 130))
    _tejado(img, d, (0, 0, ancho - 1, alto - 56), (78, 86, 98))
    # La cruz, en el tejado.
    cx, cy = ancho // 2, 130
    d.rectangle([cx - 20, cy - 62, cx + 20, cy + 62], fill=BLANCO)
    d.rectangle([cx - 62, cy - 20, cx + 62, cy + 20], fill=BLANCO)
    d.rectangle([cx - 12, cy - 54, cx + 12, cy + 54], fill=ORO)
    d.rectangle([cx - 54, cy - 12, cx + 54, cy + 12], fill=ORO)
    _equipos(d, (0, 200, ancho - 1, alto - 70), 2, 47)
    _fachada(d, (0, 0, ancho - 1, alto - 1), (74, 82, 94), (150, 190, 200), filas=2)
    d.rectangle([ancho // 2 - 50, alto - 40, ancho // 2 + 50, alto - 2], fill=(36, 44, 56))
    d.rectangle([ancho // 2 - 50, alto - 40, ancho // 2 + 50, alto - 2],
                outline=ORO_OSCURO, width=2)
    return img


def bloque(ancho=460, alto=380):
    """Edificio de relleno: no se visita, esta para que la ciudad sea una ciudad."""
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([5, 8, ancho - 5, alto - 2], 6, fill=(10, 14, 20, 120))
    _tejado(img, d, (0, 0, ancho - 1, alto - 50), (46, 54, 66))
    for x in (26, ancho - 92):
        d.rounded_rectangle([x, 34, x + 56, 78], 4, fill=HORMIGON_OSCURO)
    _equipos(d, (0, 90, ancho - 1, alto - 60), 2, 59)
    _fachada(d, (0, 0, ancho - 1, alto - 1), (40, 48, 60), (70, 120, 140), filas=2)
    return img


def main():
    guardar(asfalto(), "asfalto.png")
    guardar(acera(), "acera.png")
    guardar(cesped(), "cesped.png")
    guardar(plaza(), "plaza.png")
    guardar(aparcamiento(), "aparcamiento.png")
    guardar(linea(), "linea.png")
    guardar(coche((34, 128, 132)), "coche.png")
    guardar(coche((150, 70, 62), jugador=False), "coche_npc1.png")
    guardar(coche((70, 120, 96), jugador=False), "coche_npc2.png")
    guardar(coche((120, 110, 70), jugador=False), "coche_npc3.png")
    for estado in ("rojo", "ambar", "verde"):
        guardar(semaforo(estado), "semaforo_%s.png" % estado)
    guardar(arbol(), "arbol.png")
    guardar(torre(), "torre.png")
    guardar(banco(), "banco.png")
    guardar(retail(), "retail.png")
    guardar(salud(), "salud.png")
    guardar(bloque(), "bloque.png")


if __name__ == "__main__":
    main()
