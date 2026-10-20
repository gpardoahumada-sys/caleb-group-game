#!/usr/bin/env python3
"""COMPANEROS DE OFICINA, a partir de la hoja de Andreas.

    python tools/npc_hojas.py

No es arte nuevo: es la MISMA hoja recoloreada. La hoja solo tiene 25 colores
opacos y estan agrupados -traje, pelo, piel-, asi que se pueden remapear por
grupos sin romper el dibujo ni el sombreado. Con eso salen companeros que caminan
con las mismas animaciones que el jugador, que es justo lo que hace que la oficina
parezca una oficina y no un muñeco suelto entre muebles.

Lo que hay que conservar al recolorear no es el rango de color, que se puede
inventar, sino la RELACION entre el tono claro y el oscuro del mismo dibujo: cada
color original se lleva al nuevo multiplicando por su propia luminancia relativa al
mas claro del grupo. Escalar por un rango fijo hunde las caras -dos tonos de piel
separados un 8% acaban separados un 45%-, y es lo primero que sale.

Y el grupo de la PIEL se separa del de la CAMISA por temperatura: la piel es calida
(rojo - azul alto) y el blanco es frio (rojo - azul negativo). Sin eso, la camisa se
recolorea como si fuera la cara.
"""
import os
from collections import Counter

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOJA = os.path.join(RAIZ, "art", "player_hoja.png")
SALIDA = os.path.join(RAIZ, "art")

# nombre, traje, pelo, piel
COMPANEROS = [
    ("ejecutivo", (108, 114, 126), (38, 33, 29), (222, 178, 152)),
    ("verde", (52, 88, 70), (168, 134, 78), (228, 190, 171)),
    ("granate", (118, 44, 52), (72, 40, 32), (168, 118, 88)),
    ("mayor", (168, 142, 108), (128, 128, 132), (226, 170, 156)),
]


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def grupos(hoja):
    """Los colores opacos repartidos en (traje, pelo, piel)."""
    traje, pelo, piel = set(), set(), set()
    c = Counter()
    for y in range(hoja.height):
        for x in range(hoja.width):
            px = hoja.getpixel((x, y))
            if px[3] > 200:
                c[px[:3]] += 1
    for col in c:
        r, g, b = col
        if b > r + 18 and b > 40:
            traje.add(col)
        elif r > 190 and g > 140 and r - b > 25:
            piel.add(col)
        elif r > b:
            pelo.add(col)
    return sorted(traje), sorted(pelo), sorted(piel)


def recolorear(hoja, traje, pelo, piel):
    t, h, s = grupos(hoja)
    mapa = {}
    for origen, base in ((t, traje), (h, pelo), (s, piel)):
        if not origen:
            continue
        tope = max(lum(c) for c in origen)
        for col in origen:
            f = lum(col) / tope if tope > 0 else 1.0
            mapa[col] = tuple(max(0, min(255, int(v * f))) for v in base)

    out = Image.new("RGBA", hoja.size, (0, 0, 0, 0))
    for y in range(hoja.height):
        for x in range(hoja.width):
            px = hoja.getpixel((x, y))
            if px[3] == 0:
                continue
            nuevo = mapa.get(px[:3])
            out.putpixel((x, y), (nuevo[0], nuevo[1], nuevo[2], px[3]) if nuevo else px)
    return out


def main():
    if not os.path.isfile(HOJA):
        raise SystemExit("falta la hoja base: " + HOJA)
    hoja = Image.open(HOJA).convert("RGBA")
    for nombre, traje, pelo, piel in COMPANEROS:
        out = recolorear(hoja, traje, pelo, piel)
        ruta = os.path.join(SALIDA, "npc_%s.png" % nombre)
        out.save(ruta)
        print("  npc_%-10s %s" % (nombre, out.size))
    print("Listo. Los companeros se montan con tools/npc_hojas.py")


if __name__ == "__main__":
    main()
