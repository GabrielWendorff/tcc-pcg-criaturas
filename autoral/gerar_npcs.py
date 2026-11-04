#!/usr/bin/env python3
"""
gerar_npcs.py — folhas de caminhada e retratos dos NPCs autorais.

Saida:
    autoral/npcs/<id>_1x.png        folha 4x4 (96x96), formato do protagonista
    autoral/npcs/retratos/<id>.png  busto 32x32 (recorte da folha, 2x)
    autoral/npcs/retratos/jogador.png

NAO REDESENHA O PERSONAGEM. Importa `gerar_protagonista` e reusa a MESMA
geometria (torsos, pernas, fases), trocando so a PALETA. O motivo e o mesmo pelo
qual as criaturas sao mascaras indexadas: a forma e autoral e cara; a cor e
parametro. Um segundo conjunto de desenhos de 24px produziria personagens que
nao parecem do mesmo mundo, e qualquer correcao na silhueta teria de ser feita
duas vezes.

Como um NPC fica distinto sem geometria nova:
  - as linhas 2..9 sao o BONE (chaves B/H/b). Pintando-as com a cor do CABELO,
    o personagem aparece sem chapeu; com amarelo-palha, de chapeu de palha.
  - M/m/n sao as tiras e o volume da mochila do protagonista. Num NPC parado
    elas leem como avental, colete ou suspensorio — e e assim que sao usadas.

Regerar:  python3 autoral/gerar_npcs.py
"""

import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import gerar_protagonista as prot  # noqa: E402

DESTINO = os.path.join(AQUI, "npcs")
DESTINO_RETRATOS = os.path.join(DESTINO, "retratos")
CEL = prot.CEL

# Recorte do busto dentro do quadro (linha "baixo", coluna 0): do topo do
# chapeu ao ombro. 16x16 para que o dobro caia exatamente em 32x32, e 32x32
# ampliado 3x na caixa de dialogo mantenha o pixel quadrado.
BUSTO = (4, 2, 20, 18)

# Cada NPC e uma PALETA COMPLETA — as mesmas chaves de gerar_protagonista. Sem
# heranca parcial de proposito: ver a paleta inteira lado a lado e o que permite
# conferir, de relance, que dois personagens nao sairam com a mesma camisa.
NPCS = {
    # Aldea da vila: sem chapeu (bone pintado com a cor do cabelo), avental claro
    "mirela": {
        "K": (0x10, 0x10, 0x16),
        "B": (0x6b, 0x3a, 0x2a), "H": (0x8d, 0x51, 0x36), "b": (0x4a, 0x27, 0x1d),
        "C": (0x6b, 0x3a, 0x2a), "c": (0x8d, 0x51, 0x36),
        "S": (0xc9, 0x93, 0x67), "s": (0x9b, 0x6c, 0x48), "L": (0xe2, 0xb0, 0x85),
        "T": (0x4e, 0x6e, 0x8a), "t": (0x36, 0x4f, 0x66),
        "M": (0xe4, 0xdc, 0xc4), "m": (0xc3, 0xb8, 0x9a), "n": (0xf2, 0xec, 0xd8),
        "P": (0x5c, 0x5a, 0x48), "p": (0x42, 0x40, 0x33),
        "Z": (0x6b, 0x46, 0x30), "z": (0x42, 0x2b, 0x1d),
    },
    # Pescador: chapeu gasto, barba/cabelo grisalho, camisa de rio
    "anselmo": {
        "K": (0x10, 0x10, 0x16),
        "B": (0x5d, 0x6b, 0x52), "H": (0x7d, 0x8c, 0x6d), "b": (0x3f, 0x4a, 0x38),
        "C": (0x9a, 0x9d, 0xa4), "c": (0xbc, 0xbf, 0xc6),
        "S": (0xb0, 0x7c, 0x52), "s": (0x84, 0x59, 0x37), "L": (0xd2, 0x9e, 0x72),
        "T": (0x2f, 0x4c, 0x63), "t": (0x22, 0x37, 0x48),
        "M": (0x8a, 0x6c, 0x45), "m": (0x5e, 0x48, 0x2c), "n": (0xa5, 0x85, 0x5a),
        "P": (0x4a, 0x4f, 0x54), "p": (0x33, 0x37, 0x3c),
        "Z": (0x3a, 0x3f, 0x44), "z": (0x24, 0x27, 0x2b),
    },
    # Padeiro: touca clara, avental de farinha, camisa creme
    "bento": {
        "K": (0x10, 0x10, 0x16),
        "B": (0xef, 0xe9, 0xdc), "H": (0xff, 0xff, 0xf4), "b": (0xcd, 0xc5, 0xb2),
        "C": (0x3a, 0x2a, 0x1e), "c": (0x55, 0x3e, 0x2c),
        "S": (0xd6, 0xa4, 0x76), "s": (0xa8, 0x7a, 0x52), "L": (0xf0, 0xc4, 0x99),
        "T": (0xe8, 0xdc, 0xc0), "t": (0xc2, 0xb6, 0x9c),
        "M": (0xb8, 0x7a, 0x3e), "m": (0x8c, 0x59, 0x2a), "n": (0xd2, 0x94, 0x55),
        "P": (0x6e, 0x6a, 0x62), "p": (0x4d, 0x4a, 0x44),
        "Z": (0x4a, 0x3a, 0x2c), "z": (0x30, 0x25, 0x1c),
    },
    # Fazendeira: chapeu de palha, camisa vermelha, calca de brim
    "dulce": {
        "K": (0x10, 0x10, 0x16),
        "B": (0xd9, 0xb0, 0x5e), "H": (0xf2, 0xd2, 0x8a), "b": (0xa8, 0x85, 0x40),
        "C": (0x2c, 0x22, 0x1c), "c": (0x46, 0x36, 0x2a),
        "S": (0xa8, 0x6b, 0x42), "s": (0x7d, 0x4d, 0x2e), "L": (0xc9, 0x8d, 0x5c),
        "T": (0xa8, 0x44, 0x3c), "t": (0x7b, 0x2e, 0x29),
        "M": (0x3f, 0x5a, 0x7e), "m": (0x2c, 0x40, 0x5c), "n": (0x56, 0x74, 0x9c),
        "P": (0x3f, 0x5a, 0x7e), "p": (0x2c, 0x40, 0x5c),
        "Z": (0x5a, 0x40, 0x2c), "z": (0x3b, 0x2a, 0x1c),
    },
    # Ex-operario do distrito: bone gasto, macacao de oficina, ferrugem
    "otavio": {
        "K": (0x10, 0x10, 0x16),
        "B": (0xa6, 0x5a, 0x2e), "H": (0xc9, 0x7a, 0x44), "b": (0x76, 0x3e, 0x1f),
        "C": (0x55, 0x55, 0x5e), "c": (0x74, 0x74, 0x7f),
        "S": (0x9c, 0x6a, 0x48), "s": (0x73, 0x4c, 0x32), "L": (0xbe, 0x8a, 0x62),
        "T": (0x44, 0x4c, 0x56), "t": (0x2f, 0x35, 0x3d),
        "M": (0x6b, 0x72, 0x7c), "m": (0x3c, 0x42, 0x4a), "n": (0x86, 0x8e, 0x99),
        "P": (0x55, 0x50, 0x42), "p": (0x3b, 0x37, 0x2d),
        "Z": (0x33, 0x36, 0x3a), "z": (0x21, 0x23, 0x26),
    },
}

ORDEM = ["baixo", "esquerda", "direita", "cima"]


def folha(paleta):
    """Folha 4x4 com a paleta dada. Troca PALETA no modulo importado: e o unico
    estado global de gerar_protagonista, e desenhar() le dele."""
    original = prot.PALETA
    prot.PALETA = paleta
    try:
        img = Image.new("RGBA", (CEL * 4, CEL * 4), (0, 0, 0, 0))
        for linha, direcao in enumerate(ORDEM):
            for coluna in range(4):
                prot.desenhar(prot.montar(direcao, coluna), img,
                              coluna * CEL, linha * CEL)
        return img
    finally:
        prot.PALETA = original


def retrato(folha_1x, paleta):
    """Busto 32x32: recorte da cabeca no quadro parado, ampliado 2x, sobre um
    fundo chapado de duas faixas.

    O fundo existe porque a caixa de dialogo e de PERGAMINHO: um busto recortado
    contra o bege perde o contorno escuro do cabelo e da chapeu, e o retrato
    passa a parecer um adesivo em vez de um quadro.
    """
    corte = folha_1x.crop(BUSTO).resize((32, 32), Image.NEAREST)
    fundo = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    escuro = tuple(int(c * 0.42) for c in paleta["T"]) + (255,)
    claro = tuple(int(c * 0.58) for c in paleta["T"]) + (255,)
    px = fundo.load()
    for y in range(32):
        for x in range(32):
            # Diagonal: a mesma direcao da luz do projeto (alto a esquerda).
            px[x, y] = claro if (x + y) < 34 else escuro
    fundo.alpha_composite(corte)
    return fundo


def main():
    os.makedirs(DESTINO, exist_ok=True)
    os.makedirs(DESTINO_RETRATOS, exist_ok=True)

    for id_npc, paleta in NPCS.items():
        faltando = set(prot.PALETA) - set(paleta)
        if faltando:
            raise SystemExit(f"{id_npc}: paleta sem as chaves {sorted(faltando)}")
        img = folha(paleta)
        img.save(os.path.join(DESTINO, f"{id_npc}_1x.png"))
        retrato(img, paleta).save(
            os.path.join(DESTINO_RETRATOS, f"{id_npc}.png"))
        print(f"ok  npcs/{id_npc}_1x.png  +  retratos/{id_npc}.png")

    # O retrato do proprio jogador, para as falas com "quem": "jogador".
    folha_jogador = Image.open(
        os.path.join(AQUI, "protagonista_1x.png")).convert("RGBA")
    retrato(folha_jogador, prot.PALETA).save(
        os.path.join(DESTINO_RETRATOS, "jogador.png"))
    print("ok  retratos/jogador.png")

    contato = Image.new("RGBA", (32 * (len(NPCS) + 1), 32), (0, 0, 0, 0))
    for i, id_npc in enumerate(list(NPCS) + ["jogador"]):
        contato.alpha_composite(
            Image.open(os.path.join(DESTINO_RETRATOS, f"{id_npc}.png")), (i * 32, 0))
    contato.resize((contato.width * 4, contato.height * 4), Image.NEAREST).save(
        os.path.join(DESTINO_RETRATOS, "_preview_retratos.png"))
    print("ok  retratos/_preview_retratos.png (conferencia)")


if __name__ == "__main__":
    main()
