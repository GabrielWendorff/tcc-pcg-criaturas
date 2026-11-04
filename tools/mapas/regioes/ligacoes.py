#!/usr/bin/env python3
"""
ligacoes.py — o que transforma quatro regioes num mundo so.

Roda DEPOIS de todas as regioes, e faz tres coisas que nenhuma delas pode fazer
sozinha:

  1. ESTRADAS entre regioes, com as duas pontes sobre o rio. Sem elas o mundo
     seria quatro ilhas — e a validacao de alcancabilidade em gerar_mundo.py
     falha se alguma ficar de fora.
  2. TRANSICAO de borda: mato alto e vegetacao esparramados na faixa entre uma
     regiao e outra. E o antidoto para a "fronteira de bioma" — o escopo pede
     explicitamente que nao haja corte seco entre ambientes.
  3. A BORDA DO MUNDO: rocha, penhasco e mata fechada. Aqui, sim, o corte e
     duro — e o limite do mapa, e ele precisa ser lido como intransponivel.

A ponte merece nota. Ela nao e um prop: e TERRENO ("p", linha nova do atlas). Um
sprite de ponte por cima da agua pediria que a agua deixasse de bloquear
naquelas celulas — quer dizer, uma excecao no dado do mapa —, e a colisao do
tile e justamente o que segura o jogador no resto do rio.
"""

from mundo_lib import ruido

# (nome, pontos, largura, terreno). A ordem importa: a ponte e pintada depois da
# estrada que a alimenta, para que as pontas fiquem rentes ao caminho.
ESTRADAS = [
    ("vila_leste",      [(41, 21), (48, 21), (52, 21)], 2.4, "c"),
    ("ribeira_leste",   [(56, 21), (62, 22), (66, 24)], 2.2, "t"),
    ("ribeira_sul",     [(66, 24), (68, 34), (70, 46)], 2.2, "t"),
    ("vila_sul",        [(21, 37), (21, 44), (20, 48)], 2.4, "c"),
    ("fazenda_leste",   [(32, 66), (44, 64), (52, 63)], 2.2, "t"),
    ("industrial_oeste", [(60, 63), (64, 63), (70, 63)], 2.2, "k"),
    ("ribeira_norte",   [(66, 18), (74, 16), (84, 18)], 1.8, "t"),
]

# (nome, celula inicial, celula final) — sempre atravessando o rio na horizontal.
PONTES = [
    ("ponte_da_vila", (51, 21), (57, 21)),
    ("ponte_do_sitio", (51, 63), (61, 63)),
]


def construir(m):
    # --- estradas ---
    for _nome, pontos, largura, terreno in ESTRADAS:
        for i in range(len(pontos) - 1):
            m.faixa(pontos[i], pontos[i + 1], largura, terreno,
                    so_sobre=(".", "g", "s", "t", "c", "k"))

    # --- pontes ---
    for nome, (x0, y0), (x1, y1) in PONTES:
        atravessou = False
        for gx in range(x0, x1 + 1):
            for gy in range(y0 - 1, y0 + 2):
                if m.ler(gx, gy) in ("a", "s"):
                    m.pintar(gx, gy, "p")
                    atravessou = True
        if not atravessou:
            raise SystemExit(f"{nome}: a ponte nao encontrou agua entre "
                             f"({x0},{y0}) e ({x1},{y1}) — o rio mudou de lugar")
        # Guarda-corpo: uma fileira de cerca de cada lado, so nas celulas de
        # ponte. Sem ela a travessia le como uma tira de madeira boiando.
        for gx in range(x0, x1 + 1):
            for gy in (y0 - 2, y0 + 2):
                if m.ler(gx, gy) == "a" and m.livre(gx, gy, exigir=("a",)):
                    m.por_prop("decoracao", "cerca_x", gx, gy)

    # --- transicao entre regioes: mato alto e moitas na faixa de ninguem ---
    # A densidade cai com a distancia da fronteira, entao o mato ADENSA perto da
    # divisa em vez de formar uma linha. E o inverso de uma borda de bioma.
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) != "." or not m.livre(gx, gy):
                continue
            d_fronteira = min(abs(gx - 44), abs(gy - 43))
            if d_fronteira > 5:
                continue
            if ruido(gx, gy, 81) < 0.30 - 0.05 * d_fronteira:
                m.pintar(gx, gy, "g")

    # --- borda do mundo: rocha com espessura irregular ---
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            d = min(gx, gy, m.largura - 1 - gx, m.profundidade - 1 - gy)
            limite = 2 + int(1.9 * ruido(gx // 3, gy // 3, 1))
            if d < limite:
                m.pintar(gx, gy, "r")

    # --- penhascos: o paredao que fecha o mapa ---
    # Vao na primeira fileira de rocha colada ao terreno pisavel, e nao no meio
    # dela: e o degrau entre o mapa jogavel e a borda que da leitura de altura.
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) != "r":
                continue
            vizinho_pisavel = any(m.ler(gx + dx, gy + dy) not in ("a", "r")
                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if not vizinho_pisavel or not m.livre(gx, gy, exigir=("r",)):
                continue
            m.por_prop("penhascos",
                       "penhasco_02" if ruido(gx, gy, 21) < 0.42 else "penhasco_01",
                       gx, gy)

    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) != "r" or not m.livre(gx, gy, exigir=("r",)):
                continue
            vizinho_penhasco = any((gx + dx, gy + dy) in m._ocupado
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, 1)))
            if vizinho_penhasco and ruido(gx, gy, 22) < 0.55:
                m.por_prop("penhascos", "penhasco_01", gx, gy)

    # --- mata da borda: massa verde entre a rocha e a area jogavel ---
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) != "." or not m.livre(gx, gy):
                continue
            d = min(gx, gy, m.largura - 1 - gx, m.profundidade - 1 - gy)
            if d > 6:
                continue
            densidade = 0.62 - 0.09 * d
            if ruido(gx, gy, 31) > densidade:
                continue
            r = ruido(gx, gy, 32)
            prop = ("pinheiro_01" if r < 0.30 else "pinheiro_02" if r < 0.50
                    else "arvore_03" if r < 0.70 else "arvore_01")
            m.por_prop("arvores", prop, gx, gy)

    # --- vegetacao solta no interior ---
    # Nao entra em chao construido (calcada, lavoura, ponte, caminho): uma arvore
    # no meio da rua desmente a regiao que acabou de ser desenhada.
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) not in (".", "g") or not m.livre(gx, gy, exigir=(".", "g")):
                continue
            perto_de_via = any(m.ler(gx + dx, gy + dy) in ("c", "t", "k")
                               for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            r = ruido(gx, gy, 41)
            limite = 0.05 if perto_de_via else 0.13
            if m.ler(gx, gy) == "g":
                limite *= 0.35              # a grama alta fica aberta
            if r >= limite:
                continue
            if r < limite * 0.45:
                prop = "arvore_01" if ruido(gx, gy, 42) < 0.5 else "arvore_02"
                m.por_prop("arvores", prop, gx, gy)
            elif r < limite * 0.80:
                s = ruido(gx, gy, 43)
                prop = ("pedra_01" if s < 0.4 else "pedra_02" if s < 0.8
                        else "pedra_03")
                m.por_prop("pedras", prop, gx, gy)
            else:
                m.por_prop("decoracao",
                           "flores_01" if ruido(gx, gy, 44) < 0.5 else "flores_02",
                           gx, gy)

    # --- pedras na areia da margem ---
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) == "s" and m.livre(gx, gy, exigir=("s",)) \
                    and ruido(gx, gy, 51) < 0.10:
                m.por_prop("pedras", "pedra_02", gx, gy)
