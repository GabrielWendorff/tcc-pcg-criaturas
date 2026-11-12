"""Texto na fonte pixel do jogo (arte/ui/fonte_pixel.fnt, formato BMFont), em Python.

O banner e o poster usam a mesma fonte das telas do jogo. Renderiza na folha 1x e amplia
por um fator inteiro, sem suavizar: e assim que o jogo usa as folhas 2x e 3x.
"""
import os
import re

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FNT = os.path.join(RAIZ, "arte", "ui", "fonte_pixel.fnt")


class FontePixel:
    def __init__(self, caminho=FNT):
        texto = open(caminho, encoding="utf-8").read()
        self.altura_linha = int(re.search(r"lineHeight=(\d+)", texto).group(1))
        pagina = re.search(r'page id=0 file="([^"]+)"', texto).group(1)
        self.folha = Image.open(os.path.join(os.path.dirname(caminho), pagina)).convert("RGBA")
        self.chars = {}
        for m in re.finditer(r"char id=(\d+) x=(\d+) y=(\d+) width=(\d+) height=(\d+) "
                             r"xoffset=(-?\d+) yoffset=(-?\d+) xadvance=(\d+)", texto):
            cid, x, y, w, h, xo, yo, adv = (int(v) for v in m.groups())
            self.chars[cid] = (x, y, w, h, xo, yo, adv)

    def largura(self, texto):
        return sum(self.chars.get(ord(c), self.chars[ord("?")])[6] for c in texto)

    def mascara(self, texto):
        """Alfa da linha de texto, na escala 1."""
        img = Image.new("L", (max(1, self.largura(texto)), self.altura_linha), 0)
        x = 0
        for c in texto:
            gx, gy, w, h, xo, yo, adv = self.chars.get(ord(c), self.chars[ord("?")])
            if w and h:
                glifo = self.folha.crop((gx, gy, gx + w, gy + h)).getchannel("A")
                img.paste(glifo, (x + xo, yo), glifo)
            x += adv
        return img

    def render(self, texto, cor, escala=1, sombra=(31, 21, 15), deslocamento=1):
        """RGBA do texto colorido, com sombra deslocada (como TemaEncontro.rotulo_sombreado)."""
        m = self.mascara(texto)
        d = deslocamento if sombra is not None else 0
        img = Image.new("RGBA", (m.width + d, m.height + d), (0, 0, 0, 0))
        if sombra is not None:
            img.paste(Image.new("RGBA", m.size, tuple(sombra) + (255,)), (d, d), m)
        img.paste(Image.new("RGBA", m.size, tuple(cor) + (255,)), (0, 0), m)
        if escala != 1:
            img = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
        return img
