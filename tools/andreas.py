#!/usr/bin/env python3
"""Monta la hoja del personaje (Andreas) a partir del pack original.

    python tools/andreas.py

El pack viene en FICHEROS SUELTOS, una animacion por fichero y cada uno con su
numero de frames (abajo 7, arriba 6, lados 7, idle 4). El jugador del juego espera
UNA hoja con una fila por direccion, porque cambiar de direccion no puede depender
de cargar otra textura a mitad de partida.

Asi que esto no es "copiar el pack": es adaptarlo.

  1. Las casillas del pack son de 16x32 y el personaje llega siempre hasta el borde
     de abajo (los pies), asi que se puede recortar por rejilla sin calcular cajas.
  2. La fila de arriba tiene 6 frames y las demas 7. Se rellena repitiendo el
     ultimo, para que todas las filas midan lo mismo y el indice sea una cuenta
     limpia (fila * 7 + paso).
  3. El idle es una fila MAS, la quinta, y solo se usa de frente: es la unica que el
     pack trae dibujada. De espaldas o de lado, parado, se queda en el primer frame
     de su direccion, que ya es una pose de reposo.
  4. Los lados NO son espejo uno del otro en este pack: estan dibujados por
     separado, y por eso se copian tal cual en vez de voltear el izquierdo.

Escribe res://art/player_hoja.png (112x160).
"""
import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, "art", "fuente_andreas")
SALIDA = os.path.join(RAIZ, "art", "player_hoja.png")

CELDA_W, CELDA_H = 16, 32
COLUMNAS = 7

## fila -> (fichero, frames reales)
FILAS = [
    ("andreas walk down.png", 7),          # 0 abajo
    ("Andreas walk back.png", 6),          # 1 arriba
    ("andreas left walk.png", 7),          # 2 izquierda
    ("andreas right side walk.png", 7),    # 3 derecha
    ("andreas idle animation.png", 4),     # 4 reposo (solo de frente)
]


def main():
    hoja = Image.new("RGBA", (CELDA_W * COLUMNAS, CELDA_H * len(FILAS)), (0, 0, 0, 0))
    for fila, (nombre, frames) in enumerate(FILAS):
        ruta = os.path.join(FUENTE, nombre)
        if not os.path.isfile(ruta):
            raise SystemExit("falta " + ruta)
        tira = Image.open(ruta).convert("RGBA")
        if tira.height != CELDA_H:
            raise SystemExit("%s no mide %d de alto" % (nombre, CELDA_H))
        disponibles = tira.width // CELDA_W
        if disponibles < frames:
            raise SystemExit("%s trae %d frames y la tabla dice %d"
                             % (nombre, disponibles, frames))
        for i in range(COLUMNAS):
            # Los frames que faltan repiten el ultimo: el indice nunca se sale.
            origen = min(i, frames - 1)
            celda = tira.crop((origen * CELDA_W, 0, (origen + 1) * CELDA_W, CELDA_H))
            hoja.paste(celda, (i * CELDA_W, fila * CELDA_H))
        print("  fila %d  %-28s %d frames -> %d columnas" % (fila, nombre, frames, COLUMNAS))

    hoja.save(SALIDA)
    print("hoja:", hoja.size, "->", SALIDA)


if __name__ == "__main__":
    main()
