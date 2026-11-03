#!/usr/bin/env python3
"""
gerar_protagonista.py — folha de caminhada do personagem principal.

Formato identico ao da referencia: 4x4 celulas, ordem RPG Maker / Essentials
    linha 0 = baixo, 1 = esquerda, 2 = direita, 3 = cima
    coluna 0 e 2 = parado, 1 e 3 = passo (corpo desce 1px)

Autorado em 1x (celula 24x24, folha 96x96) e ampliado 2x no final,
porque a folha de referencia tambem e um upscale exato de 2x.

Personagem: bone azul royal com aba escura, cabelo preto nas laterais,
pele morena, camisa preta, mochila (tiras cinza + volume cinza escuro),
calca cinza-caqui, tenis azul.
"""

import os
from PIL import Image

CEL = 24
OUT = os.path.dirname(os.path.abspath(__file__))

PALETA = {
    "K": (0x10, 0x10, 0x16),   # contorno
    "B": (0x3a, 0x6e, 0xcc),   # bone azul royal
    "H": (0x5f, 0x94, 0xec),   # bone brilho
    "b": (0x1e, 0x3f, 0x7a),   # aba do bone (mais escura)
    "C": (0x20, 0x20, 0x28),   # cabelo preto
    "c": (0x38, 0x38, 0x44),   # cabelo brilho
    "S": (0xa8, 0x6b, 0x42),   # pele morena
    "s": (0x7d, 0x4d, 0x2e),   # pele sombra
    "L": (0xc9, 0x8d, 0x5c),   # pele luz
    # camisa preta: carvao, nao preto puro — preto puro some contra o contorno
    "T": (0x3d, 0x3d, 0x47),
    "t": (0x26, 0x26, 0x2e),   # camisa sombra (bracos)
    "M": (0x7b, 0x82, 0x8e),   # tira da mochila
    "m": (0x45, 0x4a, 0x54),   # corpo da mochila
    "n": (0x62, 0x69, 0x76),   # mochila luz
    "P": (0x6b, 0x65, 0x55),   # calca caqui
    "p": (0x4d, 0x49, 0x40),   # calca sombra
    "Z": (0x3a, 0x6e, 0xcc),   # tenis azul
    "z": (0x1e, 0x3f, 0x7a),   # sola
}

# --------------------------------------------------------------- torsos
# Linhas 0..18 de cada direcao. Pernas entram depois (linhas 19..22).

BAIXO = [
    "........................",
    "........................",
    ".........KKKKKK.........",
    ".......KKBBBBBBKK.......",
    "......KBBBBBBBBBBK......",
    ".....KBHHBBBBBBBBBK.....",
    "....KCKBBBBBBBBBBKCK....",
    "....KCKbbbbbbbbbbKCK....",
    "....KCKbbbbbbbbbbKCK....",
    "....KCCKKKKKKKKKKCCK....",
    "....KCSSSSSSSSSSSSCK....",
    "....KCSSKSSSSSSKSSCK....",
    "....KCSSSSSLLSSSSSCK....",
    ".....KsSSSSSSSSSSsK.....",
    "....KmKTMTTTTTTMTKmK....",
    "....KmKTMTTTTTTMTKmK....",
    ".....KTTMTTTTTTMTTK.....",
    ".....KTTTTTTTTTTTTK.....",
    ".....KSSKPPPPPPKSSK.....",
    "......KPPPPPPPPPPK......",
]

CIMA = [
    "........................",
    "........................",
    ".........KKKKKK.........",
    ".......KKBBBBBBKK.......",
    "......KBBBBBBBBBBK......",
    ".....KBHHBBBBBBBBBK.....",
    "....KCKBBBBBBBBBBKCK....",
    "....KCKBBBBBBBBBBKCK....",
    "....KCKBBBBbbBBBBKCK....",
    "....KCKKKKKKKKKKKKCK....",
    "....KCCCCCCCCCCCCCCK....",
    "....KCCcCCCCCCCCcCCK....",
    "....KCCCCCCCCCCCCCCK....",
    ".....KCCCCCCCCCCCCK.....",
    "....KmnMnnnnnnnMnmK.....",
    "....KmnMnnmmmnnMnmK.....",
    ".....KTTMnnnnnnMTTK.....",
    ".....KTTTTTTTTTTTTK.....",
    ".....KSSKPPPPPPKSSK.....",
    "......KPPPPPPPPPPK......",
]

ESQUERDA = [
    "........................",
    "........................",
    "........KKKKKKK.........",
    "......KKBBBBBBBBKK......",
    ".....KBBBBBBBBBBBBK.....",
    "....KBHHBBBBBBBBBBCK....",
    "...KBBBBBBBBBBBBBBCCK...",
    "..KbbbbBBBBBBBBBBCCK....",
    "..KbbbbbbBBBBBBBKCCK....",
    "...KKKKKKKKKKKKKKCCK....",
    "....KSSSSSSSSSSSKCCK....",
    "....KSSKKSSSSSSSKCCK....",
    "....KSSSSSSSSSSSKCCK....",
    ".....KsSSSSSSSSKCCK.....",
    "....KTTTTTTTKMmnmmK.....",
    "....KTTTTTTTKMmnmmK.....",
    "....KtTTTTTTKmmmmmK.....",
    ".....KTTTTTTTTTTTK......",
    ".....KSSKPPPPPPPPK......",
    "......KPPPPPPPPPPK......",
]


def espelhar(linhas):
    return ["".join(reversed(l)) for l in linhas]


DIREITA = espelhar(ESQUERDA)

TORSOS = {"baixo": BAIXO, "esquerda": ESQUERDA,
          "direita": DIREITA, "cima": CIMA}


# --------------------------------------------------------------- pernas
def pernas(fase, lateral=False):
    """fase 0 = parado, 1 = perna esquerda a frente, 2 = perna direita.

    Devolve 3 linhas (20..22): pernas, tenis e sola. A linha de quadril
    ja faz parte do torso, para sobrar a linha 23 para o bob do passo.
    """
    def linha(x0, txt):
        g = ["."] * CEL
        for i, ch in enumerate(txt):
            if ch != ".":
                g[x0 + i] = ch
        return "".join(g)

    if lateral:
        if fase == 0:
            return [linha(6, "KPPPPKKPPPPK"),
                    linha(6, "KZZZK..KZZZK"),
                    linha(6, "KzzzK..KzzzK")]
        if fase == 1:
            return [linha(5, "KPPPPKKPPPPK"),
                    linha(4, "KZZZZK..KPPK"),
                    linha(4, "KzzzzK...KZZK")]
        return [linha(7, "KPPPPKKPPPPK"),
                linha(6, "KPPK..KZZZZK"),
                linha(6, "KZZK...KzzzzK")]

    if fase == 0:
        return [linha(6, "KPPPPKKPPPPK"),
                linha(6, "KZZZK..KZZZK"),
                linha(6, "KzzzK..KzzzK")]
    if fase == 1:
        return [linha(5, "KPPPPPKKPPPK"),
                linha(5, "KZZZZK.KPPPK"),
                linha(5, "KzzzzK.KZZZK")]
    return [linha(6, "KPPPKKPPPPPK"),
            linha(6, "KPPPK.KZZZZK"),
            linha(6, "KZZZK.KzzzzK")]


# --------------------------------------------------------------- montagem
FASES = [0, 1, 0, 2]          # colunas: parado, passo A, parado, passo B


def montar(direcao, coluna):
    torso = TORSOS[direcao]
    fase = FASES[coluna]
    desloca = 1 if fase else 0                 # bob de 1px nos frames de passo
    lateral = direcao in ("esquerda", "direita")

    linhas = ["." * CEL] * desloca + list(torso)
    linhas = linhas[:20]
    while len(linhas) < 20:
        linhas.append("." * CEL)
    pern = pernas(fase, lateral)
    if direcao == "direita":
        pern = espelhar(pern)
    linhas += pern
    while len(linhas) < CEL:
        linhas.append("." * CEL)

    for i, l in enumerate(linhas):
        assert len(l) == CEL, f"{direcao}/{coluna} linha {i}: {len(l)} cols"
    return linhas


def desenhar(linhas, img, ox, oy):
    px = img.load()
    for y, l in enumerate(linhas):
        for x, ch in enumerate(l):
            if ch == ".":
                continue
            assert ch in PALETA, f"cor desconhecida {ch!r}"
            px[ox + x, oy + y] = PALETA[ch] + (255,)


def main():
    ordem = ["baixo", "esquerda", "direita", "cima"]
    folha = Image.new("RGBA", (CEL * 4, CEL * 4), (0, 0, 0, 0))
    for r, d in enumerate(ordem):
        for c in range(4):
            desenhar(montar(d, c), folha, c * CEL, r * CEL)

    folha.save(os.path.join(OUT, "protagonista_1x.png"))
    folha.resize((CEL * 8, CEL * 8), Image.NEAREST).save(
        os.path.join(OUT, "protagonista.png"))
    folha.resize((CEL * 4 * 6, CEL * 4 * 6), Image.NEAREST).save(
        os.path.join(OUT, "_preview_protagonista.png"))
    print("ok  protagonista.png (192x192, 2x) e protagonista_1x.png (96x96)")


if __name__ == "__main__":
    main()
