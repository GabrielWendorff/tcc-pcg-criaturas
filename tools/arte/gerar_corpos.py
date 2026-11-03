#!/usr/bin/env python3
"""
gerar_corpos.py — exporta as 32 mascaras de corpo (8 tipos x 4 portes),
a folha de contato e o JSON de ancoras.

Mesma convencao das garras: PNG RGBA com o indice de paleta no canal R.
    0 transparente | 63 contorno | 126 sombra | 189 base | 252 brilho
"""

import json
import os
from PIL import Image

from corpos_lib import rasterizar, S
from corpos_tipos import (TIPOS, PORTES, PESO_ANIMAL_BASE, ARQUETIPOS, TEM_PATAS)

# Este script vive em tools/arte/ (ferramenta de autoria); a saida vai para
# arte/, que e a raiz dos assets consumidos pela engine.
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
MASK_DIR = os.path.join(RAIZ, "arte", "corpos")
OUT = os.path.join(AQUI, "_preview")

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


def hexa(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def salvar_mascara(g, caminho):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    for y in range(S):
        for x in range(S):
            i = g[y][x]
            if i == 0:
                continue
            v = round(i * 255 / 4)
            px[x, y] = (v, v, v, 255)
    img.save(caminho)


def colorir(g, paleta, escala=1):
    cores = [(0, 0, 0, 0)] + [hexa(c) for c in paleta]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    for y in range(S):
        for x in range(S):
            px[x, y] = cores[g[y][x]]
    if escala > 1:
        img = img.resize((S * escala, S * escala), Image.NEAREST)
    return img


def main():
    os.makedirs(MASK_DIR, exist_ok=True)
    grades, ancoras = {}, {}

    for tipo, fn in TIPOS.items():
        for p, porte in enumerate(PORTES):
            runs, det, anc, fundo = fn(p)
            g = rasterizar(runs, det, fundo)
            nome = f"{tipo}_{p+1}_{porte}"
            grades[nome] = g
            salvar_mascara(g, os.path.join(MASK_DIR, f"corpo_{nome}.png"))
            ancoras[nome] = {
                "tipo": tipo, "arquetipo": ARQUETIPOS[tipo],
                "porte": porte, "indice_porte": p,
                "tem_patas": tipo in TEM_PATAS,
                **{k: v for k, v in anc.items()},
            }

    # O JSON acompanha as mascaras: sem as ancoras, os PNGs nao dizem onde um
    # apendice encosta, entao os dois sao um unico asset.
    with open(os.path.join(MASK_DIR, "corpos_ancoras.json"), "w") as f:
        json.dump({
            "canvas": [S, S],
            # Calibrado visualmente: 16x16 * 0.375 = 6px de garra sobre um corpo de
            # 32px. Acima disso o coxim da garra fica mais largo que a propria pata
            # e a silhueta le como "sola" em vez de unha.
            "escala_garra_sugerida": 0.375,
            "peso_animal_base": PESO_ANIMAL_BASE,
            "portes": PORTES,
            "sprites": ancoras,
        }, f, indent=2, ensure_ascii=False)

    # folha de contato: 8 tipos (linhas) x 4 portes (colunas)
    esc, pad = 4, 4
    cel = S * esc
    larg = pad + 4 * (cel + pad)
    alt = pad + len(TIPOS) * (cel + pad)
    folha = Image.new("RGBA", (larg, alt), (24, 24, 28, 255))
    for r, tipo in enumerate(TIPOS):
        for c, porte in enumerate(PORTES):
            spr = colorir(grades[f"{tipo}_{c+1}_{porte}"], PALETAS["terra"], esc)
            folha.alpha_composite(spr, (pad + c * (cel + pad), pad + r * (cel + pad)))
    folha.save(os.path.join(OUT, "corpos_folha_contato.png"))

    print(f"ok  {len(grades)} mascaras em arte/corpos/")
    print("ok  corpos_ancoras.json")
    print("ok  corpos_folha_contato.png")


if __name__ == "__main__":
    main()
