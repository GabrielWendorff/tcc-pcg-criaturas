#!/usr/bin/env python3
r"""
gerar_mundo_tiles.py — atlas de tiles isometricos do chao da vila.

Saida: arte/mundo/atlas_terreno.png, uma grade de celulas 32x16.
    linha 0  grama         colunas 0..2  = 3 variantes (sem borda)
    linha 1  caminho       colunas 0..15 = mascara de bordas
    linha 2  terra         idem
    linha 3  areia         idem
    linha 4  agua          idem
    linha 5  rocha         idem
    linha 6  grama_alta    idem
    linha 7  calcada       idem   (distrito industrial)
    linha 8  lavoura       idem   (fazenda)
    linha 9  ponte         idem   (travessia sobre a agua)

MASCARA DE BORDAS. Terrenos que formam manchas (caminho, lago, areia, grama
alta) nao podem terminar num corte reto no limite do losango — o resultado
parece um mosaico de azulejos, nao uma clareira. Entao cada um desses terrenos
tem 16 versoes, uma por subconjunto das 4 arestas do losango:

    bit 1 = NO (vizinho x-1)   bit 4 = SE (vizinho x+1)
    bit 2 = NE (vizinho y-1)   bit 8 = SO (vizinho y+1)

O bit LIGADO significa "deste lado o terreno ACABA" — a aresta recebe o
tratamento de transicao (dithering para a grama, faixa de espuma na agua,
degrau de sombra na rocha). Quem calcula a mascara e o carregador do mapa em
GDScript (MundoIso._mascara_de_bordas), a partir da grade de terreno; aqui so
se desenha o resultado. Assim o formato do lago fica no dado do mapa e nao na
arte, e um lago diferente nao pede um PNG novo.

Regerar:  python3 tools/arte/gerar_mundo_tiles.py
Nunca editar o PNG a mao — ele e saida.
"""

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mundo_lib import (  # noqa: E402
    ALT, DIR_MUNDO, DIR_PREVIEW, LARG, NE, NO, SE, SO, Tela,
    bayer, borda_mais_proxima, distancias_borda, dentro, losango, ruido, tom,
    salvar_folha_contato,
)

# Ordem das linhas do atlas.
LINHAS = ["grama", "caminho", "terra", "areia", "agua", "rocha", "grama_alta",
          "calcada", "lavoura", "ponte"]
VARIANTES_GRAMA = 3

# Pesos das 3 variantes de grama. A florida e rara de proposito: repetida, ela
# vira padronagem visivel e denuncia a grade.
PESOS_GRAMA = [0.55, 0.39, 0.06]

# Quais vizinhos NAO produzem transicao, por terreno. O bit da aresta so acende
# quando o vizinho esta fora do grupo.
#
# A areia agrupa com a agua porque a transicao praia/agua ja e desenhada pela
# faixa de espuma do tile de agua: dar dithering tambem do lado da areia
# produziria duas transicoes empilhadas na mesma aresta. O caminho agrupa com a
# terra porque praca e trilha sao o mesmo chao batido, so com acabamento
# diferente.
GRUPOS_DE_TRANSICAO = {
    # Calcada, caminho e terra sao TODOS chao de circulacao: onde um encosta no
    # outro nao ha transicao a desenhar, so mudanca de acabamento. Se a calcada
    # nao entrasse nos grupos do caminho e da terra, cada quarteirao do distrito
    # apareceria com uma franja de grama dentro da propria rua.
    "caminho": ["caminho", "terra", "calcada"],
    "terra": ["terra", "caminho", "calcada", "lavoura"],
    "calcada": ["calcada", "caminho", "terra"],
    # A lavoura encosta na terra das carreiras; contra a grama, ela dithera.
    "lavoura": ["lavoura", "terra"],
    # A ponte e continuacao da estrada: flush com caminho e terra, e so nas
    # arestas sobre a agua ela mostra o fim das tabuas.
    "ponte": ["ponte", "caminho", "terra"],
    "areia": ["areia", "agua"],
    "agua": ["agua"],
    "rocha": ["rocha"],
    "grama_alta": ["grama_alta"],
}


def _base(tela, material, semente, granulacao=0.30):
    """Preenche o losango com a rampa do material, granulada por ruido fixo.

    O ruido e uma funcao de (x, y) — nao um sorteio —, entao regerar a arte nao
    move um pixel. Isso importa: o tile e conteudo autoral versionado, e um
    diff de PNG que muda a cada execucao deixaria de ser revisavel.
    """
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            r = ruido(x, y, semente)
            if r < granulacao * 0.45:
                idx = 1
            elif r < granulacao:
                idx = 3
            else:
                idx = 2
            tela.por(x, y, tom(material, idx))


def _tufos_grama(tela, semente, densidade=0.10, material="grama"):
    """Tufos de 2-3px verticais. Sao eles que dao leitura de 'grama' — sem
    nenhuma estrutura vertical o tile le como um tapete liso de ruido."""
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            if ruido(x, y, semente + 77) > densidade:
                continue
            alto = 2 if ruido(x, y, semente + 91) < 0.6 else 3
            for k in range(alto):
                if dentro(x, y - k):
                    tela.por(x, y - k, tom(material, 3 if k == alto - 1 else 1))


def _dither_borda(tela, mascara, material_vizinho, profundidade=4.0, semente=0):
    """Desmancha as arestas ligadas em `mascara` com dithering ordenado.

    O Bayer 4x4 e proposital em vez de ruido: o padrao ordenado alterna pixel
    sim/pixel nao de forma regular, que e como pixel art resolve gradiente sem
    meio-tom. Ruido puro no limiar produz sujeira e cintila entre tiles vizinhos.
    """
    if mascara == 0:
        return
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            d = distancias_borda(x, y)
            perto = min((d[b] for b in (NO, NE, SE, SO) if mascara & b),
                        default=None)
            if perto is None or perto > profundidade:
                continue
            t = perto / profundidade                       # 0 na aresta, 1 dentro
            if bayer(x, y) > t * 0.9 + ruido(x, y, semente) * 0.12:
                idx = 2 if ruido(x, y, semente + 5) > 0.35 else 1
                tela.por(x, y, tom(material_vizinho, idx))


def _luz_por_aresta(tela, mascara):
    """Uma linha de 1px mais clara nas arestas NO/NE e mais escura nas SE/SO.

    Sol no alto a esquerda: sem isso, uma mancha de caminho no meio da grama
    fica chapada e o desenho perde o volume que o resto do cenario tem.

    O efeito e fraco de proposito. Num caminho de 2 a 3 celulas de largura quase
    toda celula e celula de borda, entao o realce cai em quase todos os tiles —
    forte demais, ele deixa de ler como luz e passa a desenhar a grade."""
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            lado, dist = borda_mais_proxima(x, y)
            if dist > 1.2 or not (mascara & lado):
                continue
            c = tela.ler(x, y)
            if c is None:
                continue
            k = 13 if lado in (NO, NE) else -11
            tela.por(x, y, tuple(max(0, min(255, v + k)) for v in c[:3]))


# ------------------------------------------------------------------ terrenos
def grama(variante):
    t = Tela(LARG, ALT)
    _base(t, "grama", semente=10 + variante, granulacao=0.26)
    _tufos_grama(t, semente=10 + variante, densidade=0.07)
    if variante == 2:                    # variante florida, usada com parcimonia
        for i, (fx, fy) in enumerate(((11, 6), (20, 9), (16, 4))):
            t.por(fx, fy, (0xef, 0xe4, 0x93))
            t.por(fx, fy - 1, (0xf7, 0xf2, 0xc6))
            t.por(fx + 1, fy, (0xe2, 0xc8, 0x6d) if i else (0xe8, 0xa8, 0xc0))
    return t


def caminho(mascara):
    t = Tela(LARG, ALT)
    _base(t, "caminho", semente=30, granulacao=0.30)
    for y, x0, x1 in losango():          # seixos
        for x in range(x0, x1 + 1):
            if ruido(x, y, 33) < 0.045:
                t.por(x, y, tom("caminho", 0))
                if dentro(x, y - 1):
                    t.por(x, y - 1, tom("caminho", 3))
    _dither_borda(t, mascara, "grama", profundidade=4.5, semente=31)
    _luz_por_aresta(t, mascara)
    return t


def terra(mascara):
    t = Tela(LARG, ALT)
    _base(t, "terra", semente=40, granulacao=0.26)
    # Lajota da praca: sulcos nos dois eixos da grade, espacados de meia celula.
    # E o que separa a praca do caminho de terra batida — sem eles as duas
    # manchas marrons no centro da vila leem como uma so.
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            if (x + 2 * y) % 16 in (0, 1) or (x - 2 * y) % 16 in (0, 1):
                t.por(x, y, tom("terra", 0))
            elif (x + 2 * y) % 16 == 2 or (x - 2 * y) % 16 == 2:
                t.por(x, y, tom("terra", 3))
    _dither_borda(t, mascara, "grama", profundidade=3.5, semente=41)
    _luz_por_aresta(t, mascara)
    return t


def areia(mascara):
    t = Tela(LARG, ALT)
    _base(t, "areia", semente=50, granulacao=0.28)
    _dither_borda(t, mascara, "grama", profundidade=5.0, semente=51)
    _luz_por_aresta(t, mascara)
    return t


def agua(mascara):
    """Agua. As arestas ligadas encostam em terra: recebem faixa rasa clara e
    uma linha de espuma. As arestas desligadas sao agua aberta e ficam lisas —
    e o que faz duas celulas de lago vizinhas nao mostrarem costura."""
    t = Tela(LARG, ALT)
    _base(t, "agua", semente=60, granulacao=0.22)
    for y, x0, x1 in losango():          # brilho especular em faixas horizontais
        for x in range(x0, x1 + 1):
            if ruido(x // 3, y, 61) < 0.10 and y % 2 == 0:
                t.por(x, y, tom("agua", 3))
    if mascara:
        for y, x0, x1 in losango():
            for x in range(x0, x1 + 1):
                d = distancias_borda(x, y)
                perto = min((d[b] for b in (NO, NE, SE, SO) if mascara & b),
                            default=99.0)
                # A espuma e QUEBRADA de proposito. Uma linha branca continua
                # desenha o contorno de cada tile e denuncia a grade: o lago
                # passa a ler como um poligono de degraus em vez de uma margem.
                if perto <= 1.6 and bayer(x, y) < 0.62 + 0.3 * ruido(x, y, 63):
                    t.por(x, y, (0xd6, 0xe8, 0xef))              # espuma
                elif perto <= 3.4 and bayer(x, y) < 0.8:
                    t.por(x, y, tom("agua", 3))                  # raso
                elif perto <= 5.0 and bayer(x, y) < 0.4:
                    t.por(x, y, tom("agua", 2))
    return t


def rocha(mascara):
    t = Tela(LARG, ALT)
    _base(t, "rocha", semente=70, granulacao=0.36)
    for y, x0, x1 in losango():          # fissuras
        for x in range(x0, x1 + 1):
            if ruido(x, y, 71) < 0.05:
                t.por(x, y, tom("rocha", 0))
    _dither_borda(t, mascara, "grama", profundidade=3.0, semente=72)
    _luz_por_aresta(t, mascara)
    return t


def grama_alta(mascara):
    """Grama alta. Marca no chao, sem nenhum comportamento, as areas reservadas
    aos futuros encontros com monstros: quem olha o mapa ve onde a mecanica vai
    entrar antes de ela existir."""
    t = Tela(LARG, ALT)
    _base(t, "grama_alta", semente=80, granulacao=0.44)
    _tufos_grama(t, semente=80, densidade=0.34, material="grama_alta")
    _tufos_grama(t, semente=83, densidade=0.16, material="grama")
    _dither_borda(t, mascara, "grama", profundidade=4.0, semente=81)
    return t


def calcada(mascara):
    """Pedra de calcada do distrito industrial.

    Lajota RETANGULAR e alinhada aos eixos da grade — e o que separa a rua
    construida do chao batido da vila, que usa sulco em X. A mancha de ferrugem
    e rara e fixa por ruido: e ela que diz que esta rua e velha sem precisar de
    um segundo tile."""
    t = Tela(LARG, ALT)
    _base(t, "calcada", semente=90, granulacao=0.24)
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            # Duas familias de juntas, deslocadas: lajota corrida, nao xadrez.
            junta_a = (x + 2 * y) % 12 == 0
            junta_b = (x - 2 * y) % 24 < 1 and (x + 2 * y) % 24 < 12
            if junta_a or junta_b:
                t.por(x, y, tom("calcada", 0))
            elif (x + 2 * y) % 12 == 1:
                t.por(x, y, tom("calcada", 3))          # quina da lajota ao sol
            elif ruido(x, y, 91) < 0.012:
                # Ferrugem RARA. A 5% ela virava sardas espalhadas e a rua lia
                # como cascalho colorido; a 1,2% ela e mancha, que e o que uma
                # rua velha tem.
                t.por(x, y, tom("ferrugem", 1))
    _dither_borda(t, mascara, "grama", profundidade=3.0, semente=93)
    _luz_por_aresta(t, mascara)
    return t


def lavoura(mascara):
    """Terra arada: carreiras paralelas com crista clara e sulco escuro.

    As carreiras seguem UM eixo da grade (o mesmo em todo o tile) porque e assim
    que se ara: a leitura de 'plantado' vem da direcao repetida, e alternar a
    direcao por tile transformaria o talhao num tabuleiro."""
    t = Tela(LARG, ALT)
    _base(t, "lavoura", semente=100, granulacao=0.30)
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            faixa = (x + 2 * y) % 8
            if faixa in (0, 1):
                t.por(x, y, tom("lavoura", 0))          # sulco
            elif faixa in (3, 4):
                t.por(x, y, tom("lavoura", 3))          # crista, virada ao sol
            if ruido(x, y, 101) < 0.05:
                t.por(x, y, tom("terra", 1))            # torrao
    _dither_borda(t, mascara, "grama", profundidade=3.5, semente=102)
    _luz_por_aresta(t, mascara)
    return t


def ponte(mascara):
    """Deck de tabuas sobre a agua.

    As arestas ligadas NAO ditheram: elas recebem o topo escuro da longarina. A
    ponte e um objeto construido, e objeto construido tem quina — desmanchar a
    borda em pontilhado a faria parecer uma mancha de madeira boiando."""
    t = Tela(LARG, ALT)
    _base(t, "tabua", semente=110, granulacao=0.14)
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            fresta = (x - 2 * y) % 7
            if fresta == 0:                             # fresta entre tabuas
                t.por(x, y, tom("tabua", 0))
            elif fresta == 1:
                t.por(x, y, tom("tabua", 3))            # quina da tabua ao sol
            elif fresta == 6:
                t.por(x, y, tom("tabua", 1))            # sombra na outra quina
            elif ruido(x, y, 111) < 0.05:               # no da madeira
                t.por(x, y, tom("tabua", 1))
    for y, x0, x1 in losango():
        for x in range(x0, x1 + 1):
            lado, dist = borda_mais_proxima(x, y)
            if not (mascara & lado):
                continue
            if dist <= 1.2:
                t.por(x, y, tom("tabua", 0))            # longarina
            elif dist <= 2.2 and lado in (SE, SO):
                t.por(x, y, tom("tabua", 1))            # sombra da guarda
    return t


CONSTRUTORES = {
    "caminho": caminho, "terra": terra, "areia": areia,
    "agua": agua, "rocha": rocha, "grama_alta": grama_alta,
    "calcada": calcada, "lavoura": lavoura, "ponte": ponte,
}


def main():
    colunas, linhas = 16, len(LINHAS)
    atlas = Image.new("RGBA", (colunas * LARG, linhas * ALT), (0, 0, 0, 0))
    galeria = []

    for lin, nome in enumerate(LINHAS):
        if nome == "grama":
            for col in range(VARIANTES_GRAMA):
                im = grama(col).imagem()
                atlas.alpha_composite(im, (col * LARG, lin * ALT))
                galeria.append((f"grama_{col}", im))
            continue
        for mascara in range(16):
            im = CONSTRUTORES[nome](mascara).imagem()
            atlas.alpha_composite(im, (mascara * LARG, lin * ALT))
            if mascara in (0, 5, 15):
                galeria.append((f"{nome}_{mascara:02d}", im))

    os.makedirs(DIR_MUNDO, exist_ok=True)
    destino = os.path.join(DIR_MUNDO, "atlas_terreno.png")
    atlas.save(destino)

    # Indice do atlas. E a fonte unica de verdade sobre onde cada terreno mora e
    # como se escolhe o tile: quem le sao o carregador em GDScript e o
    # previsualizador em Python, que precisam concordar pixel a pixel — se cada
    # um trouxesse a sua copia da tabela, a previa deixaria de valer como
    # conferencia do jogo.
    indice = os.path.join(DIR_MUNDO, "atlas_terreno.json")
    with open(indice, "w", encoding="utf-8") as f:
        json.dump({
            "_meta": {
                "descricao": "Indice do atlas de terreno isometrico.",
                "gerado_por": "tools/arte/gerar_mundo_tiles.py",
                "aviso": "Saida de ferramenta. Nao editar a mao.",
                "mascara_de_bordas": {
                    "NO": 1, "NE": 2, "SE": 4, "SO": 8,
                    "vizinho_NO": [-1, 0], "vizinho_NE": [0, -1],
                    "vizinho_SE": [1, 0], "vizinho_SO": [0, 1],
                },
            },
            "arquivo": "atlas_terreno.png",
            "celula": [LARG, ALT],
            "linhas": {nome: i for i, nome in enumerate(LINHAS)},
            "com_mascara": [n for n in LINHAS if n != "grama"],
            "pesos_grama": PESOS_GRAMA,
            "grupos_de_transicao": GRUPOS_DE_TRANSICAO,
        }, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"ok  {indice}")
    salvar_folha_contato(galeria, os.path.join(DIR_PREVIEW, "mundo_terreno.png"),
                         colunas=6)
    print(f"ok  {destino}  ({atlas.width}x{atlas.height}, "
          f"{colunas}x{linhas} celulas de {LARG}x{ALT})")
    for lin, nome in enumerate(LINHAS):
        n = VARIANTES_GRAMA if nome == "grama" else 16
        print(f"    linha {lin}: {nome:12s} {n:2d} celulas")


if __name__ == "__main__":
    main()
