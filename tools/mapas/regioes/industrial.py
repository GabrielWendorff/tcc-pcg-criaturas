#!/usr/bin/env python3
"""
industrial.py — o distrito industrial velho e a padaria.

MESMA IDENTIDADE VISUAL, MATERIAIS DIFERENTES. Nada aqui muda de estilo: a
projecao, a paleta, a luz no alto a esquerda e o tamanho da celula sao os da
vila. O que muda e do que as coisas sao feitas — calcada no lugar de terra
batida, tijolo e zinco no lugar de reboco e telha, dente-de-serra no lugar de
quatro aguas. E assim que uma regiao ganha carater sem virar outro jogo.

O distrito fica na margem LESTE do rio, encostado nele. Isso e conteudo: e o que
sustenta a fala do Otavio sobre a cor da agua depois da fabrica.

A PADARIA e um comercio vivo dentro de um distrito morto — e por isso ela fica na
rua principal, com toldo, e nao escondida num canto.
"""

REGIAO = {
    "id": "industrial",
    "nome": "Distrito da Chaminé",
    "descricao": "Fábrica parada, galpões e uma padaria que não fechou.",
    "icone": "chamine",
    "cor": "#8e8c8a",
    "retangulo": (45, 43, 94, 86),
}


def construir(m):
    m.regiao(**REGIAO)

    # --- o patio: uma mancha de calcada, nao um retangulo ---
    # Retangulo perfeito le como praca planejada; o distrito cresceu torto.
    for cx, cy, raio, fase in ((66, 58, 7.5, 0.6), (74, 66, 6.0, 2.2),
                               (62, 70, 5.5, 4.0), (78, 54, 4.5, 1.4)):
        m.disco(cx, cy, raio, "k", deformacao=0.22, fase=fase,
                so_sobre=(".", "g", "t", "c"))

    # --- ruas estreitas ---
    # 2.0 de largura contra 2.6 da vila: rua de distrito e mais apertada que
    # estrada de campo, e a diferenca e sentida ao andar entre os galpoes.
    m.faixa((60, 52), (84, 52), 2.0, "k", so_sobre=(".", "g", "t", "c"))
    m.faixa((60, 72), (84, 72), 2.0, "k", so_sobre=(".", "g", "t", "c"))
    m.faixa((70, 48), (70, 80), 2.0, "k", so_sobre=(".", "g", "t", "c"))
    m.faixa((82, 50), (82, 74), 1.8, "k", so_sobre=(".", "g", "t", "c"))
    m.faixa((60, 62), (70, 62), 2.0, "k", so_sobre=(".", "g", "t", "c"))

    # --- as construcoes ---
    m.construcao("fabrica", "fabrica", 64, 55, papel="industria",
                 regiao="industrial", chao="k", exigir=(".", "g", "t", "k"))
    m.construcao("galpao_expedicao", "galpao_01", 74, 56, papel="deposito",
                 regiao="industrial", chao="k", exigir=(".", "g", "t", "k"))
    m.construcao("galpao_norte", "galpao_02", 76, 66, papel="deposito",
                 regiao="industrial", chao="k", exigir=(".", "g", "t", "k"))
    m.construcao("padaria", "padaria", 62, 66, papel="comercio",
                 regiao="industrial", chao="k", exigir=(".", "g", "t", "k"))
    m.construcao("oficina", "oficina", 78, 74, papel="comercio",
                 regiao="industrial", chao="k", exigir=(".", "g", "t", "k"))

    # A chamine solta e o marco do distrito: e ela que se ve de longe, antes de
    # qualquer predio.
    for gx, gy in ((72, 54), (68, 68)):
        if m.livre(gx, gy, exigir=("k", "t", ".")):
            m.por_prop("decoracao", "chamine", gx, gy)

    # --- ferro velho no patio ---
    from mundo_lib import ruido
    for prop, gx, gy in (("maquinario", 67, 61), ("maquinario", 75, 62),
                         ("barril", 61, 62), ("barril", 62, 61),
                         ("barril", 79, 57), ("barril_agua", 60, 68),
                         ("caixa", 73, 70), ("caixa", 74, 70),
                         ("caixa", 63, 71), ("placa", 70, 64),
                         ("maquinario", 80, 70)):
        if m.livre(gx, gy, exigir=("k", "t", ".", "g")):
            m.por_prop("decoracao", prop, gx, gy)

    # Mato nascendo nas frestas da calcada: e o que diz "parado ha anos" sem
    # precisar de uma linha de dialogo.
    for gy in range(46, min(86, m.profundidade)):
        for gx in range(48, min(94, m.largura)):
            if m.ler(gx, gy) != "k" or not m.livre(gx, gy, exigir=("k",)):
                continue
            if ruido(gx, gy, 71) < 0.03:
                m.por_prop("decoracao", "flores_02", gx, gy)

    # --- zonas de encontro: terreno baldio entre os galpoes ---
    m.ponto_de_encontro("baldio_da_fabrica", 88, 60, 3.0, "baldio",
                        ["eletrico", "sombra"])
    m.ponto_de_encontro("fundos_do_galpao", 66, 80, 3.2, "entulho",
                        ["fogo", "eletrico"])
