#!/usr/bin/env python3
r"""
Gera os icones de todos os itens da bolsa como pixel art.

Saida:
    arte/itens/itens.png    folha 8 colunas x 20px de celula
    arte/itens/itens.json   id do item -> indice na folha

Os ids sao os MESMOS de data/captura/dispositivos.json, data/captura/iscas.json
e data/itens/catalogo.json. Acrescentar um item la sem desenha-lo aqui e erro
detectado por tools/test_encontro.gd e tools/test_bolsa.gd, nao um icone
faltando descoberto na tela.

DIRECAO DE ARTE
Silhueta primeiro: em 20x20, o jogador precisa reconhecer o item sem ler o nome.
Cada icone e uma forma cheia com contorno escuro de 1px por fora (ui_lib.contornar)
e tres tons — sombra, base, brilho — com a luz no alto a esquerda, a mesma
convencao de corpos_lib e mundo_lib. Nada de detalhe interno com menos de 2px:
some na primeira olhada e vira ruido.

    python3 tools/arte/gerar_itens.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ui_lib
from ui_lib import anel, disco, dither, moldura, px, ret, runs, tela

S = 20                      # lado da celula
COLUNAS = 8


# ------------------------------------------------------- dispositivos (6)

def _orbe(base, sombra, brilho, metal, metal_c):
    """Corpo comum das duas esferas: globo com COLEIRA de metal e argola no topo.

    A coleira e a argola existem por decisao de design, nao de enfeite. Um globo
    partido ao meio por uma faixa horizontal com um botao no centro e a forma
    registrada de outra franquia; este projeto precisa de identidade propria. O
    perfil daqui — globo pendurado por uma argola, com costura DIAGONAL e uma
    lente no quadrante superior — le como 'aparelho de captura' sem ser aquela
    forma, e ainda ganha uma silhueta que nao e um circulo puro, o que ajuda a
    distinguir da Redoma na roda.
    """
    img = tela(S, S)
    cx, cy = 9.5, 11.5
    disco(img, cx, cy, 7.6, sombra)
    disco(img, cx, cy, 7.0, base)
    # metade inferior mais clara: luz no alto a esquerda, sombra propria embaixo
    for y in range(13, 19):
        for x in range(S):
            if img.getpixel((x, y))[3]:
                px(img, x, y, brilho)
    # costura diagonal
    for i in range(13):
        px(img, 3 + i, 17 - i, metal)
        px(img, 3 + i, 16 - i, metal)
    # coleira e argola
    ret(img, 7, 3, 12, 5, metal)
    ret(img, 7, 3, 12, 3, metal_c)
    anel(img, 9.5, 1.5, 2.2, metal)
    # lente no quadrante superior esquerdo
    disco(img, 7.0, 9.5, 2.4, metal)
    disco(img, 7.0, 9.5, 1.5, "perg_c")
    return img


def esfera_simples():
    return _orbe("aco", "aco_e", "osso", "terra", "terra_c")


def esfera_reforcada():
    img = _orbe("azul", "azul_e", "azul_c", "aco", "aco_c")
    # cintas de reforco e rebites: o que faz "reforcada" ler a um relance
    ret(img, 2, 11, 17, 12, "aco_e")
    ret(img, 2, 11, 17, 11, "aco")
    for x, y in ((4, 7), (14, 7), (4, 15), (14, 15)):
        px(img, x, y, "aco_c")
        px(img, x + 1, y, "aco_c")
    return img


def rede_de_caca():
    """Malha aberta com pesos nas pontas. Le como rede pelo VAZIO entre os fios."""
    img = tela(S, S)
    disco(img, 9.5, 10.5, 8, "folha_e")
    disco(img, 9.5, 10.5, 7.2, "folha")
    # buracos da malha: xadrez de 2px
    for y in range(3, 18, 3):
        for x in range(2, 18, 3):
            if img.getpixel((min(x, 19), min(y, 19)))[3]:
                px(img, x, y, "vazio")
                px(img, x + 1, y, "vazio")
    # cordao superior
    runs(img, [(2, 5, 14), (1, 7, 12)], "terra")
    for x, y in ((2, 15), (17, 15), (9, 18)):
        disco(img, x, y, 1.6, "terra_c")
    return img


def armadilha_de_aco():
    """Armadilha de mandibula, vista de cima: base ovalada, duas meias-luas
    dentadas fechando uma sobre a outra, e a corrente saindo pelo lado.

    A versao anterior era uma fileira de dentes sobre uma barra — lia como
    pente. O que faz ler como armadilha e o CIRCULO: a boca aberta precisa de
    contorno fechado para o olho entender que aquilo prende alguma coisa.
    """
    img = tela(S, S)
    # base / prato
    disco(img, 9.5, 11.5, 7.4, "aco_e")
    disco(img, 9.5, 11.5, 5.4, "contorno")
    disco(img, 9.5, 11.5, 4.6, "terra_e")
    # mandibula superior e inferior
    for dy, sinal in ((0, 1), (0, -1)):
        pass
    runs(img, [(5, 4, 15), (6, 3, 16)], "aco")
    runs(img, [(5, 4, 15)], "aco_c")
    runs(img, [(17, 4, 15), (16, 3, 16)], "aco")
    # dentes que se encaixam (os de cima descem, os de baixo sobem, alternados)
    for i, cx in enumerate(range(4, 16, 3)):
        runs(img, [(7, cx, cx + 1), (8, cx, cx)], "aco_c")
        runs(img, [(15, cx + 1, cx + 2), (14, cx + 2, cx + 2)], "aco_c")
    # corrente
    for i in range(3):
        anel(img, 17.5, 3.5 - i * 0.0 + i * 0.0, 1.3, "aco")
    anel(img, 17.0, 8.0, 1.4, "aco")
    anel(img, 18.0, 5.0, 1.4, "aco")
    return img


def redoma_aquatica():
    """Domo de agua com bolhas. Meia esfera, nao esfera: a base reta e o que
    impede de virar mais uma bola na roda."""
    img = tela(S, S)
    disco(img, 9.5, 11, 8, "ciano_e")
    disco(img, 9.5, 11, 7.2, "ciano")
    ret(img, 0, 15, 19, 19, "vazio")
    ret(img, 2, 14, 17, 16, "azul_e")
    ret(img, 2, 14, 17, 14, "azul")
    for x, y, r in ((7, 8, 1.6), (12, 11, 1.2), (9, 12, 0.9)):
        disco(img, x, y, r, "ciano_c")
    runs(img, [(5, 6, 8), (6, 5, 6)], "perg_c")
    return img


def prisma_selante():
    """Cristal facetado. Unica forma angular da roda — o item raro tem de ser o
    que menos se parece com os outros."""
    img = tela(S, S)
    corpo = []
    for i, y in enumerate(range(1, 10)):
        corpo.append((y, 9 - i, 10 + i))
    for i, y in enumerate(range(10, 19)):
        corpo.append((y, i + 1, 18 - i))
    runs(img, corpo, "roxo_e")
    for i, y in enumerate(range(3, 10)):
        runs(img, [(y, 9 - i + 1, 10 + i - 1)], "roxo")
    for i, y in enumerate(range(10, 17)):
        runs(img, [(y, i + 2, 17 - i)], "roxo")
    # faceta iluminada a esquerda + centelha
    for i, y in enumerate(range(3, 10)):
        runs(img, [(y, 9 - i + 1, 9)], "roxo_c")
    px(img, 9, 5, "perg_c")
    px(img, 9, 6, "perg_c")
    return img


# --------------------------------------------------------------- iscas (10)

def osso():
    img = tela(S, S)
    ret(img, 5, 8, 14, 11, "osso")
    ret(img, 5, 8, 14, 8, "osso_c")
    for cx, cy in ((4, 7), (4, 12), (15, 7), (15, 12)):
        disco(img, cx, cy, 2.4, "osso")
    for cx, cy in ((4, 7), (15, 7)):
        disco(img, cx, cy, 1.1, "osso_c")
    dither(img, 6, 11, 13, 11, "osso_e")
    return img


def carne_seca():
    img = tela(S, S)
    runs(img, [(4, 7, 13), (5, 5, 15), (6, 4, 16), (7, 3, 16), (8, 3, 16),
               (9, 3, 15), (10, 4, 15), (11, 5, 14), (12, 6, 13), (13, 8, 12)],
         "carne")
    runs(img, [(4, 7, 11), (5, 5, 11), (6, 4, 10), (7, 3, 9)], "carne_c")
    dither(img, 6, 9, 14, 12, "carne_e")
    # osso saindo por baixo, com folga de 1px para nao fundir com a carne
    ret(img, 7, 15, 12, 16, "osso")
    for cx in (6, 13):
        disco(img, cx, 15.5, 1.6, "osso_c")
    return img


def petisco_felino():
    """Dois bombons em losango. Forma pequena e repetida = 'petisco'."""
    img = tela(S, S)
    for ox, oy, c, cc in ((2, 3, "ouro", "ouro_c"), (9, 9, "ouro", "ouro_c")):
        runs(img, [(oy + 0, ox + 3, ox + 4), (oy + 1, ox + 2, ox + 5),
                   (oy + 2, ox + 1, ox + 6), (oy + 3, ox + 1, ox + 6),
                   (oy + 4, ox + 2, ox + 5), (oy + 5, ox + 3, ox + 4)], c)
        runs(img, [(oy + 1, ox + 2, ox + 3), (oy + 2, ox + 1, ox + 3)], cc)
        px(img, ox + 3, oy + 3, "ouro_e")
    return img


def peixe_seco():
    img = tela(S, S)
    runs(img, [(6, 7, 12), (7, 5, 14), (8, 4, 15), (9, 4, 15), (10, 5, 14),
               (11, 7, 12)], "ciano")
    runs(img, [(6, 7, 10), (7, 5, 9), (8, 4, 8)], "ciano_c")
    runs(img, [(6, 15, 17), (7, 15, 17), (8, 16, 17), (9, 16, 17),
               (10, 15, 17), (11, 15, 17)], "ciano_e")
    px(img, 6, 8, "contorno")
    dither(img, 8, 9, 13, 10, "ciano_e")
    return img


def minhoca():
    """Corpo fino e sinuoso, com aneis. Os cinco discos gordos da versao
    anterior liam como um cacho de frutas — o que faz ler como minhoca e a
    espessura de 3px e a curva em S, nao a repeticao."""
    img = tela(S, S)
    trilha = [(3, 15), (4, 14), (5, 13), (6, 12), (7, 11), (8, 10), (9, 9),
              (10, 8), (11, 8), (12, 7), (13, 7), (14, 6), (15, 6), (16, 5)]
    for i, (x, y) in enumerate(trilha):
        runs(img, [(y, x - 1, x + 1), (y + 1, x - 1, x + 1)], "carne")
        px(img, x - 1, y, "carne_c")
        if i % 3 == 0:
            px(img, x, y + 1, "carne_e")
    # cabeca mais grossa
    disco(img, 16.5, 5.0, 2.2, "carne")
    disco(img, 16.0, 4.3, 1.2, "carne_c")
    return img


def sementes():
    img = tela(S, S)
    for cx, cy in ((5, 6), (12, 5), (7, 13), (14, 12), (10, 9)):
        runs(img, [(cy, cx, cx + 1), (cy + 1, cx - 1, cx + 2),
                   (cy + 2, cx - 1, cx + 2), (cy + 3, cx, cx + 1)], "terra_c")
        px(img, cx, cy + 1, "perg_c")
    return img


def queijo_curado():
    """Cunha com furos. A forma de fatia e mais reconhecivel que um bloco."""
    img = tela(S, S)
    runs(img, [(y, 2, 2 + (y - 4) * 2 + 1) for y in range(5, 15)], "ouro")
    ret(img, 2, 14, 17, 16, "ouro_e")
    runs(img, [(y, 2, 2 + (y - 4) * 2 + 1) for y in range(5, 8)], "ouro_c")
    for cx, cy in ((6, 10), (10, 13), (5, 15)):
        disco(img, cx, cy, 1.4, "ouro_e")
    return img


def nectar_floral():
    """Frasco com gota. O gargalo estreito e o que o separa da fruta."""
    img = tela(S, S)
    ret(img, 8, 2, 11, 5, "folha_e")
    ret(img, 7, 5, 12, 6, "folha")
    disco(img, 9.5, 12, 6, "roxo_e")
    disco(img, 9.5, 12, 5.2, "roxo")
    ret(img, 5, 6, 14, 8, "roxo_e")
    runs(img, [(9, 6, 8), (10, 5, 7)], "roxo_c")
    disco(img, 12, 14, 1.4, "roxo_c")
    return img


def fruta_madura():
    img = tela(S, S)
    disco(img, 9.5, 12, 6.4, "vermelho_e")
    disco(img, 9.5, 12, 5.8, "vermelho")
    runs(img, [(8, 6, 9), (9, 5, 8), (10, 5, 7)], "vermelho_c")
    ret(img, 9, 3, 10, 7, "terra")
    runs(img, [(3, 11, 15), (4, 12, 16), (5, 13, 15)], "folha")
    runs(img, [(3, 11, 13), (4, 12, 14)], "folha_c")
    return img


def larva_viva():
    """Corpo segmentado com cabeca. Distingue-se da minhoca pelo dorso reto e
    pelos dois olhos."""
    img = tela(S, S)
    for i, cx in enumerate((5, 9, 13)):
        disco(img, cx, 11, 3.2, "perg_e")
        disco(img, cx - 0.6, 10, 2.0, "perg")
    disco(img, 16, 10, 3.0, "perg_c")
    px(img, 17, 9, "contorno")
    px(img, 15, 9, "contorno")
    dither(img, 3, 13, 14, 13, "terra")
    return img


# ------------------------------------------------ ferramentas e consumiveis (4)

def vara_de_pesca():
    """Vara na diagonal com carretel e linha pendendo.

    A DIAGONAL e o que faz a silhueta caber em 20x20 sem a vara virar um risco
    vertical de 1px — e tambem o que a distingue do frasco das pocoes, que sao
    as unicas outras formas altas da folha. A linha desce em dither porque um
    fio de 1px cheio pesa mais que a propria vara.
    """
    img = tela(S, S)
    # cabo (mais grosso, embaixo a esquerda) e vara (afina subindo a direita)
    for i in range(6):
        px(img, 2 + i, 16 - i, "terra_e")
        px(img, 3 + i, 16 - i, "terra")
    for i in range(6, 15):
        px(img, 2 + i, 16 - i, "madeira_c")
    # carretel na junta cabo/vara
    disco(img, 8.5, 10.5, 2.6, "aco_e")
    disco(img, 8.5, 10.5, 1.7, "aco_c")
    # linha caindo da ponta, em dither
    for y in range(3, 15, 2):
        px(img, 17, y, "perg_e")
    # anzol
    runs(img, [(15, 15, 17), (16, 15, 16)], "aco")
    return img


def _frasco(vidro, vidro_c, liquido, liquido_c):
    """Corpo comum das pocoes: frasco de ombro largo, rolha e brilho no vidro.

    As tres pocoes sao a MESMA forma em cores diferentes, de proposito: o
    jogador le "isto e uma pocao" pela silhueta e "qual delas" pela cor, que e
    como uma familia de consumiveis se le num inventario. Formas diferentes para
    o mesmo papel obrigariam a reconhecer cada uma em separado.
    """
    img = tela(S, S)
    ret(img, 8, 2, 11, 4, "terra_e")       # rolha
    ret(img, 8, 2, 11, 3, "terra_c")
    ret(img, 8, 4, 11, 7, vidro)           # gargalo
    disco(img, 9.5, 12.5, 6.2, vidro)      # bojo
    disco(img, 9.5, 13.0, 5.2, liquido)    # liquido, deixando a borda de vidro
    runs(img, [(10, 6, 9), (11, 5, 8)], liquido_c)
    runs(img, [(6, 8, 10), (7, 8, 9)], vidro_c)   # brilho no gargalo
    px(img, 6, 11, vidro_c)
    return img


def pocao_simples():
    return _frasco("ciano_e", "ciano_c", "verde", "verde_c")


def pocao_forte():
    return _frasco("roxo_e", "roxo_c", "vermelho", "vermelho_c")


def elixir_de_folego():
    # Vidro ambar e nao dourado: com vidro e liquido na mesma familia de cor, o
    # frasco lia como um bloco macico e perdia a leitura de "liquido dentro".
    return _frasco("terra_e", "perg_c", "ouro", "ouro_c")


# ------------------------------------------------- equipamento de exemplo (2)

def lanterna():
    """Lanterna de mao: alca em argola, tampa de lata, vidro aceso, base larga.

    O que a separa das pocoes — as outras formas altas e com 'liquido' dourado
    na folha — sao os LADOS RETOS com grade de metal e a argola no topo. O
    frasco e bojudo e tem rolha; a lanterna e uma caixa, e a luz fica no meio
    dela, nao no fundo.
    """
    img = tela(S, S)
    anel(img, 9.5, 2.6, 2.4, "aco")             # alca
    runs(img, [(5, 7, 12), (6, 6, 13)], "aco")   # tampa
    runs(img, [(5, 7, 9)], "aco_c")
    ret(img, 6, 7, 13, 14, "ouro_e")             # vidro
    ret(img, 7, 8, 12, 13, "ouro")
    # chama em gota: ponta fina em cima, bojo embaixo, miolo quase branco
    runs(img, [(9, 10, 10), (10, 9, 10), (11, 8, 11), (12, 8, 11),
               (13, 9, 10)], "ouro_c")
    runs(img, [(11, 9, 10), (12, 9, 10)], "perg_c")
    for x in (6, 13):                            # grade lateral
        for y in range(7, 15):
            px(img, x, y, "aco_e")
    ret(img, 5, 15, 14, 16, "aco_e")             # base
    ret(img, 5, 15, 14, 15, "aco")
    return img


def pa_de_jardim():
    """Pa de jardim na diagonal: cabo de madeira, virola, lamina em gota.

    Mesma diagonal da vara de pesca, de proposito — sao as duas ferramentas de
    mao e a roda as mostra lado a lado. O que as separa e o PESO da silhueta: a
    vara e um risco longo com linha pendente; a pa concentra metade da area numa
    lamina larga de aco, com o vinco central escuro que diz 'pa' e nao 'colher'.
    """
    img = tela(S, S)
    # cabo grosso (3px), embaixo a esquerda, com a ponta arredondada
    for i in range(6):
        px(img, 2 + i, 17 - i, "terra_e")
        px(img, 3 + i, 17 - i, "terra")
        px(img, 3 + i, 16 - i, "terra_c")
    disco(img, 2.5, 17.0, 1.4, "terra")
    # virola de metal na junta
    disco(img, 9.0, 10.0, 1.6, "aco_e")
    # lamina: discos decrescentes ao longo da diagonal = gota apontando ao canto
    for cx, cy, r in ((12.0, 7.0, 3.4), (14.2, 4.8, 2.6), (16.0, 3.0, 1.5)):
        disco(img, cx, cy, r, "aco")
    for cx, cy, r in ((11.2, 6.2, 1.8), (13.4, 4.0, 1.2)):
        disco(img, cx, cy, r, "aco_c")              # luz no alto a esquerda
    for i in range(6):                               # vinco central
        px(img, 11 + i, 8 - i, "aco_e")
    return img


DISPOSITIVOS = [
    ("esfera_simples", esfera_simples), ("esfera_reforcada", esfera_reforcada),
    ("rede_de_caca", rede_de_caca), ("armadilha_de_aco", armadilha_de_aco),
    ("redoma_aquatica", redoma_aquatica), ("prisma_selante", prisma_selante),
]
ISCAS = [
    ("osso", osso), ("carne_seca", carne_seca),
    ("petisco_felino", petisco_felino), ("peixe_seco", peixe_seco),
    ("minhoca", minhoca), ("sementes", sementes),
    ("queijo_curado", queijo_curado), ("nectar_floral", nectar_floral),
    ("fruta_madura", fruta_madura), ("larva_viva", larva_viva),
]
# Itens de data/itens/catalogo.json. Os ids sao os de la, como os de cima sao os
# de data/captura/*.json — um id sem icone e erro de dado, apanhado por
# tools/test_bolsa.gd e tools/test_equipamento.gd.
#
# Item novo entra SEMPRE NO FIM desta lista. O indice na folha e a posicao na
# concatenacao DISPOSITIVOS + ISCAS + OUTROS; inserir no meio renumeraria todos
# os seguintes, e qualquer recorte gravado fora do itens.json (uma cena de
# teste, uma captura de tela de referencia) passaria a apontar o icone errado.
OUTROS = [
    ("vara_de_pesca", vara_de_pesca), ("pocao_simples", pocao_simples),
    ("pocao_forte", pocao_forte), ("elixir_de_folego", elixir_de_folego),
    ("lanterna", lanterna), ("pa_de_jardim", pa_de_jardim),
]


def main():
    sprites = []
    for nome, fn in DISPOSITIVOS + ISCAS + OUTROS:
        img = fn()
        ui_lib.contornar(img, "contorno")
        sprites.append((nome, img))

    folha, indices = ui_lib.atlas(sprites, S, COLUNAS)
    os.makedirs(ui_lib.DIR_ITENS, exist_ok=True)
    folha.save(os.path.join(ui_lib.DIR_ITENS, "itens.png"))
    with open(os.path.join(ui_lib.DIR_ITENS, "itens.json"), "w",
              encoding="utf-8") as f:
        json.dump({
            "_meta": {
                "descricao": "Indice dos icones de item na folha itens.png. "
                             "Os ids sao os de data/captura/*.json e "
                             "data/itens/catalogo.json. "
                             "Gerado por tools/arte/gerar_itens.py — nao editar a mao.",
                "versao": 1,
            },
            "celula": [S, S],
            "colunas": COLUNAS,
            "itens": indices,
        }, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("itens: %d icones, folha %dx%d" % (len(sprites), folha.width, folha.height))


if __name__ == "__main__":
    main()
