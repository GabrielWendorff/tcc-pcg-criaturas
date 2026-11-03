#!/usr/bin/env python3
r"""
Gera as pecas de interface do encontro: molduras 9-slice, medidor, selo,
balao de aviso e vinheta.

Saida em arte/ui/.

9-SLICE, E POR QUE AS MARGENS SAO O QUE SAO
Um StyleBoxTexture divide a textura em 9 pedacos: os 4 cantos ficam intactos, as
4 bordas esticam num eixo so e o miolo estica nos dois. Para isso funcionar, o
miolo tem de ser LISO — qualquer detalhe ali vira um borrao esticado. Por isso
toda moldura daqui e: contorno, chanfro, linha interna, e um miolo de cor chapada.

Tudo e autorado em pixels de TELA. Uma borda de 4px no PNG e uma borda de 4px na
tela, em qualquer resolucao: o 9-slice estica so o miolo liso, nunca os cantos.
E o que mantem a espessura da moldura constante sem depender de escala inteira
de janela.

CHANFRO
Claro em cima e a esquerda, escuro embaixo e a direita — o mesmo sol das outras
familias de arte. E o que da volume a moldura sem sombra externa: sombra
projetada em CSS le como interface web; chanfro de 1px le como objeto.

    python3 tools/arte/gerar_ui.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ui_lib
from ui_lib import anel, disco, dither, moldura, px, ret, runs, tela

# Vinheta: 192x108 e exatamente 1/6 de 1152x648 (a janela do projeto), entao ela
# sobe por replicacao inteira de pixel em vez de reamostragem.
VINH_L, VINH_A = 192, 108


def _quadro(lado, camadas, miolo):
    """Moldura quadrada com camadas concentricas. `camadas` vai de fora para
    dentro: (cor_topo_esq, cor_baixo_dir, espessura)."""
    img = tela(lado, lado)
    ret(img, 0, 0, lado - 1, lado - 1, miolo)
    d = 0
    for cor_ce, cor_bd, esp in camadas:
        for i in range(esp):
            k = d + i
            runs(img, [(k, k, lado - 1 - k)], cor_ce)          # topo
            for y in range(k, lado - k):
                px(img, k, y, cor_ce)                           # esquerda
            runs(img, [(lado - 1 - k, k, lado - 1 - k)], cor_bd)  # base
            for y in range(k, lado - k):
                px(img, lado - 1 - k, y, cor_bd)                # direita
            # cantos do chanfro: sem isto o canto inferior esquerdo fica com a
            # cor errada nos dois lados e o volume se desfaz.
            px(img, k, lado - 1 - k, cor_ce)
            px(img, lado - 1 - k, k, cor_ce)
        d += esp
    return img


def cartao(borda, borda_c, miolo, miolo_c):
    """Cartao de item da roda. 20x20, margem 7."""
    img = _quadro(20, [
        ("contorno", "contorno", 1),
        (borda_c, borda, 2),
        ("contorno", "contorno", 1),
    ], miolo)
    # brilho interno no topo: o miolo chapado sozinho le como retangulo de CSS
    runs(img, [(4, 4, 15)], miolo_c)
    return img


def painel(borda, borda_c, miolo, miolo_c, lado=28):
    """Painel grande (ficha, miolo da roda, caixa de mensagem). Margem 10."""
    img = _quadro(lado, [
        ("contorno", "contorno", 1),
        (borda_c, borda, 3),
        ("contorno", "contorno", 1),
        (miolo_c, miolo_c, 1),
    ], miolo)
    # tachas nos cantos: detalhe que so existe nos cantos, que o 9-slice preserva
    for x, y in ((3, 3), (lado - 4, 3), (3, lado - 4), (lado - 4, lado - 4)):
        px(img, x, y, "ouro")
        px(img, x, y + 1, "ouro_e")
    return img


def medidor_moldura():
    """Trilho do medidor de chance. 10x10, margem 3."""
    img = _quadro(10, [
        ("contorno", "contorno", 1),
        ("madeira_e", "madeira", 1),
    ], "noite_e")
    return img


def selo():
    """Fundo do selo 'ISCA PREFERIDA'. 12x12, margem 4, cantos cortados."""
    img = _quadro(12, [("contorno", "contorno", 1), ("ouro_e", "ouro_e", 1)],
                  "ouro")
    for x, y in ((0, 0), (11, 0), (0, 11), (11, 11)):
        px(img, x, y, "vazio")
    return img


def vinheta():
    """Escurecimento radial em TRAMA, nao em gradiente.

    Um gradiente suave e o recurso de interface moderna; num quadro de pixel art
    ele aparece como faixa lisa no meio de tudo que e quantizado. A trama de
    xadrez em 4 niveis produz o mesmo efeito de foco com a granulacao do resto
    da tela — e e a mesma tecnica que mundo_lib usa nas sombras dos props.
    """
    img = tela(VINH_L, VINH_A)
    cx, cy = VINH_L / 2.0, VINH_A / 2.0
    # normaliza pela diagonal para o efeito nao depender da proporcao
    maxr = (cx ** 2 + cy ** 2) ** 0.5
    escuro = ui_lib.P["contorno"]
    for y in range(VINH_A):
        for x in range(VINH_L):
            r = ((x - cx) ** 2 + ((y - cy) * (VINH_L / VINH_A) * 0.62) ** 2) ** 0.5
            t = max(0.0, min(1.0, (r / maxr - 0.42) / 0.58))
            nivel = int(t * 4.0)           # 0..4
            if nivel <= 0:
                continue
            # niveis 1-3 = trama de densidade crescente; 4 = cheio
            padroes = {1: (x + y) % 4 == 0, 2: (x + y) % 2 == 0,
                       3: (x + y) % 4 != 0, 4: True}
            if padroes.get(nivel, False):
                px(img, x, y, escuro)
    return img


def balao_de_aviso():
    """Balao de susto que salta sobre a cabeca do jogador.

    Substitui o rotulo de texto "!" que havia antes. Motivo: a fonte da interface
    e bitmap, e fonte de bitmap nao aceita o contorno gerado pela engine — um "!"
    chapado sobre grama clara sumiria. O balao traz o proprio contorno e o proprio
    fundo, e e a linguagem do genero em vez de um caractere ampliado.

    O traco tem 6px de largura em 24 de balao. Parece exagerado no PNG e nao e:
    ele aparece por menos de um segundo, na periferia da atencao, sobre folhagem
    de alto contraste. Um traco fino le como sujeira na tela.
    """
    img = tela(24, 30)
    # corpo do balao
    disco(img, 11.5, 12, 11, "perg_c")
    ret(img, 1, 9, 22, 16, "perg_c")
    # rabicho apontando para a cabeca
    runs(img, [(22, 8, 14), (23, 9, 13), (24, 10, 13), (25, 10, 12),
               (26, 11, 12), (27, 11, 11)], "perg_c")
    # rim inferior: 1px mais escuro acompanhando a curva, sem cruzar o miolo.
    # Faixas horizontais atravessando o balao liam como uma boca.
    for x in range(4, 20):
        for y in range(21, 17, -1):
            if img.getpixel((x, y))[3] and not img.getpixel((x, y + 1))[3]:
                px(img, x, y, "perg_e")
                break
    # o "!" — traco grosso e ponto quadrado, 3px de folga entre os dois
    ret(img, 9, 5, 14, 13, "vermelho")
    ret(img, 9, 5, 10, 13, "vermelho_c")
    ret(img, 13, 5, 14, 13, "vermelho_e")
    ret(img, 9, 16, 14, 19, "vermelho")
    ret(img, 9, 16, 10, 19, "vermelho_c")
    ret(img, 13, 16, 14, 19, "vermelho_e")
    ui_lib.contornar(img, "contorno")
    return img


def balao_de_aviso():
    """Balao de susto que salta sobre a cabeca do jogador.

    Substitui o rotulo de texto "!" que havia antes. Motivo: a fonte da interface
    e bitmap, e fonte de bitmap nao aceita o contorno gerado pela engine — um "!"
    chapado sobre grama clara sumiria. O balao traz o proprio contorno e o proprio
    fundo, e e a linguagem do genero em vez de um caractere ampliado.

    O traco tem 6px de largura em 24 de balao. Parece exagerado no PNG e nao e:
    ele aparece por menos de um segundo, na periferia da atencao, sobre folhagem
    de alto contraste. Um traco fino le como sujeira na tela.
    """
    img = tela(24, 30)
    # corpo do balao
    disco(img, 11.5, 12, 11, "perg_c")
    ret(img, 1, 9, 22, 16, "perg_c")
    # rabicho apontando para a cabeca
    runs(img, [(22, 8, 14), (23, 9, 13), (24, 10, 13), (25, 10, 12),
               (26, 11, 12), (27, 11, 11)], "perg_c")
    # rim inferior: 1px mais escuro acompanhando a curva, sem cruzar o miolo.
    # Faixas horizontais atravessando o balao liam como uma boca.
    for x in range(4, 20):
        for y in range(21, 17, -1):
            if img.getpixel((x, y))[3] and not img.getpixel((x, y + 1))[3]:
                px(img, x, y, "perg_e")
                break
    # o "!" — traco grosso e ponto quadrado, 3px de folga entre os dois
    ret(img, 9, 5, 14, 13, "vermelho")
    ret(img, 9, 5, 10, 13, "vermelho_c")
    ret(img, 13, 5, 14, 13, "vermelho_e")
    ret(img, 9, 16, 14, 19, "vermelho")
    ret(img, 9, 16, 10, 19, "vermelho_c")
    ret(img, 13, 16, 14, 19, "vermelho_e")
    ui_lib.contornar(img, "contorno")
    return img


def raio_da_roda():
    """Segmento pontilhado do centro ate um slot. Desenhado como sprite de 1x8 e
    repetido pela roda: uma linha continua desenhada em tempo de execucao sai com
    largura fracionaria nas diagonais e destoa de todo o resto."""
    img = tela(4, 4)
    ret(img, 1, 1, 2, 2, "ouro_e")
    px(img, 1, 1, "ouro")
    return img


PECAS = [
    ("cartao_normal.png", lambda: cartao("madeira_e", "madeira", "noite", "noite_c")),
    ("cartao_ativo.png", lambda: cartao("madeira", "madeira_c", "noite_c", "noite_c")),
    ("cartao_selecionado.png", lambda: cartao("ouro_e", "ouro", "noite_c", "ouro_e")),
    ("cartao_desativado.png", lambda: cartao("contorno", "madeira_e", "noite_e", "noite")),
    ("painel_pergaminho.png", lambda: painel("madeira_e", "madeira_c", "perg", "perg_c")),
    ("painel_escuro.png", lambda: painel("madeira_e", "madeira_c", "noite", "noite_c")),
    ("painel_ouro.png", lambda: painel("ouro_e", "ouro", "noite", "noite_c")),
    ("medidor.png", medidor_moldura),
    ("selo.png", selo),
    ("balao_aviso.png", balao_de_aviso),
    ("vinheta.png", vinheta),
]


def main():
    os.makedirs(ui_lib.DIR_UI, exist_ok=True)
    for nome, fn in PECAS:
        img = fn()
        img.save(os.path.join(ui_lib.DIR_UI, nome))
        print("  %-26s %dx%d" % (nome, img.width, img.height))
    print("ui: %d pecas em arte/ui/" % len(PECAS))


if __name__ == "__main__":
    main()
