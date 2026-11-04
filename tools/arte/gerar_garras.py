#!/usr/bin/env python3
"""
Gerador de sprites de garras 16x16 como MASCARAS INDEXADAS.

Saida: PNG RGBA onde o canal R codifica o indice de paleta:
    0   -> transparente (alpha 0)
    63  -> indice 1 = contorno
    126 -> indice 2 = sombra
    189 -> indice 3 = base
    252 -> indice 4 = brilho

No Godot 4:  idx = round(COLOR.r * 4.0)  -> lookup na paleta do elemento.

Modelos: curtas, curvas, serrilhadas, adaga   (eixo suave -> agressiva)
"""

from PIL import Image
import os

S = 16                      # lado do sprite
# Ver nota em gerar_corpos.py: mascaras vao para arte/, previews ficam na
# ferramenta (nao sao consumidos pelo jogo).
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
MASK_DIR = os.path.join(RAIZ, "arte", "garras")
OUT = os.path.join(AQUI, "_preview")
PREV_DIR = OUT

TRANSP, OUTLINE, DARK, BASE, HILITE = 0, 1, 2, 3, 4

# ---------------------------------------------------------------- geometria
# Cada modelo e descrito por "runs": (y, x_inicio, x_fim) inclusivos.
# Desenhados a mao para garantir leitura clara em 16x16.

def _pad(y0=13, y1=14, x0=1, x1=14):
    """Coxim/nó de fixação na base da garra."""
    return [(y, x0, x1) for y in range(y0, y1 + 1)]


def curtas():
    """3 unhas curtas e rombudas. Extremo 'suave' do eixo."""
    runs = _pad()
    for cx in (2, 7, 12):
        runs += [
            (12, cx - 1, cx + 1),
            (11, cx - 1, cx + 1),
            (10, cx - 1, cx + 1),
            (9,  cx - 1, cx),
            (8,  cx, cx),
        ]
    return runs


def curvas():
    """3 garras em foice, varrendo para a direita. Suave-media."""
    runs = _pad()
    for cx in (1, 6, 11):
        runs += [
            (12, cx - 0, cx + 2),
            (11, cx - 0, cx + 2),
            (10, cx + 1, cx + 3),
            (9,  cx + 1, cx + 3),
            (8,  cx + 2, cx + 4),
            (7,  cx + 2, cx + 4),
            (6,  cx + 3, cx + 4),
            (5,  cx + 4, cx + 4),
        ]
    return runs


def serrilhadas():
    """3 garras retas e longas com entalhes na borda direita. Media-agressiva."""
    runs = _pad()
    for cx in (2, 7, 12):
        runs += [
            (12, cx - 1, cx + 1),
            (11, cx - 1, cx + 1),
            (10, cx - 1, cx + 1),
            (9,  cx - 1, cx),        # entalhe
            (8,  cx - 1, cx + 1),
            (7,  cx - 1, cx),        # entalhe
            (6,  cx - 1, cx + 1),
            (5,  cx - 1, cx),        # entalhe
            (4,  cx, cx),            # ponta
        ]
    return runs


def adaga():
    """2 laminas longas e afiadas. Extremo 'agressivo' do eixo."""
    runs = _pad()
    for cx in (4, 11):
        runs += [
            (13, cx - 2, cx + 2),
            (12, cx - 2, cx + 2),
            (11, cx - 1, cx + 1),
            (10, cx - 1, cx + 1),
            (9,  cx - 1, cx + 1),
            (8,  cx - 1, cx + 1),
            (7,  cx - 1, cx + 1),
            (6,  cx - 1, cx + 1),
            (5,  cx - 1, cx + 1),
            (4,  cx - 1, cx + 1),
            (3,  cx, cx + 1),
            (2,  cx, cx),
        ]
    return runs


MODELOS = {
    "01_curtas": curtas,
    "02_curvas": curvas,
    "03_serrilhadas": serrilhadas,
    "04_adaga": adaga,
}

# ---------------------------------------------------------------- rasterizacao

def rasterizar(runs):
    """runs -> grade 16x16 de indices, com sombreamento e contorno automaticos."""
    g = [[TRANSP] * S for _ in range(S)]

    # 1. preenchimento
    for y, x0, x1 in runs:
        if not (0 <= y < S):
            continue
        for x in range(max(0, x0), min(S - 1, x1) + 1):
            g[y][x] = BASE

    solido = [[g[y][x] == BASE for x in range(S)] for y in range(S)]

    def cheio(x, y):
        return 0 <= x < S and 0 <= y < S and solido[y][x]

    # 2. sombreamento: luz no canto superior-esquerdo
    for y in range(S):
        for x in range(S):
            if not solido[y][x]:
                continue
            if not cheio(x - 1, y) or not cheio(x, y - 1):
                g[y][x] = HILITE
            elif not cheio(x + 1, y) or not cheio(x, y + 1):
                g[y][x] = DARK

    # 3. contorno: vizinho-4 vazio vira contorno
    contorno = []
    for y in range(S):
        for x in range(S):
            if solido[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if cheio(x + dx, y + dy):
                    contorno.append((x, y))
                    break
    for x, y in contorno:
        g[y][x] = OUTLINE

    return g


def salvar_mascara(g, caminho):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    for y in range(S):
        for x in range(S):
            i = g[y][x]
            if i == TRANSP:
                continue
            v = round(i * 255 / 4)
            px[x, y] = (v, v, v, 255)
    img.save(caminho)


# ---------------------------------------------------------------- preview
# Paletas por elemento: (contorno, sombra, base, brilho)
PALETAS = {
    "fogo":     ("#3d0f08", "#992d12", "#e0621f", "#ffc24a"),
    "agua":     ("#0a2340", "#155a8a", "#2f9fd6", "#a8e8ff"),
    "terra":    ("#2b1c0e", "#6b4a24", "#a87c46", "#e0c489"),
    "ar":       ("#2c2f3d", "#6a7385", "#a9b3c4", "#eef3fb"),
    "planta":   ("#102a12", "#2f6b2c", "#5fae45", "#c2e878"),
    "eletrico": ("#332a05", "#8a7005", "#e0c012", "#fff88a"),
    "gelo":     ("#123245", "#2f7fa0", "#7fd2e8", "#e6fbff"),
    "sombra":   ("#100a1c", "#2f2145", "#5b3f85", "#a98ad6"),
}

VIES = {
    "fogo":     [1, 2, 3, 5],
    "agua":     [4, 3, 2, 1],
    "terra":    [2, 3, 4, 2],
    "ar":       [4, 3, 2, 1],
    "planta":   [3, 3, 2, 2],
    "eletrico": [1, 2, 4, 4],
    "gelo":     [1, 2, 3, 4],
    "sombra":   [1, 1, 3, 5],
}


def hexa(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def colorir(g, paleta, escala=8):
    cores = [(0, 0, 0, 0)] + [hexa(c) for c in paleta]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    for y in range(S):
        for x in range(S):
            px[x, y] = cores[g[y][x]]
    return img.resize((S * escala, S * escala), Image.NEAREST)


def orientar_para_uso(g):
    """Inverte a grade verticalmente na exportacao.

    Os modelos acima sao autorados apontando PARA CIMA, com o coxim na base — e
    assim que a forma se le melhor num quadro isolado de 16x16. Mas a garra e
    composta sob a pata: o coxim encosta no membro e as unhas descem. Inverter uma
    unica vez, aqui, deixa o asset ja na orientacao de uso, e a camada de
    apresentacao nao precisa saber de flip nenhum — ela so cola a mascara na
    ancora. Alterar isto exige revisar CreatureSpriteRenderer.
    """
    return g[::-1]


def folha_contato(grades, escala=6):
    """Grade elementos (linhas) x modelos (colunas), com opacidade pelo peso."""
    nomes = list(grades.keys())
    cel = S * escala
    pad = 4
    larg = pad + len(nomes) * (cel + pad)
    alt = pad + len(VIES) * (cel + pad)
    folha = Image.new("RGBA", (larg, alt), (24, 24, 28, 255))
    for r, elem in enumerate(VIES):
        pesos = VIES[elem]
        for c, nome in enumerate(nomes):
            spr = colorir(grades[nome], PALETAS[elem], escala)
            # peso baixo = mais apagado, so para leitura visual do vies
            a = int(90 + 165 * (pesos[c] - 1) / 4)
            spr.putalpha(spr.getchannel("A").point(lambda v: v * a // 255))
            folha.alpha_composite(spr, (pad + c * (cel + pad), pad + r * (cel + pad)))
    return folha


# ---------------------------------------------------------------- main
if __name__ == "__main__":
    os.makedirs(MASK_DIR, exist_ok=True)
    os.makedirs(PREV_DIR, exist_ok=True)

    grades = {}
    for nome, fn in MODELOS.items():
        g = orientar_para_uso(rasterizar(fn()))
        grades[nome] = g
        salvar_mascara(g, os.path.join(MASK_DIR, f"garra_{nome}.png"))
        colorir(g, PALETAS["terra"]).save(
            os.path.join(PREV_DIR, f"garra_{nome}_x8.png"))
        print(f"ok  garra_{nome}.png")

    folha_contato(grades).save(os.path.join(OUT, "garras_folha_contato.png"))
    print("ok  garras_folha_contato.png")
