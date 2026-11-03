#!/usr/bin/env python3
r"""
Gera a fonte pixel da interface a partir de tools/arte/fonte_glifos.py.

Saida (arte/ui/):
    fonte_pixel.png / .fnt      1x — corpo de texto, 11px de caixa
    fonte_pixel_2x.png / .fnt   2x — titulos de painel
    fonte_pixel_3x.png / .fnt   3x — cartaz de tela cheia (CRIATURA ENCONTRADA)

Formato .fnt (BMFont texto): Godot 4 importa nativamente como FontFile.

POR QUE DUAS FOLHAS EM VEZ DE UMA ESCALADA EM TEMPO DE EXECUCAO
Uma fonte de bitmap pedida num tamanho maior que o nativo e REAMOSTRADA pela
engine, e o filtro come as bordas do pixel — o titulo sairia borrado justamente
onde a leitura de pixel art precisa ser mais nitida. Ampliar por vizinho mais
proximo aqui, em tempo de geracao, mantem cada pixel um quadrado exato.

    python3 tools/arte/gerar_fonte.py
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fonte_glifos as G
import ui_lib

LARG, ALT = 5, 11          # caixa do glifo
LINHA_CORPO = 2            # onde as 7 linhas do corpo comecam
BASE = 9                   # linha de base, medida do topo da caixa
AVANCO = LARG + 1          # 1px de espaco entre caracteres
COLUNAS = 16
BRANCO = (255, 255, 255, 255)


def _vazio():
    return ["." * LARG for _ in range(ALT)]


def _pintar(linhas, origem, desenho):
    """Escreve `desenho` (lista de linhas) a partir da linha `origem`."""
    for i, linha in enumerate(desenho):
        y = origem + i
        if 0 <= y < ALT:
            fundida = list(linhas[y])
            for x, c in enumerate(linha):
                if c == "#":
                    fundida[x] = "#"
            linhas[y] = "".join(fundida)
    return linhas


def montar(caractere):
    """Caixa 5x11 completa de um caractere, com acento e descida no lugar."""
    if caractere in G.ACENTUADOS:
        base, acento, desloca = G.ACENTUADOS[caractere]
        linhas = montar(base)
        return _pintar(linhas, desloca, G.ACENTOS[acento])
    if caractere in G.CEDILHADOS:
        linhas = montar(G.CEDILHADOS[caractere])
        return _pintar(linhas, BASE, G.CEDILHA)

    linhas = _vazio()
    linhas = _pintar(linhas, LINHA_CORPO, G.CORPO[caractere])
    if caractere in G.DESCIDA:
        linhas = _pintar(linhas, BASE, G.DESCIDA[caractere])
    return linhas


def caracteres():
    """Ordem estavel: define a posicao de cada glifo na folha, e uma folha que
    muda de arranjo a cada geracao produz diff ilegivel."""
    ordem = [c for c in G.CORPO if c != "ı"]
    ordem += list(G.ACENTUADOS) + list(G.CEDILHADOS)
    return ordem


def gerar(escala=1):
    chars = caracteres()
    linhas_folha = (len(chars) + COLUNAS - 1) // COLUNAS
    folha = ui_lib.tela(LARG * COLUNAS * escala, ALT * linhas_folha * escala)

    metricas = []
    for i, ch in enumerate(chars):
        cel = montar(ch)
        cx, cy = (i % COLUNAS) * LARG * escala, (i // COLUNAS) * ALT * escala
        for y, linha in enumerate(cel):
            for x, c in enumerate(linha):
                if c != "#":
                    continue
                # Cada pixel logico vira um bloco escala x escala. Vizinho mais
                # proximo por construcao: nao ha reamostragem, ha replicacao.
                for dy in range(escala):
                    for dx in range(escala):
                        ui_lib.px(folha, cx + x * escala + dx,
                                  cy + y * escala + dy, BRANCO)
        metricas.append((ch, cx, cy))
    return folha, metricas, chars


def escrever_fnt(caminho, nome_png, metricas, folha, escala):
    linhas = [
        'info face="PixelTCC" size=%d bold=0 italic=0 charset="" unicode=1'
        ' stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0' % (ALT * escala),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % ((ALT + 2) * escala, BASE * escala, folha.width, folha.height),
        'page id=0 file="%s"' % nome_png,
        "chars count=%d" % len(metricas),
    ]
    for ch, x, y in metricas:
        linhas.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0"
            " xadvance=%d page=0 chnl=15"
            % (ord(ch), x, y, LARG * escala, ALT * escala, AVANCO * escala))
    with open(caminho, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")


def main():
    os.makedirs(ui_lib.DIR_UI, exist_ok=True)
    for escala, sufixo in ((1, ""), (2, "_2x"), (3, "_3x")):
        folha, metricas, chars = gerar(escala)
        nome_png = "fonte_pixel%s.png" % sufixo
        folha.save(os.path.join(ui_lib.DIR_UI, nome_png))
        escrever_fnt(os.path.join(ui_lib.DIR_UI, "fonte_pixel%s.fnt" % sufixo),
                     nome_png, metricas, folha, escala)
        print("fonte %dx: %d glifos, folha %dx%d"
              % (escala, len(chars), folha.width, folha.height))


if __name__ == "__main__":
    main()
