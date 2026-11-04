#!/usr/bin/env python3
"""
vila.py — a vila inicial. CONTEUDO PRESERVADO da primeira area jogavel.

O desenho e o mesmo de antes da expansao do mundo: mesmo lago, mesma praca, mesmo
casario, mesmas oito zonas de encontro, mesmas proporcoes. O que mudou foi o
CONTEXTO — a vila deixou de ser o mapa inteiro e virou uma regiao dele —, e com
isso duas coisas sairam daqui:

  1. a borda de rocha que cercava os quatro lados. Ela existia como limite do
     MUNDO; agora o limite do mundo esta a 50 celulas de distancia, e um paredao
     em volta da vila a transformaria numa ilha.
  2. o deslocamento (OX, OY): a vila nasce no canto noroeste do mundo, e todas as
     coordenadas da planta original sao somadas a ele. Assim o desenho continua
     conferivel contra a versao anterior, celula a celula.
"""

OX, OY = 2, 2

REGIAO = {
    "id": "vila",
    "nome": "Vila do Poço",
    "descricao": "Praça, poço e sete casas. É daqui que tudo sai.",
    "icone": "casa",
    "cor": "#6b8f4b",
    # O retangulo cobre a vila E os arredores dela ate a divisa da regiao
    # vizinha. As quatro regioes LADRILHAM o mapa inteiro, sem vao entre elas:
    # o vao apareceria como uma faixa sem nevoa no mapa geral (M), revelando
    # terreno de uma regiao que o jogador ainda nao visitou.
    "retangulo": (1, 1, 44, 42),
}

# Praca e spawn, ja com deslocamento.
PRACA = (19.0 + OX, 17.0 + OY)
SPAWN = (19 + OX, 19 + OY)

# Casas da vila. `papel` e o gancho de NPC/loja/missao que ja existia no mapa
# antigo e que agora tem quem o leia: autoral/npcs/npcs.json posiciona gente
# perto delas.
PLANTA = [
    ("casa_do_prefeito", "casa_06", 21, 22, "civico"),
    ("casa_norte",       "casa_01", 21,  7, "residencia"),
    ("casa_oeste",       "casa_03", 10, 19, "residencia"),
    ("loja",             "casa_02", 25, 19, "comercio"),
    ("casa_sul",         "casa_04", 16, 22, "residencia"),
    ("casa_alta",        "casa_05", 16,  8, "residencia"),
    ("celeiro_da_vila",  "celeiro", 10, 14, "deposito"),
]

# Zonas de encontro. Ficam FORA da praca e afastadas dos caminhos principais:
# atravessar a vila nunca pode obrigar a passar por elas — entrar na grama alta
# tem de ser escolha do jogador.
AREAS = [
    ("campo_norte",       8.0,  7.5, 3.0, "campo",    ["terra", "planta"]),
    ("margem_do_lago",   34.0, 13.5, 2.6, "margem",   ["agua", "gelo"]),
    ("pedregal_leste",   33.0, 21.0, 2.8, "pedregal", ["terra", "eletrico"]),
    ("clareira_sul",     20.0, 30.0, 3.6, "clareira", ["planta", "ar"]),
    ("bosque_oeste",      7.0, 22.0, 3.2, "bosque",   ["planta", "sombra"]),
    ("encosta_sudoeste", 11.0, 30.0, 3.0, "encosta",  ["terra", "fogo"]),
    ("campina_norte",    14.0,  3.5, 2.6, "campina",  ["ar", "eletrico"]),
    ("mata_sudeste",     30.0, 29.0, 3.2, "mata",     ["sombra", "planta"]),
]


def construir(m):
    m.regiao(**REGIAO)
    m.spawn = SPAWN

    # --- lago, no quadrante norte-leste ---
    # Tres bacias sobrepostas de tamanhos diferentes, cada uma com harmonicos
    # proprios. Um disco so, por mais deformado, ainda le como bolha; sao as
    # reentrancias entre bacias que dao ao lago um contorno de lago.
    m.disco(29.8 + OX, 6.2 + OY, 3.9, "a", deformacao=0.40, fase=0.9, so_sobre=(".",))
    m.disco(26.6 + OX, 9.0 + OY, 2.6, "a", deformacao=0.52, fase=2.4, so_sobre=(".",))
    m.disco(31.8 + OX, 9.2 + OY, 2.1, "a", deformacao=0.48, fase=4.1, so_sobre=(".",))
    m.disco(29.6 + OX, 11.4 + OY, 1.9, "a", deformacao=0.60, fase=5.6, so_sobre=(".",))

    # --- praca central e caminhos internos ---
    m.disco(PRACA[0], PRACA[1], 4.6, "t", deformacao=0.16, fase=1.3, so_sobre=(".",))
    m.faixa((19 + OX, 4 + OY), (19 + OX, 31 + OY), 2.6, "c", so_sobre=(".", "g"))
    m.faixa((6 + OX, 17 + OY), (31 + OX, 17 + OY), 2.6, "c", so_sobre=(".", "g"))
    m.faixa((22 + OX, 15 + OY), (26 + OX, 12 + OY), 2.0, "c", so_sobre=(".", "g", "s"))
    m.faixa((16 + OX, 20 + OY), (10 + OX, 26 + OY), 2.0, "c", so_sobre=(".", "g"))
    m.faixa((23 + OX, 20 + OY), (27 + OX, 24 + OY), 2.0, "c", so_sobre=(".", "g"))
    m.disco(PRACA[0], PRACA[1], 4.6, "t", deformacao=0.16, fase=1.3, so_sobre=("c",))

    m.ocupar(*SPAWN)          # o jogador nasce em chao limpo, sem prop por cima

    for id_ponto, cx, cy, raio, bioma, elementos in AREAS:
        m.ponto_de_encontro(id_ponto, cx + OX, cy + OY, raio, bioma, elementos)

    for nome, prop, gx, gy, papel in PLANTA:
        m.construcao(nome, prop, gx + OX, gy + OY, papel=papel, regiao="vila")

    # --- cercas e decoracao em volta das primeiras casas ---
    for c in m.casas[:4]:
        gx, gy = c["celula"]
        W, D = m.tamanho(c["prop"])
        for dx in range(W):
            if m.livre(gx + dx, gy - 1):
                m.por_prop("decoracao", "cerca_x", gx + dx, gy - 1)
        for dy in range(D):
            if m.livre(gx - 1, gy + dy):
                m.por_prop("decoracao", "cerca_y", gx - 1, gy + dy)

    for prop, gx, gy in (("poco", 19, 17), ("placa", 19, 21), ("placa", 17, 17),
                         ("caixa", 26, 18), ("caixa", 25, 18), ("toco_01", 12, 15),
                         ("caixa", 11, 21), ("toco_01", 28, 24)):
        if m.livre(gx + OX, gy + OY, exigir=(".", "t", "c", "g")):
            m.por_prop("decoracao", prop, gx + OX, gy + OY)
