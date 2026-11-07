r"""
mundo_lib.py — primitivas de pixel art isometrica para os tiles e props do mundo.

Geometria canonica do projeto: losango 32x16 (proporcao 2:1). A celula (0,0) de
uma TileMapLayer isometrica em Godot ocupa exatamente esse losango, e todo asset
de chao e desenhado dentro dele.

Diferenca deliberada em relacao a arte de criaturas (arte/corpos, arte/garras):
aquelas sao MASCARAS INDEXADAS, porque a cor da criatura e um atributo derivado
sorteado (RF04) e so pode ser resolvida em tempo de execucao. O mundo da vila e
conteudo AUTORAL fixo (Camada 1) — sua cor nao vem de tabela nenhuma —, entao os
PNGs daqui ja saem coloridos e nao passam pelo paleta_indexada.gdshader.

Convencao de luz: sol no alto a ESQUERDA. A mesma de corpos_lib.rasterizar, para
que criatura e cenario nao briguem quando aparecerem no mesmo quadro.

Sistema de coordenadas do losango (celula 32x16):

        (15,0)                 aresta NO = vizinho (x-1, y)
      .   /\   .               aresta NE = vizinho (x, y-1)
   NO/         \NE             aresta SE = vizinho (x+1, y)
    /           \              aresta SO = vizinho (x, y+1)
   (0,7)     (31,7)
    \           /              A ordem dos bits em `mascara_bordas` e
   SO\         /SE             NO=1, NE=2, SE=4, SO=8 — a mesma que
      .   \/   .               MundoIso._mascara_de_bordas() calcula em
        (15,15)                GDScript a partir da grade de terreno.
"""

import math
import os

from PIL import Image

# --------------------------------------------------------------- geometria
LARG = 32          # largura do losango, em pixels
ALT = 16           # altura do losango
CX = (LARG - 1) / 2.0
CY = (ALT - 1) / 2.0

# bits de `mascara_bordas`
NO, NE, SE, SO = 1, 2, 4, 8
BORDAS = (NO, NE, SE, SO)

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR_MUNDO = os.path.join(RAIZ, "arte", "mundo")
DIR_PREVIEW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview")


def losango(larg=LARG, alt=ALT, ox=0, oy=0):
    """Runs (y, x0, x1) do losango cheio. Formato canonico 2:1 do pixel art iso:
    a linha do topo tem 4px e cada linha desce 2px de cada lado."""
    runs = []
    meio = alt // 2
    for y in range(alt):
        k = y if y < meio else alt - 1 - y
        passo = larg // (2 * meio)
        x0 = larg // 2 - 2 - passo * k
        x1 = larg // 2 + 1 + passo * k
        runs.append((oy + y, ox + x0, ox + x1))
    return runs


# Semi-eixos usados nas contas de aresta. Sao 16,5 e 8,5 — e nao 16 e 8 — para
# que o losango matematico coincida com a MASCARA em escada de losango(): a
# escada de 2px por linha e um pouco mais larga que a elipse ideal, e com 16/8
# os pixels extremos (0,7) e (31,8) cairiam de fora.
SEMI_X, SEMI_Y = 16.5, 8.5

# Mascara exata da celula, derivada da mesma tabela de runs que o desenho usa.
MASCARA = frozenset(
    (x, y) for y, x0, x1 in losango() for x in range(x0, x1 + 1)
)


def distancias_borda(x, y):
    """Distancia aproximada, em pixels, de (x,y) a cada uma das 4 arestas.

    O losango e o conjunto max(|a|,|b|) <= 1 com a = px + py e b = px - py, onde
    px = dx/SEMI_X e py = dy/SEMI_Y. Cada aresta e um dos quatro extremos:
    a=-1 e a NO, b=+1 a NE, a=+1 a SE, b=-1 a SO. O fator k converte a unidade
    de `a`/`b` para pixels (|grad a| = hypot(1/SEMI_X, 1/SEMI_Y)).
    """
    px = (x - CX) / SEMI_X
    py = (y - CY) / SEMI_Y
    a, b = px + py, px - py
    k = 1.0 / math.hypot(1.0 / SEMI_X, 1.0 / SEMI_Y)
    return {NO: (1.0 + a) * k, NE: (1.0 - b) * k,
            SE: (1.0 - a) * k, SO: (1.0 + b) * k}


def borda_mais_proxima(x, y):
    """Qual das 4 arestas esta mais perto, e a que distancia."""
    d = distancias_borda(x, y)
    lado = min(d, key=d.get)
    return lado, d[lado]


def dentro(x, y):
    """True se o pixel pertence a celula. Usa a mascara, nao a inequacao: e o
    desenho que manda, para que borda e preenchimento nunca discordem em 1px."""
    return (int(x), int(y)) in MASCARA


# --------------------------------------------------------------- cor
def _hsv(c, ds=0.0, dv=0.0):
    import colorsys
    r, g, b = (v / 255.0 for v in c[:3])
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = min(1.0, max(0.0, s + ds))
    v = min(1.0, max(0.0, v + dv))
    return tuple(int(round(v * 255)) for v in colorsys.hsv_to_rgb(h, s, v))


def rampa(base, n=4, espalhamento=0.16):
    """Rampa de n tons a partir de uma cor base, do mais escuro ao mais claro.

    A sombra ganha saturacao e o brilho perde: e o que impede que os quatro tons
    leiam como a mesma cor com opacidade diferente, defeito classico de rampa
    gerada so por multiplicacao de valor.
    """
    tons = []
    for i in range(n):
        t = (i / (n - 1)) - 0.5 if n > 1 else 0.0
        tons.append(_hsv(base, ds=-0.22 * t, dv=espalhamento * 2 * t))
    return tons


# Paleta do mundo. Uma entrada por material; cada uma vira uma rampa de 4 tons
# na ordem [escuro, sombra, base, brilho].
MATERIAIS = {
    "grama":       (0x5f, 0x93, 0x4b),
    "grama_alta":  (0x2d, 0x5e, 0x33),
    "caminho":     (0xa8, 0x8c, 0x62),
    "terra":       (0x93, 0x8d, 0x82),
    "agua":        (0x3a, 0x84, 0xb0),
    "areia":       (0xd0, 0xbd, 0x8b),
    "rocha":       (0x4c, 0x4e, 0x5e),
    "madeira":     (0x8a, 0x60, 0x3e),
    "tronco":      (0x63, 0x45, 0x2d),
    "folha":       (0x46, 0x84, 0x47),
    "folha_fria":  (0x38, 0x6e, 0x5c),
    "parede":      (0xd8, 0xcb, 0xac),
    "telha_rubi":  (0xb0, 0x50, 0x46),
    "telha_ardosia": (0x5c, 0x6b, 0x8c),
    "telha_musgo": (0x66, 0x86, 0x54),
    "palha":       (0xc4, 0xa0, 0x59),
    # --- distrito industrial, ribeira e fazenda -------------------------------
    # Entraram com a expansao do mundo. Sao MATERIAIS, nao regioes: o que
    # distingue o distrito da vila e o material de que ele e feito (pedra de
    # calcada, tijolo, zinco, ferrugem), nao uma paleta paralela — e por isso que
    # as duas regioes continuam parecendo o mesmo mundo.
    "calcada":     (0x8e, 0x8c, 0x8a),
    "lavoura":     (0x6f, 0x4f, 0x36),
    "tabua":       (0x9a, 0x74, 0x4a),
    "tijolo":      (0x9c, 0x5a, 0x48),
    "metal":       (0x8d, 0x96, 0xa2),
    "ferrugem":    (0x9a, 0x5f, 0x33),
    "milho":       (0xd2, 0xbb, 0x5c),
    # --- chegada de onibus (cutscene de abertura) -----------------------------
    "onibus":      (0xd8, 0x9a, 0x3c),
    "vidro":       (0x86, 0xa9, 0xbe),
}

CONTORNO = (0x24, 0x22, 0x30)      # contorno geral dos props
CONTORNO_SUAVE = (0x39, 0x38, 0x47)

RAMPAS = {nome: rampa(cor) for nome, cor in MATERIAIS.items()}


def tom(material, i):
    """Tom i da rampa do material: 0 escuro, 1 sombra, 2 base, 3 brilho."""
    return RAMPAS[material][i]


# --------------------------------------------------------------- tela
class Tela:
    """Buffer RGBA com origem no canto superior esquerdo."""

    def __init__(self, larg, alt):
        self.larg, self.alt = larg, alt
        self.px = [[None] * larg for _ in range(alt)]

    def por(self, x, y, cor):
        x, y = int(x), int(y)
        if 0 <= x < self.larg and 0 <= y < self.alt and cor is not None:
            self.px[y][x] = cor

    def ler(self, x, y):
        x, y = int(x), int(y)
        if 0 <= x < self.larg and 0 <= y < self.alt:
            return self.px[y][x]
        return None

    def runs(self, runs, cor):
        for y, x0, x1 in runs:
            for x in range(int(x0), int(x1) + 1):
                self.por(x, y, cor)

    def ret(self, x0, y0, x1, y1, cor):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.por(x, y, cor)

    def linha(self, x0, y0, x1, y1, cor):
        """Bresenham."""
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.por(x0, y0, cor)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def elipse(self, cx, cy, rx, ry, cor):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            d = 1.0 - ((y - cy) / (ry + 0.5)) ** 2
            if d <= 0:
                continue
            w = rx * math.sqrt(d)
            for x in range(int(round(cx - w)), int(round(cx + w)) + 1):
                self.por(x, y, cor)

    def poligono(self, pts, cor):
        """Preenchimento por varredura de um poligono convexo ou concavo simples.
        E com ele que as faces de casas e penhascos sao pintadas: cada face e um
        quadrilatero em projecao isometrica, nao um retangulo."""
        if len(pts) < 3:
            return
        ys = [p[1] for p in pts]
        for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
            cortes = []
            for i in range(len(pts)):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % len(pts)]
                if y0 == y1:
                    continue
                if min(y0, y1) <= y < max(y0, y1):
                    t = (y - y0) / (y1 - y0)
                    cortes.append(x0 + (x1 - x0) * t)
            cortes.sort()
            for i in range(0, len(cortes) - 1, 2):
                for x in range(int(round(cortes[i])), int(round(cortes[i + 1])) + 1):
                    self.por(x, y, cor)

    def ocupado(self, x, y):
        return self.ler(x, y) is not None

    def contornar(self, cor=CONTORNO, cantos=False):
        """Contorno externo de 1px em volta de tudo que esta pintado."""
        viz = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if cantos:
            viz += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        borda = []
        for y in range(self.alt):
            for x in range(self.larg):
                if self.ocupado(x, y):
                    continue
                if any(self.ocupado(x + dx, y + dy) for dx, dy in viz):
                    borda.append((x, y))
        for x, y in borda:
            self.por(x, y, cor)

    def sombra_chao(self, cx, cy, rx, ry, alpha=90):
        """Elipse de sombra semitransparente sob um prop. Desenhada por baixo:
        so pinta onde ainda nao ha pixel."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            d = 1.0 - ((y - cy) / (ry + 0.5)) ** 2
            if d <= 0:
                continue
            w = rx * math.sqrt(d)
            for x in range(int(round(cx - w)), int(round(cx + w)) + 1):
                if not self.ocupado(x, y):
                    self.por(x, y, (0x1c, 0x22, 0x2e, alpha))

    def imagem(self):
        img = Image.new("RGBA", (self.larg, self.alt), (0, 0, 0, 0))
        pon = img.load()
        for y in range(self.alt):
            for x in range(self.larg):
                c = self.px[y][x]
                if c is None:
                    continue
                pon[x, y] = c if len(c) == 4 else c + (255,)
        return img

    def salvar(self, caminho):
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        self.imagem().save(caminho)


# --------------------------------------------------------------- texturas
def ruido(x, y, semente=0):
    """Hash inteiro deterministico em [0,1). Sem estado global: o mesmo (x,y)
    devolve sempre o mesmo valor, entao regerar a arte nao muda um pixel."""
    h = (x * 374761393 + y * 668265263 + semente * 2147483647) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65536.0


BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def bayer(x, y):
    """Limiar ordenado em [0,1) — dithering sem ruido temporal."""
    return BAYER4[y % 4][x % 4] / 16.0


def salvar_folha_contato(nomes_e_imagens, caminho, colunas=8, fundo=(0x1b, 0x1e, 0x26)):
    """Folha de conferencia visual. Nao e consumida pelo jogo — fica em
    tools/arte/_preview/, que tem .gdignore."""
    if not nomes_e_imagens:
        return
    cel_l = max(im.width for _, im in nomes_e_imagens) + 8
    cel_a = max(im.height for _, im in nomes_e_imagens) + 8
    linhas = (len(nomes_e_imagens) + colunas - 1) // colunas
    folha = Image.new("RGBA", (cel_l * colunas, cel_a * linhas), fundo + (255,))
    for i, (_, im) in enumerate(nomes_e_imagens):
        cx = (i % colunas) * cel_l + (cel_l - im.width) // 2
        cy = (i // colunas) * cel_a + (cel_a - im.height) // 2
        folha.alpha_composite(im, (cx, cy))
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    escala = max(1, 512 // max(folha.width, 1))
    folha.resize((folha.width * escala, folha.height * escala),
                 Image.NEAREST).save(caminho)
