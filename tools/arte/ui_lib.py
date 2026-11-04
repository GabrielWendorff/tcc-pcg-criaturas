r"""
ui_lib.py — primitivas de pixel art para a INTERFACE (arte/ui, arte/itens).

Terceira familia de arte do projeto, ao lado das duas que ja existiam:

    arte/corpos, arte/garras   mascaras INDEXADAS  (cor resolvida no shader,
                               porque a cor da criatura e atributo sorteado)
    arte/mundo                 pixel art COLORIDA  (vila autoral, cor fixa)
    arte/ui, arte/itens        pixel art COLORIDA  <- esta

A interface e colorida pelo mesmo motivo do mundo: um icone de osso nao tem
matiz sorteado. A unica excecao continua sendo a criatura desenhada dentro da
ficha, que passa pelo paleta_indexada.gdshader como em qualquer outra tela.

CONVENCOES
----------
Luz no alto a ESQUERDA — a mesma de corpos_lib e mundo_lib, para que icone,
cenario e criatura nao briguem no mesmo quadro.

Tudo e autorado em pixels de TELA 1:1. Nada aqui e reescalado em tempo de
execucao: uma borda de 3px no PNG e uma borda de 3px na tela. E o que mantem o
pixel quadrado sem depender de zoom inteiro na interface — ver a nota sobre
window/stretch/scale_mode em docs/pendencias.md.

PALETA
------
Madeira + pergaminho, quente e tatil, no espirito dos RPGs pixel art
aconchegantes. Deliberadamente MAIS QUENTE que o azul-ardosia do
bestiario_viewer: aquela e uma tela de analise (RF07/RF08), esta e o jogo. O que
as duas continuam compartilhando e a semantica das cores de estado — verde
sucesso, vermelho falha, dourado selecao —, para que a mesma cor nunca signifique
duas coisas no projeto.
"""

import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR_UI = os.path.join(RAIZ, "arte", "ui")
DIR_ITENS = os.path.join(RAIZ, "arte", "itens")

# ------------------------------------------------------------------ paleta
P = {
    # madeira (molduras)
    "contorno":   (31, 21, 15, 255),      # quase preto, quente
    "madeira_e":  (74, 49, 33, 255),      # sombra
    "madeira":    (107, 70, 48, 255),
    "madeira_c":  (138, 92, 62, 255),     # luz
    # pergaminho (interior dos paineis)
    "perg_e":     (176, 138, 94, 255),
    "perg":       (232, 213, 168, 255),
    "perg_c":     (247, 235, 205, 255),
    # tinta sobre pergaminho
    "tinta":      (58, 42, 28, 255),
    "tinta_c":    (110, 86, 62, 255),
    # interior escuro (cartoes da roda)
    "noite_e":    (24, 22, 32, 255),
    "noite":      (40, 36, 54, 255),
    "noite_c":    (58, 52, 76, 255),
    # estados
    "ouro_e":     (168, 118, 26, 255),
    "ouro":       (242, 193, 78, 255),
    "ouro_c":     (255, 233, 168, 255),
    "verde_e":    (46, 96, 46, 255),
    "verde":      (91, 191, 91, 255),
    "verde_c":    (150, 224, 130, 255),
    "vermelho_e": (128, 42, 38, 255),
    "vermelho":   (225, 75, 75, 255),
    "vermelho_c": (245, 140, 120, 255),
    "azul_e":     (40, 58, 130, 255),
    "azul":       (75, 110, 232, 255),
    "azul_c":     (140, 175, 255, 255),
    "ciano_e":    (34, 118, 118, 255),
    "ciano":      (75, 214, 214, 255),
    "ciano_c":    (168, 245, 245, 255),
    "roxo_e":     (86, 44, 138, 255),
    "roxo":       (155, 91, 232, 255),
    "roxo_c":     (200, 160, 255, 255),
    "aco_e":      (78, 84, 98, 255),
    "aco":        (126, 134, 152, 255),
    "aco_c":      (188, 196, 214, 255),
    "osso_e":     (176, 168, 148, 255),
    "osso":       (226, 220, 202, 255),
    "osso_c":     (252, 250, 242, 255),
    "carne_e":    (140, 46, 44, 255),
    "carne":      (198, 74, 68, 255),
    "carne_c":    (232, 130, 118, 255),
    "terra_e":    (92, 62, 38, 255),
    "terra":      (138, 90, 60, 255),
    "terra_c":    (178, 128, 88, 255),
    "folha_e":    (46, 104, 52, 255),
    "folha":      (86, 158, 74, 255),
    "folha_c":    (144, 202, 110, 255),
    "vazio":      (0, 0, 0, 0),
}


def cor(nome):
    return P[nome]


# ------------------------------------------------------------- primitivas
def tela(larg, alt):
    return Image.new("RGBA", (larg, alt), P["vazio"])


def px(img, x, y, c):
    """Pinta um pixel. Ignora fora da tela — deixa as formas serem descritas
    sem cada chamada precisar checar limites."""
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c if isinstance(c, tuple) else P[c])


def runs(img, lista, c):
    """Pinta runs (y, x0, x1) inclusivos — o mesmo formato de gerar_garras.py."""
    for y, x0, x1 in lista:
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def ret(img, x0, y0, x1, y1, c):
    """Retangulo cheio, coordenadas inclusivas."""
    runs(img, [(y, x0, x1) for y in range(y0, y1 + 1)], c)


def moldura(img, x0, y0, x1, y1, c):
    """Contorno de 1px."""
    runs(img, [(y0, x0, x1), (y1, x0, x1)], c)
    for y in range(y0, y1 + 1):
        px(img, x0, y, c)
        px(img, x1, y, c)


def disco(img, cx, cy, r, c):
    """Circulo cheio em grade de pixel. O +0.35 no raio ao quadrado tira o
    'dente' que aparece nos quatro polos quando o teste e estritamente <= r^2."""
    rr = r * r + 0.35
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= rr:
                px(img, x, y, c)


def anel(img, cx, cy, r, c):
    """Circunferencia de 1px."""
    interno = tela(img.width, img.height)
    disco(interno, cx, cy, r, (255, 255, 255, 255))
    dentro = tela(img.width, img.height)
    disco(dentro, cx, cy, r - 1, (255, 255, 255, 255))
    for y in range(img.height):
        for x in range(img.width):
            if interno.getpixel((x, y))[3] and not dentro.getpixel((x, y))[3]:
                px(img, x, y, c)


def dither(img, x0, y0, x1, y1, c, densidade=2):
    """Trama xadrez. E a sombra do pixel art: um gradiente de verdade quebraria
    a leitura de pixel na primeira ampliacao."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + y) % densidade == 0:
                px(img, x, y, c)


def contornar(img, c, diagonais=False):
    """Envolve tudo que e opaco com um contorno de 1px POR FORA.
    O contorno escuro e o que faz um icone de 20px continuar legivel sobre
    qualquer fundo — e o mesmo recurso das mascaras de corpo."""
    vizinhos = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    if diagonais:
        vizinhos += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    alvo = []
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3]:
                continue
            for dx, dy in vizinhos:
                vx, vy = x + dx, y + dy
                if 0 <= vx < img.width and 0 <= vy < img.height \
                        and img.getpixel((vx, vy))[3] > 0:
                    alvo.append((x, y))
                    break
    for x, y in alvo:
        px(img, x, y, c)


def salvar(img, diretorio, nome):
    os.makedirs(diretorio, exist_ok=True)
    caminho = os.path.join(diretorio, nome)
    img.save(caminho)
    return caminho


def atlas(sprites, celula, colunas):
    """Empacota sprites do mesmo tamanho numa folha. Devolve (imagem, indices).

    Uma folha e nao 16 PNGs soltos: a roda instancia todos os icones de uma vez,
    e um unico load() com AtlasTexture evita 16 idas ao disco por abertura.
    """
    linhas = (len(sprites) + colunas - 1) // colunas
    folha = tela(celula * colunas, celula * linhas)
    indices = {}
    for i, (nome, img) in enumerate(sprites):
        cx, cy = (i % colunas) * celula, (i // colunas) * celula
        folha.alpha_composite(img, (cx, cy))
        indices[nome] = i
    return folha, indices
