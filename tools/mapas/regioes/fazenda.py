#!/usr/bin/env python3
"""
fazenda.py — a pequena fazenda ao sul da vila.

TALHAO E CARREIRA, nao "campo verde". O que faz uma area ler como cultivada nao e
a cor: e a REPETICAO ORIENTADA — talhoes retangulares, carreiras paralelas,
cercas fechando o perimetro. Por isso a lavoura tem terreno proprio (linha nova
do atlas) e as plantas entram como props alinhados nas carreiras.

A transicao com a vila e gradual de proposito (ver ligacoes.py): estrada de
terra, cercas antes do primeiro talhao, mato alto entre um e outro. Uma borda
reta entre grama e lavoura leria como fronteira de bioma — o defeito que o
escopo pede para evitar.
"""

REGIAO = {
    "id": "fazenda",
    "nome": "Sítio da Dulce",
    "descricao": "Três talhões, um celeiro e um espantalho que assusta pouco.",
    "icone": "trigo",
    "cor": "#c4a059",
    "retangulo": (1, 43, 44, 86),
}

# Talhoes: (x0, y0, x1, y1, planta). Tamanhos diferentes de proposito — talhao
# igual em area igual e desenho de planilha, nao de sitio.
TALHOES = [
    (8, 56, 17, 64, "plantacao_milho"),
    (20, 54, 28, 60, "plantacao_folha"),
    (10, 68, 20, 76, "plantacao_milho"),
    (24, 66, 31, 72, "plantacao_folha"),
]


def construir(m):
    m.regiao(**REGIAO)

    # --- o terreiro e as estradas internas ---
    m.disco(20, 50, 5.0, "t", deformacao=0.20, fase=0.8, so_sobre=(".", "g"))
    m.faixa((20, 46), (20, 78), 2.2, "t", so_sobre=(".", "g"))
    m.faixa((9, 66), (32, 66), 2.0, "t", so_sobre=(".", "g"))
    m.faixa((18, 56), (30, 52), 1.8, "t", so_sobre=(".", "g"))

    # --- talhoes ---
    for x0, y0, x1, y1, _planta in TALHOES:
        m.retangulo(x0, y0, x1, y1, "l", so_sobre=(".", "g", "t"))

    # --- construcoes ---
    m.construcao("celeiro_da_fazenda", "celeiro", 15, 48, papel="deposito",
                 regiao="fazenda", exigir=(".", "g", "t"))
    m.construcao("casa_da_fazenda", "casa_05", 24, 47, papel="residencia",
                 regiao="fazenda", exigir=(".", "g", "t"))

    # --- plantas nas carreiras ---
    # Uma carreira sim, uma nao: com todas as celulas ocupadas o talhao vira uma
    # massa solida de sprites e o jogador nao ve mais o sulco do terreno.
    for x0, y0, x1, y1, planta in TALHOES:
        for gy in range(y0, y1 + 1):
            if (gy - y0) % 2:
                continue
            for gx in range(x0, x1 + 1):
                if m.livre(gx, gy, exigir=("l",)):
                    m.por_prop("decoracao", planta, gx, gy)

    # --- cerca em volta dos talhoes, com porteira ---
    # A porteira NAO e um prop: e uma falha proposital na cerca, na carreira em
    # que a estrada entra. Um portao desenhado pediria arte nova para dizer o que
    # um vao de duas celulas ja diz.
    for x0, y0, x1, y1, _planta in TALHOES:
        for gx in range(x0 - 1, x1 + 2):
            for gy in (y0 - 1, y1 + 1):
                if abs(gx - (x0 + x1) // 2) <= 1:      # vao da porteira
                    continue
                if m.livre(gx, gy, exigir=(".", "g", "t")):
                    m.por_prop("decoracao", "cerca_x", gx, gy)
        # Nas laterais, uma celula sim outra nao. A cerca fechada nos quatro
        # lados de quatro talhoes vizinhos empilha duas fileiras de madeira em
        # cada divisa e o sitio vira um labirinto de estacas; alternada, ela
        # ainda le como cerca e deixa o talhao respirar.
        for gy in range(y0, y1 + 1):
            if gy % 2:
                continue
            for gx in (x0 - 1, x1 + 1):
                if m.livre(gx, gy, exigir=(".", "g", "t")):
                    m.por_prop("decoracao", "cerca_y", gx, gy)

    for prop, gx, gy in (("espantalho", 13, 60), ("espantalho", 27, 69),
                         ("caixa", 19, 52), ("caixa", 20, 52),
                         ("barril_agua", 22, 50), ("placa", 20, 45),
                         ("toco_01", 33, 58)):
        if m.livre(gx, gy, exigir=(".", "g", "t", "l")):
            m.por_prop("decoracao", prop, gx, gy)

    # --- zonas de encontro: pasto e mato alto nas bordas do sitio ---
    m.ponto_de_encontro("pasto_alto", 33, 76, 3.4, "pasto", ["terra", "ar"])
    m.ponto_de_encontro("moita_do_sitio", 6, 50, 3.0, "moita", ["planta", "terra"])
    m.ponto_de_encontro("varzea_sul", 26, 82, 3.2, "varzea", ["agua", "planta"])
