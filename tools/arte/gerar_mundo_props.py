#!/usr/bin/env python3
r"""
gerar_mundo_props.py — casas, arvores, pedras, penhascos e decoracao da vila.

Saida:
    arte/mundo/props/<nome>.png   um PNG por prop
    arte/mundo/props.json         ancora, pegada em celulas e poligono de colisao

Props sao SPRITES, nao tiles: ficam num no proprio, com colisao propria, dentro
do container ordenado por profundidade (y-sort). E por isso que eles podem ser
mais altos que a celula — uma arvore de 48px numa celula de 16px de altura — e
mesmo assim o jogador passa corretamente na frente ou atras dela.

CONVENCAO DE ANCORA. Cada PNG declara em props.json a sua `ancora`: o pixel do
sprite que deve cair sobre o CENTRO da celula (ou, em props de varias celulas, o
centro da pegada). O carregador em GDScript faz apenas

    sprite.centered = false
    sprite.offset   = -ancora
    no.position     = centro_da_pegada

de modo que a ordenacao por profundidade use a posicao do PE do prop, e nao a do
canto do quadro — que e o que faz a casa ficar atras do jogador quando ele desce
por baixo dela.

PROJECAO. Tudo aqui e construido no espaco da GRADE (gx, gy em celulas, dz em
pixels de altura) e projetado por _iso(). Desenhar direto em pixels de tela
funcionaria para uma caixa, mas nao para um telhado de quatro aguas: as faces
so ficam coerentes se as arestas vierem todas da mesma projecao.

    _iso(gx, gy, dz) = (X0 + (gx - gy)*16,  Y0 + (gx + gy)*8 - dz)

Luz no alto a ESQUERDA (mesma de corpos_lib e dos tiles). Ordem de claridade das
faces: NO > NE > SO > SE.

Regerar:  python3 tools/arte/gerar_mundo_props.py
Nunca editar os PNGs nem o JSON a mao — sao saida.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mundo_lib import (  # noqa: E402
    CONTORNO, CONTORNO_SUAVE, DIR_MUNDO, DIR_PREVIEW, Tela, ruido,
    salvar_folha_contato, tom,
)

MEIA_L, MEIA_A = 16, 8          # meia celula: (gx-gy)*16, (gx+gy)*8
DIR_PROPS = os.path.join(DIR_MUNDO, "props")

_catalogo = {}


class Cena:
    """Tela com projecao isometrica de grade acoplada.

    X0/Y0 sao escolhidos para que a pegada W x D encoste na base do quadro e
    fique centrada nele; assim a ancora e sempre o centro da pegada.
    """

    def __init__(self, larg_cel, prof_cel, altura_px, folga_x=0):
        self.W, self.D = larg_cel, prof_cel
        self.larg = (larg_cel + prof_cel) * MEIA_L + folga_x * 2
        self.alt = (larg_cel + prof_cel) * MEIA_A + altura_px
        self.X0 = prof_cel * MEIA_L + folga_x
        self.Y0 = altura_px
        self.tela = Tela(self.larg, self.alt)

    def iso(self, gx, gy, dz=0.0):
        return (self.X0 + (gx - gy) * MEIA_L,
                self.Y0 + (gx + gy) * MEIA_A - dz)

    @property
    def ancora(self):
        """Centro da pegada, em pixels do sprite."""
        return [int(self.X0 + (self.W - self.D) * MEIA_L / 2),
                int(self.Y0 + (self.W + self.D) * MEIA_A / 2)]

    def face(self, pontos_grade, cor):
        self.tela.poligono([self.iso(*p) for p in pontos_grade], cor)

    def aresta(self, p, q, cor):
        (x0, y0), (x1, y1) = self.iso(*p), self.iso(*q)
        self.tela.linha(x0, y0, x1, y1, cor)


def pegada_losango(W, D, encolher=0.0):
    """Quatro cantos, em pixels relativos a ancora, do losango que a pegada
    W x D ocupa no chao. Vira o CollisionPolygon2D do prop.

    E a projecao da AREA NO CHAO, nao a caixa do sprite: colidir com o quadro
    faria o jogador esbarrar no ar acima do telhado, a dois metros da parede.
    `encolher` recua o poligono para dentro — uma arvore ocupa bem menos chao
    que a celula em que esta plantada."""
    ex = (W + D) * MEIA_L / 2 * (1.0 - encolher)
    ey = (W + D) * MEIA_A / 2 * (1.0 - encolher)
    return [[0, -ey], [ex, 0], [0, ey], [-ex, 0]]


def registrar(nome, cena, celulas, colisao, altura_colisao=None):
    os.makedirs(DIR_PROPS, exist_ok=True)
    img = cena.tela.imagem()
    img.save(os.path.join(DIR_PROPS, f"{nome}.png"))
    _catalogo[nome] = {
        "arquivo": f"{nome}.png",
        "tamanho": [cena.larg, cena.alt],
        "ancora": cena.ancora,
        "celulas": list(celulas),
        "colisao": colisao,
    }
    return nome, img


# ------------------------------------------------------------------- casas
def casa(nome, W=2, D=2, parede="parede", telha="telha_rubi",
         h_parede=17, h_telhado=13, porta="SO", var=0,
         toldo=None, chamine=None):
    """Casa isometrica: caixa de paredes + telhado de quatro aguas.

    O telhado tem cumeeira quando a pegada nao e quadrada e vira piramide quando
    e — que e o comportamento correto de um telhado de quatro aguas, e nao um
    caso especial: com W == D as duas metades da cumeeira colapsam no mesmo ponto.
    """
    beiral = 0.17                     # avanco do telhado, em celulas
    c = Cena(W, D, altura_px=h_parede + h_telhado + 4, folga_x=4)

    # --- paredes (faces SO e SE, as duas voltadas para a camera) ---
    c.face([(0, D), (W, D), (W, D), (0, D)], None)
    c.face([(0, D, 0), (W, D, 0), (W, D, h_parede), (0, D, h_parede)],
           tom(parede, 2))                                   # face SO (esquerda)
    c.face([(W, D, 0), (W, 0, 0), (W, 0, h_parede), (W, D, h_parede)],
           tom(parede, 1))                                   # face SE (direita)

    # rodape: uma faixa de pedra na base tira o ar de "caixa flutuando"
    c.face([(0, D, 0), (W, D, 0), (W, D, 3), (0, D, 3)], tom("rocha", 1))
    c.face([(W, D, 0), (W, 0, 0), (W, 0, 3), (W, D, 3)], tom("rocha", 0))

    # --- telhado de quatro aguas ---
    bx0, bx1 = -beiral, W + beiral
    by0, by1 = -beiral, D + beiral
    z = h_parede
    cum = h_parede + h_telhado
    if W >= D:                        # cumeeira ao longo de gx
        s0, s1 = (W * 0.28, D / 2.0), (W * 0.72, D / 2.0)
    else:
        s0, s1 = (W / 2.0, D * 0.28), (W / 2.0, D * 0.72)
    P0 = (s0[0], s0[1], cum)
    P1 = (s1[0], s1[1], cum)
    A = (bx0, by0, z)                 # canto norte  (topo da tela)
    B = (bx1, by0, z)                 # canto leste  (direita)
    C = (bx1, by1, z)                 # canto sul    (baixo)
    Dd = (bx0, by1, z)                # canto oeste  (esquerda)
    if W >= D:
        c.face([A, B, P1, P0], tom(telha, 3))     # agua NE -> vira a luz
        c.face([B, C, P1], tom(telha, 1))         # hip SE
        c.face([C, Dd, P0, P1], tom(telha, 2))    # agua SO
        c.face([Dd, A, P0], tom(telha, 3))        # hip NO
    else:
        c.face([A, B, P0], tom(telha, 3))
        c.face([B, C, P1, P0], tom(telha, 2))
        c.face([C, Dd, P1], tom(telha, 1))
        c.face([Dd, A, P0, P1], tom(telha, 3))
    c.aresta(P0, P1, tom(telha, 3))               # cumeeira
    for p, q in ((A, P0), (B, P1) if W >= D else (B, P0), (C, P1), (Dd, P0)):
        c.aresta(p, q, tom(telha, 0))             # espigoes

    # --- porta e janelas ---
    def na_face_so(gx, dz, larg, alt, cor):
        c.face([(gx, D, dz), (gx + larg, D, dz),
                (gx + larg, D, dz + alt), (gx, D, dz + alt)], cor)

    def na_face_se(gy, dz, prof, alt, cor):
        c.face([(W, D - gy, dz), (W, D - gy - prof, dz),
                (W, D - gy - prof, dz + alt), (W, D - gy, dz + alt)], cor)

    if porta == "SO":
        na_face_so(W / 2.0 - 0.24, 0, 0.48, 12, CONTORNO)
        na_face_so(W / 2.0 - 0.20, 0, 0.40, 11, tom("madeira", 1))
        na_face_so(W / 2.0 - 0.15, 1, 0.30, 9, tom("madeira", 2))
        if W > 1.2:
            na_face_so(0.20, 7, 0.34, 7, CONTORNO)
            na_face_so(0.23, 8, 0.28, 5, tom("agua", 0))
        na_face_se(D / 2.0 - 0.19, 7, 0.38, 7, CONTORNO)
        na_face_se(D / 2.0 - 0.16, 8, 0.32, 5, tom("agua", 0))
    else:
        na_face_se(D / 2.0 - 0.24, 0, 0.48, 12, CONTORNO)
        na_face_se(D / 2.0 - 0.20, 0, 0.40, 11, tom("madeira", 1))
        na_face_se(D / 2.0 - 0.15, 1, 0.30, 9, tom("madeira", 2))
        na_face_so(W / 2.0 - 0.19, 7, 0.38, 7, CONTORNO)
        na_face_so(W / 2.0 - 0.16, 8, 0.32, 5, tom("agua", 0))
        if W > 1.2:
            na_face_so(W - 0.53, 7, 0.36, 7, CONTORNO)
            na_face_so(W - 0.5, 8, 0.3, 5, tom("agua", 0))

    # --- toldo sobre a porta (padaria, comercio) ---
    # Listrado, e nao chapado: e a listra que diz "loja" a 32px de distancia.
    # Sai da fachada da porta, com a mesma projecao das outras faces — um
    # retangulo desenhado direto em pixels de tela nao encostaria na parede.
    if toldo is not None:
        z = h_parede - 3
        avanco = 0.42
        if porta == "SO":
            a, b = (0.15, D), (W - 0.15, D)
            a2, b2 = (0.15, D + avanco), (W - 0.15, D + avanco)
        else:
            a, b = (W, 0.15), (W, D - 0.15)
            a2, b2 = (W + avanco, 0.15), (W + avanco, D - 0.15)
        c.face([(a[0], a[1], z), (b[0], b[1], z),
                (b2[0], b2[1], z - 7), (a2[0], a2[1], z - 7)], tom(toldo, 2))
        listras = 6
        for i in range(0, listras, 2):
            t0, t1 = i / listras, (i + 1) / listras
            def _mistura(p, q, t):
                return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
            p0, p1 = _mistura(a, b, t0), _mistura(a, b, t1)
            q0, q1 = _mistura(a2, b2, t0), _mistura(a2, b2, t1)
            c.face([(p0[0], p0[1], z), (p1[0], p1[1], z),
                    (q1[0], q1[1], z - 7), (q0[0], q0[1], z - 7)],
                   tom("parede", 3))
        c.aresta((a2[0], a2[1], z - 7), (b2[0], b2[1], z - 7), tom(toldo, 0))

    # --- chamine ---
    if chamine is not None:
        gx, gy = W * 0.28, D * 0.24
        base = h_parede + h_telhado * 0.45
        topo = base + chamine
        lado = 0.20
        c.face([(gx, gy + lado, base), (gx + lado, gy + lado, base),
                (gx + lado, gy + lado, topo), (gx, gy + lado, topo)],
               tom("tijolo", 2))
        c.face([(gx + lado, gy + lado, base), (gx + lado, gy, base),
                (gx + lado, gy, topo), (gx + lado, gy + lado, topo)],
               tom("tijolo", 1))
        c.face([(gx, gy, topo), (gx + lado, gy, topo),
                (gx + lado, gy + lado, topo), (gx, gy + lado, topo)],
               tom("tijolo", 0))

    c.tela.contornar(CONTORNO)
    cx, cy = c.ancora
    c.tela.sombra_chao(cx + 3, cy + 2, (W + D) * MEIA_L / 2 - 1,
                       (W + D) * MEIA_A / 2 - 1, alpha=70)
    return registrar(nome, c, (W, D), {
        "tipo": "poligono", "pontos": pegada_losango(W, D, encolher=0.06)})


# ---------------------------------------------------------------- vegetacao
def arvore(nome, tronco=8, raio=12, folha="folha", copas=4, semente=0):
    """Arvore frondosa: tronco curto e copa larga.

    A proporcao importa mais do que parece: com tronco longo e copa pequena a
    silhueta le como pirulito e o cenario perde a escala — a arvore precisa
    dominar o quadro para que o jogador de 24px ao lado dela pareca pequeno.
    """
    largura_copa = int(raio * 2.4)
    c = Cena(1, 1, altura_px=tronco + int(raio * 1.9) + 4,
             folga_x=max(0, largura_copa // 2 - MEIA_L + 2))
    t = c.tela
    bx, by = c.ancora
    esp = 2 if raio < 11 else 3
    t.ret(bx - esp, by - tronco - 2, bx + esp - 1, by - 1, tom("tronco", 1))
    t.ret(bx - esp, by - tronco - 2, bx - esp, by - 1, tom("tronco", 2))
    t.ret(bx + esp - 1, by - tronco - 2, bx + esp - 1, by - 1, tom("tronco", 0))

    cy = by - tronco - int(raio * 0.75)
    for i in range(copas):
        ox = int(round((ruido(i, 0, semente) - 0.5) * raio * 1.25))
        oy = int(round((ruido(i, 1, semente) - 0.65) * raio * 0.85))
        rr = raio * (0.62 + 0.42 * ruido(i, 2, semente))
        t.elipse(bx + ox, cy + oy, rr, rr * 0.86, tom(folha, 2))
    t.elipse(bx, cy - raio // 4, raio * 0.95, raio * 0.8, tom(folha, 2))

    for y in range(cy - raio * 2, by):
        for x in range(bx - largura_copa, bx + largura_copa):
            if t.ler(x, y) != tom(folha, 2):
                continue
            if not t.ocupado(x - 1, y - 1) or ruido(x, y, semente + 9) < 0.09:
                t.por(x, y, tom(folha, 3))
            elif not t.ocupado(x + 1, y + 1) or ruido(x, y, semente + 13) < 0.15:
                t.por(x, y, tom(folha, 1))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by + 1, raio * 0.95, raio * 0.48, alpha=80)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.30)})


def pinheiro(nome, altura=34, raio=8, semente=0):
    """Conifera: tres saias triangulares. A silhueta em cone e o que distingue
    a mata da borda do mapa das arvores soltas da vila."""
    c = Cena(1, 1, altura_px=altura + 8, folga_x=raio - 6)
    t = c.tela
    bx, by = c.ancora
    t.ret(bx - 1, by - 7, bx + 1, by - 1, tom("tronco", 1))
    for i in range(3):
        base_y = by - 6 - i * (altura - 12) // 3
        r = raio * (1.0 - i * 0.26)
        h = (altura - 8) // 3 + 4
        t.poligono([(bx - r, base_y), (bx + r, base_y), (bx, base_y - h)],
                   tom("folha_fria", 2))
        t.poligono([(bx - r, base_y), (bx, base_y), (bx, base_y - h)],
                   tom("folha_fria", 3))
        for y in range(int(base_y - h), int(base_y) + 1):
            for x in range(int(bx - r), int(bx + r) + 1):
                if t.ler(x, y) and ruido(x, y, semente + i) < 0.12:
                    t.por(x, y, tom("folha_fria", 1))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by, raio * 0.85, raio * 0.45, alpha=80)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.34)})


def toco(nome):
    c = Cena(1, 1, altura_px=8, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    t.elipse(bx, by - 6, 6, 3, tom("tronco", 2))
    t.ret(bx - 6, by - 6, bx + 6, by - 2, tom("tronco", 1))
    t.elipse(bx, by - 2, 6, 3, tom("tronco", 0))
    t.elipse(bx, by - 6, 6, 3, tom("tronco", 2))
    t.elipse(bx, by - 6, 3, 1, tom("tronco", 3))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 1, by - 1, 7, 3.4, alpha=70)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.45)})


def flores(nome, cor=(0xe8, 0xa8, 0xc0), semente=0):
    """Tufo de flores. Unico prop SEM colisao: e enfeite de chao, e travar o
    jogador numa flor seria pior que o ganho visual."""
    c = Cena(1, 1, altura_px=6, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    for i in range(7):
        fx = bx + int(round((ruido(i, 0, semente) - 0.5) * 20))
        fy = by - 1 - int(round(ruido(i, 1, semente) * 5))
        t.por(fx, fy + 1, tom("grama", 0))
        t.por(fx, fy, cor)
        if ruido(i, 2, semente) < 0.45:
            t.por(fx + 1, fy, tuple(min(255, v + 24) for v in cor))
    return registrar(nome, c, (1, 1), {"tipo": "nenhuma"})


# -------------------------------------------------------------------- pedras
def pedra(nome, raio=7, altura=9, semente=0):
    c = Cena(1, 1, altura_px=altura + 4, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    for i in range(3):
        ox = int(round((ruido(i, 0, semente) - 0.5) * raio))
        oy = int(round(-ruido(i, 1, semente) * altura * 0.6))
        rr = raio * (0.6 + 0.45 * ruido(i, 2, semente))
        t.elipse(bx + ox, by - 3 + oy, rr, rr * 0.75, tom("rocha", 2))
    for y in range(by - altura - 4, by + 1):
        for x in range(bx - raio * 2, bx + raio * 2):
            if t.ler(x, y) != tom("rocha", 2):
                continue
            if not t.ocupado(x - 1, y - 1):
                t.por(x, y, tom("rocha", 3))
            elif not t.ocupado(x + 1, y + 1):
                t.por(x, y, tom("rocha", 1))
            elif ruido(x, y, semente + 4) < 0.08:
                t.por(x, y, tom("rocha", 1))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by, raio * 0.9, raio * 0.45, alpha=75)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.28)})


def penhasco(nome, altura=16, semente=0):
    """Bloco de rocha de uma celula com topo gramado.

    Existe para dar ao mapa uma BORDA com relevo em vez de uma parede invisivel:
    o jogador ve um paredao, entende que a regiao continua alem dele e nao fica
    esbarrando num limite que nao explica a si mesmo. Como e um cubo isometrico
    exato, blocos vizinhos encaixam sem costura.
    """
    c = Cena(1, 1, altura_px=altura, folga_x=0)
    t = c.tela
    c.face([(0, 1, 0), (1, 1, 0), (1, 1, altura), (0, 1, altura)],
           tom("rocha", 2))                                   # face SO
    c.face([(1, 1, 0), (1, 0, 0), (1, 0, altura), (1, 1, altura)],
           tom("rocha", 1))                                   # face SE
    c.face([(0, 0, altura), (1, 0, altura), (1, 1, altura), (0, 1, altura)],
           tom("grama", 2))                                   # topo
    bx, by = c.ancora
    for y in range(by - altura * 2, by + 1):                   # textura das faces
        for x in range(c.larg):
            v = t.ler(x, y)
            if v == tom("rocha", 2) and ruido(x, y, semente) < 0.12:
                t.por(x, y, tom("rocha", 1))
            elif v == tom("rocha", 1) and ruido(x, y, semente + 1) < 0.12:
                t.por(x, y, tom("rocha", 0))
            elif v == tom("grama", 2) and ruido(x, y, semente + 2) < 0.22:
                t.por(x, y, tom("grama", 1 if ruido(x, y, 3) < 0.5 else 3))
    for gx in range(2):                                        # borda do topo
        c.aresta((gx, 0, altura), (gx, 1, altura), tom("grama", 3))
        c.aresta((0, gx, altura), (1, gx, altura), tom("grama", 3))
    t.contornar(CONTORNO_SUAVE)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.0)})


# --------------------------------------------------------------- construidos
def poco(nome):
    """Poco da praca. Ponto de referencia visual no centro da vila — um mapa sem
    um marco central deixa o jogador sem ancora para se orientar."""
    c = Cena(1, 1, altura_px=26, folga_x=2)
    t = c.tela
    bx, by = c.ancora
    t.elipse(bx, by - 4, 11, 6, tom("rocha", 1))
    t.ret(bx - 11, by - 8, bx + 11, by - 4, tom("rocha", 2))
    t.elipse(bx, by - 8, 11, 6, tom("rocha", 3))
    t.elipse(bx, by - 8, 7, 4, tom("agua", 0))
    t.elipse(bx - 2, by - 9, 3, 2, tom("agua", 2))
    for lado in (-8, 7):                                    # montantes
        t.ret(bx + lado, by - 24, bx + lado + 1, by - 8, tom("madeira", 1))
    t.ret(bx - 10, by - 26, bx + 9, by - 24, tom("telha_musgo", 2))
    t.ret(bx - 10, by - 26, bx - 1, by - 25, tom("telha_musgo", 3))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by - 2, 12, 6, alpha=75)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.15)})


def cerca(nome, eixo="x"):
    """Segmento de cerca ao longo de um dos eixos da grade. Dois PNGs cobrem
    todas as direcoes porque numa grade isometrica so ha dois eixos."""
    c = Cena(1, 1, altura_px=14, folga_x=0)
    t = c.tela
    p0, p1 = ((0, 0.5), (1, 0.5)) if eixo == "x" else ((0.5, 0), (0.5, 1))
    for trav in (7, 11):
        c.aresta((p0[0], p0[1], trav), (p1[0], p1[1], trav), tom("madeira", 2))
        c.aresta((p0[0], p0[1], trav - 1), (p1[0], p1[1], trav - 1),
                 tom("madeira", 1))
    for g in (0.08, 0.5, 0.92):
        gx = p0[0] + (p1[0] - p0[0]) * g
        gy = p0[1] + (p1[1] - p0[1]) * g
        x, y = c.iso(gx, gy)
        t.ret(x - 1, y - 13, x, y, tom("madeira", 1))
        t.ret(x - 1, y - 13, x - 1, y, tom("madeira", 2))
    t.contornar(CONTORNO)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.20)})


def placa(nome):
    c = Cena(1, 1, altura_px=22, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    t.ret(bx - 1, by - 14, bx, by - 1, tom("madeira", 1))
    t.ret(bx - 8, by - 22, bx + 7, by - 13, tom("madeira", 2))
    t.ret(bx - 8, by - 22, bx + 7, by - 21, tom("madeira", 3))
    for i in range(3):
        t.ret(bx - 6, by - 20 + i * 3, bx + 3 - i, by - 20 + i * 3,
              tom("madeira", 0))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by, 7, 3, alpha=70)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.45)})


def caixa(nome):
    c = Cena(1, 1, altura_px=13, folga_x=0)
    h = 12
    c.face([(0.12, 0.88, 0), (0.88, 0.88, 0), (0.88, 0.88, h), (0.12, 0.88, h)],
           tom("madeira", 2))
    c.face([(0.88, 0.88, 0), (0.88, 0.12, 0), (0.88, 0.12, h), (0.88, 0.88, h)],
           tom("madeira", 1))
    c.face([(0.12, 0.12, h), (0.88, 0.12, h), (0.88, 0.88, h), (0.12, 0.88, h)],
           tom("madeira", 3))
    c.aresta((0.12, 0.88, h / 2), (0.88, 0.88, h / 2), tom("madeira", 0))
    c.aresta((0.88, 0.88, h / 2), (0.88, 0.12, h / 2), tom("madeira", 0))
    c.tela.contornar(CONTORNO)
    bx, by = c.ancora
    c.tela.sombra_chao(bx + 2, by - 2, 9, 4.5, alpha=70)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.14)})


def bolsa_perdida(nome):
    """Ponto de interesse da Camada 3: uma bolsa de couro com moedas, sem colisao,
    porque o jogador a recolhe ao pisar nela."""
    c = Cena(1, 1, altura_px=12, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    t.elipse(bx, by - 4, 6, 4, tom("madeira", 1))
    t.elipse(bx - 1, by - 5, 4, 3, tom("madeira", 2))
    t.ret(bx - 2, by - 10, bx + 1, by - 8, tom("madeira", 0))
    t.ret(bx - 3, by - 11, bx + 2, by - 10, tom("madeira", 3))
    for dx, dy in ((6, -1), (8, -3), (-7, -1)):
        t.elipse(bx + dx, by + dy, 2, 1, tom("onibus", 3))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 1, by, 8, 3, alpha=70)
    return registrar(nome, c, (1, 1), {"tipo": "nenhuma"})


# ---------------------------------------------------------------------- main

# ------------------------------------------------- distrito industrial
def galpao(nome, W=3, D=2, h_parede=20, telha="metal", parede="metal"):
    """Galpao de telhado de DUAS aguas e portao largo.

    Duas aguas, e nao quatro como a casa: e a diferenca de tipologia que separa
    construcao industrial de casa de vila a distancia, antes de qualquer
    detalhe. O material tambem muda (zinco no lugar de telha ceramica), mas a
    forma e o que se le primeiro.
    """
    h_telhado = 10
    c = Cena(W, D, altura_px=h_parede + h_telhado + 6, folga_x=4)

    c.face([(0, D, 0), (W, D, 0), (W, D, h_parede), (0, D, h_parede)],
           tom(parede, 2))
    c.face([(W, D, 0), (W, 0, 0), (W, 0, h_parede), (W, D, h_parede)],
           tom(parede, 1))
    # Nervuras verticais do zinco. Sao elas que impedem a parede de ler como
    # bloco chapado — telha ondulada nunca e uma superficie lisa.
    passo = 0.34
    x = passo
    while x < W:
        c.aresta((x, D, 0), (x, D, h_parede), tom(parede, 0))
        x += passo
    y = passo
    while y < D:
        c.aresta((W, D - y, 0), (W, D - y, h_parede), tom(parede, 0))
        y += passo

    c.face([(0, D, 0), (W, D, 0), (W, D, 3), (0, D, 3)], tom("rocha", 1))
    c.face([(W, D, 0), (W, 0, 0), (W, 0, 3), (W, D, 3)], tom("rocha", 0))

    beiral = 0.2
    cum = h_parede + h_telhado
    A = (-beiral, -beiral, h_parede)
    B = (W + beiral, -beiral, h_parede)
    C = (W + beiral, D + beiral, h_parede)
    Dd = (-beiral, D + beiral, h_parede)
    P0 = (-beiral, D / 2.0, cum)
    P1 = (W + beiral, D / 2.0, cum)
    c.face([A, B, P1, P0], tom(telha, 3))
    c.face([Dd, C, P1, P0], tom(telha, 1))
    c.aresta(P0, P1, tom(telha, 3))
    c.aresta(A, P0, tom(telha, 0))
    c.aresta(B, P1, tom(telha, 0))

    # portao largo na face SO
    pw = min(1.4, W * 0.5)
    c.face([(W / 2 - pw / 2, D, 0), (W / 2 + pw / 2, D, 0),
            (W / 2 + pw / 2, D, 13), (W / 2 - pw / 2, D, 13)], CONTORNO)
    c.face([(W / 2 - pw / 2 + 0.06, D, 0.5), (W / 2 + pw / 2 - 0.06, D, 0.5),
            (W / 2 + pw / 2 - 0.06, D, 12), (W / 2 - pw / 2 + 0.06, D, 12)],
           tom("ferrugem", 1))
    c.aresta((W / 2, D, 0.5), (W / 2, D, 12), tom("ferrugem", 0))

    c.tela.contornar(CONTORNO)
    cx, cy = c.ancora
    c.tela.sombra_chao(cx + 3, cy + 2, (W + D) * MEIA_L / 2 - 1,
                       (W + D) * MEIA_A / 2 - 1, alpha=70)
    return registrar(nome, c, (W, D), {
        "tipo": "poligono", "pontos": pegada_losango(W, D, encolher=0.06)})


def fabrica(nome, W=3, D=3):
    """A fabrica: volume de tijolo com telhado SHED (dentes de serra) e chamine.

    O telhado dente-de-serra e a assinatura do edificio industrial do seculo
    passado — janela voltada ao norte em cada dente, para luz sem sol direto. E
    o que faz o predio ler como fabrica mesmo em silhueta.
    """
    h_parede = 30
    h_dente = 9
    c = Cena(W, D, altura_px=h_parede + h_dente + 30, folga_x=5)

    c.face([(0, D, 0), (W, D, 0), (W, D, h_parede), (0, D, h_parede)],
           tom("tijolo", 2))
    c.face([(W, D, 0), (W, 0, 0), (W, 0, h_parede), (W, D, h_parede)],
           tom("tijolo", 1))
    # fiadas de tijolo
    z = 4
    while z < h_parede:
        c.aresta((0, D, z), (W, D, z), tom("tijolo", 0))
        c.aresta((W, D, z), (W, 0, z), tom("tijolo", 0))
        z += 5
    c.face([(0, D, 0), (W, D, 0), (W, D, 4), (0, D, 4)], tom("rocha", 1))
    c.face([(W, D, 0), (W, 0, 0), (W, 0, 4), (W, D, 4)], tom("rocha", 0))

    # janelas industriais: duas fileiras de vidro sujo
    for i in range(int(W)):
        x0 = i + 0.22
        c.face([(x0, D, 10), (x0 + 0.56, D, 10),
                (x0 + 0.56, D, 22), (x0, D, 22)], CONTORNO)
        c.face([(x0 + 0.05, D, 10.8), (x0 + 0.51, D, 10.8),
                (x0 + 0.51, D, 21.2), (x0 + 0.05, D, 21.2)], tom("agua", 0))
        c.aresta((x0 + 0.28, D, 10.8), (x0 + 0.28, D, 21.2), CONTORNO_SUAVE)

    # telhado dente de serra, ao longo de gx
    dentes = int(W)
    for i in range(dentes):
        x0, x1 = i, i + 1
        c.face([(x0, -0.1, h_parede), (x1, -0.1, h_parede + h_dente),
                (x1, D + 0.1, h_parede + h_dente), (x0, D + 0.1, h_parede)],
               tom("metal", 2))
        # a face vertical do dente e vidro: e a janela do shed
        c.face([(x1, -0.1, h_parede), (x1, D + 0.1, h_parede),
                (x1, D + 0.1, h_parede + h_dente), (x1, -0.1, h_parede + h_dente)],
               tom("agua", 1))
        c.aresta((x1, -0.1, h_parede + h_dente), (x1, D + 0.1, h_parede + h_dente),
                 tom("metal", 0))

    # chamine de tijolo, alta, com faixa clara e boca escura
    gx, gy, lado = W * 0.12, D * 0.12, 0.34
    base, topo = h_parede, h_parede + 30
    c.face([(gx, gy + lado, base), (gx + lado, gy + lado, base),
            (gx + lado, gy + lado, topo), (gx, gy + lado, topo)], tom("tijolo", 2))
    c.face([(gx + lado, gy + lado, base), (gx + lado, gy, base),
            (gx + lado, gy, topo), (gx + lado, gy + lado, topo)], tom("tijolo", 1))
    for zz in (topo - 5, topo - 7):
        c.aresta((gx, gy + lado, zz), (gx + lado, gy + lado, zz), tom("parede", 2))
        c.aresta((gx + lado, gy + lado, zz), (gx + lado, gy, zz), tom("parede", 1))
    c.face([(gx, gy, topo), (gx + lado, gy, topo),
            (gx + lado, gy + lado, topo), (gx, gy + lado, topo)], CONTORNO)

    c.tela.contornar(CONTORNO)
    cx, cy = c.ancora
    c.tela.sombra_chao(cx + 3, cy + 2, (W + D) * MEIA_L / 2 - 1,
                       (W + D) * MEIA_A / 2 - 1, alpha=70)
    return registrar(nome, c, (W, D), {
        "tipo": "poligono", "pontos": pegada_losango(W, D, encolher=0.06)})


def maquinario(nome, semente=0):
    """Maquina abandonada no patio: bloco enferrujado, volante e cano.

    Nao e um objeto reconhecivel de proposito — o que se le e 'peca pesada que
    ficou'. Uma maquina identificavel pediria detalhe que 32px nao comportam.
    """
    c = Cena(1, 1, altura_px=22, folga_x=2)
    t = c.tela
    bx, by = c.ancora
    t.ret(bx - 11, by - 16, bx + 11, by - 4, tom("ferrugem", 1))
    t.ret(bx - 11, by - 16, bx - 2, by - 4, tom("ferrugem", 2))
    t.ret(bx - 9, by - 14, bx - 4, by - 9, tom("metal", 1))
    for i in range(4):                       # chapas rebitadas
        t.por(bx - 8 + i * 5, by - 6, tom("metal", 3))
        t.por(bx - 8 + i * 5, by - 15, tom("metal", 3))
    t.elipse(bx + 6, by - 18, 5, 5, tom("metal", 2))     # volante
    t.elipse(bx + 6, by - 18, 2, 2, tom("ferrugem", 0))
    t.ret(bx - 2, by - 24, bx + 1, by - 16, tom("metal", 1))   # cano
    t.elipse(bx - 1, by - 24, 3, 2, tom("metal", 3))
    if ruido(1, 2, semente) < 0.5:
        t.ret(bx + 2, by - 9, bx + 9, by - 6, tom("ferrugem", 0))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by - 2, 13, 6, alpha=80)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.18)})


def barril(nome, material="ferrugem"):
    c = Cena(1, 1, altura_px=16, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    t.elipse(bx, by - 4, 7, 3, tom(material, 1))
    t.ret(bx - 7, by - 16, bx + 7, by - 4, tom(material, 2))
    t.ret(bx - 7, by - 16, bx - 2, by - 4, tom(material, 3))
    for zz in (by - 14, by - 9):             # arcos
        t.ret(bx - 7, zz, bx + 7, zz + 1, tom("metal", 1))
    t.elipse(bx, by - 16, 7, 3, tom(material, 3))
    t.elipse(bx, by - 16, 4, 1, tom(material, 1))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 1, by - 2, 8, 4, alpha=75)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.42)})


def chamine(nome, altura=44):
    """Chamine solta no patio — a silhueta que marca o distrito no horizonte."""
    c = Cena(1, 1, altura_px=altura + 8, folga_x=2)
    t = c.tela
    bx, by = c.ancora
    t.elipse(bx, by - 5, 10, 5, tom("tijolo", 1))        # base alargada
    t.ret(bx - 9, by - 12, bx + 9, by - 5, tom("tijolo", 2))
    t.ret(bx - 9, by - 12, bx - 3, by - 5, tom("tijolo", 1))
    t.ret(bx - 5, by - altura, bx + 5, by - 12, tom("tijolo", 2))
    t.ret(bx - 5, by - altura, bx - 1, by - 12, tom("tijolo", 1))
    for i in range(3, altura - 12, 5):                   # fiadas
        t.ret(bx - 5, by - 12 - i, bx + 5, by - 12 - i, tom("tijolo", 0))
    t.ret(bx - 6, by - altura - 3, bx + 6, by - altura, tom("tijolo", 1))
    t.elipse(bx, by - altura - 3, 6, 2, CONTORNO)
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by - 3, 11, 5, alpha=80)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.25)})


# ------------------------------------------------------------- ribeira
def varal_peixe(nome):
    """Varal de peixe secando: dois esteios, uma corda e tres peixes.

    Isto e narrativa de cenario, nao decoracao: diz que alguem pesca aqui todo
    dia, sem nenhuma linha de dialogo.
    """
    c = Cena(1, 1, altura_px=24, folga_x=3)
    t = c.tela
    bx, by = c.ancora
    for dx in (-13, 13):
        t.ret(bx + dx, by - 22, bx + dx + 2, by - 2, tom("tronco", 1))
    t.linha(bx - 12, by - 20, bx + 13, by - 20, tom("tabua", 1))
    for i, dx in enumerate((-8, 0, 8)):
        cor = tom("agua", 2) if i % 2 == 0 else tom("metal", 2)
        t.linha(bx + dx, by - 20, bx + dx, by - 17, tom("tabua", 0))
        t.elipse(bx + dx, by - 13, 3, 5, cor)
        t.por(bx + dx + 1, by - 15, tom("parede", 3))
        t.linha(bx + dx, by - 8, bx + dx - 2, by - 6, cor)
        t.linha(bx + dx, by - 8, bx + dx + 2, by - 6, cor)
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by - 1, 13, 4, alpha=60)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.5)})


def barco(nome):
    """Bote de madeira encalhado na areia."""
    c = Cena(2, 1, altura_px=14, folga_x=3)
    t = c.tela
    bx, by = c.ancora
    t.elipse(bx, by - 6, 22, 7, tom("tabua", 1))
    t.elipse(bx, by - 8, 20, 6, tom("tabua", 2))
    t.elipse(bx, by - 8, 16, 4, tom("tronco", 0))        # bojo interno
    for dx in (-8, 4):                                   # bancos
        t.ret(bx + dx, by - 10, bx + dx + 4, by - 7, tom("tabua", 3))
    t.linha(bx - 18, by - 12, bx + 6, by - 4, tom("tronco", 2))   # remo
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by - 2, 22, 6, alpha=70)
    return registrar(nome, c, (2, 1), {
        "tipo": "poligono", "pontos": pegada_losango(2, 1, encolher=0.2)})


def junco(nome, semente=0):
    """Juncos da margem. SEM colisao, como as flores: sao borda de agua, e o
    jogador precisa poder encostar no rio."""
    c = Cena(1, 1, altura_px=18, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    for i in range(9):
        jx = bx + int(round((ruido(i, 0, semente) - 0.5) * 22))
        alt = 8 + int(ruido(i, 1, semente) * 9)
        incl = 1 if ruido(i, 2, semente) < 0.5 else -1
        cor = tom("folha_fria", 2) if i % 2 else tom("grama_alta", 2)
        t.linha(jx, by - 2, jx + incl * 2, by - 2 - alt, cor)
        t.por(jx + incl * 2, by - 3 - alt, tom("palha", 1))
    t.contornar(CONTORNO_SUAVE)
    return registrar(nome, c, (1, 1), {"tipo": "nenhuma"})


# ------------------------------------------------------------- fazenda
def plantacao(nome, material="milho", altura=16, semente=0):
    """Carreira de pes plantados numa celula. SEM colisao: o jogador anda entre
    as carreiras, e travar a lavoura faria o talhao virar uma parede."""
    c = Cena(1, 1, altura_px=altura + 4, folga_x=0)
    t = c.tela
    bx, by = c.ancora
    for i in range(5):
        px = bx - 12 + i * 6
        py = by - 2 - int(ruido(i, 3, semente) * 3)
        alt = altura - int(ruido(i, 4, semente) * 4)
        t.linha(px, py, px, py - alt, tom(material, 1))
        t.linha(px + 1, py, px + 1, py - alt + 2, tom(material, 2))
        for k in range(2, alt, 4):                       # folhas
            lado = 1 if (i + k) % 2 else -1
            t.linha(px, py - k, px + lado * 3, py - k - 2, tom(material, 2))
        t.por(px, py - alt - 1, tom(material, 3))
    t.contornar(CONTORNO_SUAVE)
    return registrar(nome, c, (1, 1), {"tipo": "nenhuma"})


def espantalho(nome):
    c = Cena(1, 1, altura_px=30, folga_x=2)
    t = c.tela
    bx, by = c.ancora
    t.ret(bx - 1, by - 26, bx + 1, by - 2, tom("tronco", 1))     # mastro
    t.linha(bx - 11, by - 19, bx + 11, by - 19, tom("tronco", 2))  # braco
    t.ret(bx - 7, by - 24, bx + 7, by - 12, tom("telha_rubi", 2))  # camisa
    t.ret(bx - 7, by - 24, bx - 3, by - 12, tom("telha_rubi", 1))
    for i in range(4):                                            # palha
        t.linha(bx - 9 + i * 6, by - 12, bx - 11 + i * 6, by - 8, tom("palha", 1))
    t.elipse(bx, by - 27, 5, 5, tom("palha", 2))                  # cabeca
    t.por(bx - 2, by - 28, CONTORNO)
    t.por(bx + 2, by - 28, CONTORNO)
    t.elipse(bx, by - 30, 9, 3, tom("palha", 1))                  # chapeu
    t.elipse(bx, by - 32, 4, 2, tom("palha", 3))
    t.contornar(CONTORNO)
    t.sombra_chao(bx + 2, by - 1, 8, 4, alpha=70)
    return registrar(nome, c, (1, 1), {
        "tipo": "poligono", "pontos": pegada_losango(1, 1, encolher=0.5)})


# ------------------------------------------------------------------ chegada
TREVA = (0x12, 0x10, 0x1a)


def _arco(cy, meia, z_base, z_topo, x, passos=14):
    """Contorno de um arco de volta inteira na face x = const, em pontos de grade.
    `cy` e o centro no eixo y da grade; `meia`, a meia largura em celulas."""
    import math
    raio_z = z_topo - z_base
    pts = [(x, cy + meia, 0)]
    for i in range(passos + 1):
        t = math.pi * i / passos
        pts.append((x, cy + meia * math.cos(t), z_base + raio_z * math.sin(t)))
    pts.append((x, cy - meia, 0))
    return pts


def tunel(nome, W=2, D=3, altura=34, semente=0):
    """Boca de tunel na rocha da borda oeste: por onde o onibus chega.

    E um penhasco mais alto que os vizinhos (16 e 22 px), para que a boca leia
    como passagem cavada no paredao e nao como mais um bloco. O arco fica na face
    SE (x = W), a que olha para a estrada: o jogador ve a boca de frente quando a
    camera acompanha o onibus saindo.
    """
    c = Cena(W, D, altura_px=altura, folga_x=0)
    t = c.tela
    c.face([(0, D, 0), (W, D, 0), (W, D, altura), (0, D, altura)], tom("rocha", 2))
    c.face([(W, D, 0), (W, 0, 0), (W, 0, altura), (W, D, altura)], tom("rocha", 1))
    c.face([(0, 0, altura), (W, 0, altura), (W, D, altura), (0, D, altura)],
           tom("grama", 2))
    for y in range(c.alt):                                     # textura da rocha
        for x in range(c.larg):
            v = t.ler(x, y)
            if v == tom("rocha", 2) and ruido(x, y, semente) < 0.14:
                t.por(x, y, tom("rocha", 1))
            elif v == tom("rocha", 1) and ruido(x, y, semente + 1) < 0.14:
                t.por(x, y, tom("rocha", 0))
            elif v == tom("grama", 2) and ruido(x, y, semente + 2) < 0.22:
                t.por(x, y, tom("grama", 1 if ruido(x, y, 3) < 0.5 else 3))

    meio = D / 2.0
    # Moldura de pedra aparelhada, depois a boca e o fundo, cada vez mais escuros:
    # tres aneis bastam para a boca ter profundidade sem desenhar o interior.
    c.face(_arco(meio, 1.02, 13, 26, W), tom("calcada", 2))
    c.face(_arco(meio, 0.86, 12, 22, W), tom("rocha", 0))
    c.face(_arco(meio, 0.74, 11, 20, W), TREVA)
    for i in range(7):                                         # aduelas da moldura
        import math
        a = math.pi * (i + 0.5) / 7
        p = (W, meio + 0.94 * math.cos(a), 13 + 11 * math.sin(a))
        q = (W, meio + 1.02 * math.cos(a), 13 + 13 * math.sin(a))
        c.aresta(p, q, tom("calcada", 1))
    c.aresta((W, meio - 1.02, 0), (W, meio - 1.02, 13), tom("calcada", 3))
    # Chao da estrada entrando no tunel: a calcada continua alem da boca.
    c.face([(W, meio - 0.74, 0), (W, meio + 0.74, 0),
            (W - 0.35, meio + 0.6, 0), (W - 0.35, meio - 0.6, 0)], tom("calcada", 0))
    for gx in range(W + 1):                                    # borda do topo
        c.aresta((gx, 0, altura), (gx, D, altura), tom("grama", 3))
    c.aresta((0, D, altura), (W, D, altura), tom("grama", 3))
    t.contornar(CONTORNO_SUAVE)
    return registrar(nome, c, (W, D), {
        "tipo": "poligono", "pontos": pegada_losango(W, D, encolher=0.0)})


def onibus(nome):
    """O onibus da chegada, de perfil ao longo do eixo x da grade (frente em +x).

    NAO e colocado no mapa: a cutscene o instancia e o move. Fica no catalogo de
    props porque e desenhado com a mesma projecao e lido com a mesma ancora.
    Pegada 3 x 2, carroceria de 2,7 x 1,1 celulas centrada nela.
    """
    c = Cena(3, 2, altura_px=26, folga_x=2)
    t = c.tela
    x0, x1, y0, y1 = 0.15, 2.85, 0.45, 1.55
    zb, zt = 3, 21
    # carroceria: lado SO (comprido), frente SE e teto
    c.face([(x0, y1, zb), (x1, y1, zb), (x1, y1, zt), (x0, y1, zt)], tom("onibus", 2))
    c.face([(x1, y1, zb), (x1, y0, zb), (x1, y0, zt), (x1, y1, zt)], tom("onibus", 1))
    c.face([(x0, y0, zt), (x1, y0, zt), (x1, y1, zt), (x0, y1, zt)], tom("onibus", 3))
    c.face([(x0 + 0.2, y0 + 0.2, zt), (x1 - 0.5, y0 + 0.2, zt),
            (x1 - 0.5, y1 - 0.2, zt), (x0 + 0.2, y1 - 0.2, zt)], tom("metal", 3))
    # faixa vermelha e para-choque
    c.face([(x0, y1, 7), (x1, y1, 7), (x1, y1, 9), (x0, y1, 9)], tom("telha_rubi", 2))
    c.face([(x1, y1, 7), (x1, y0, 7), (x1, y0, 9), (x1, y1, 9)], tom("telha_rubi", 1))
    c.face([(x1, y1, zb), (x1, y0, zb), (x1, y0, zb + 2), (x1, y1, zb + 2)], tom("metal", 1))
    # janelas do lado, com montantes
    c.face([(x0 + 0.18, y1, 12), (x1 - 0.62, y1, 12), (x1 - 0.62, y1, 18),
            (x0 + 0.18, y1, 18)], tom("vidro", 1))
    x = x0 + 0.18
    while x < x1 - 0.7:
        c.aresta((x, y1, 12), (x, y1, 18), tom("onibus", 1))
        c.aresta((x + 0.08, y1, 17), (x + 0.22, y1, 17), tom("vidro", 3))
        x += 0.42
    # porta perto da frente, do lado do embarque
    c.face([(x1 - 0.55, y1, zb), (x1 - 0.15, y1, zb), (x1 - 0.15, y1, 18),
            (x1 - 0.55, y1, 18)], tom("onibus", 0))
    c.face([(x1 - 0.5, y1, 11), (x1 - 0.2, y1, 11), (x1 - 0.2, y1, 17),
            (x1 - 0.5, y1, 17)], tom("vidro", 0))
    c.aresta((x1 - 0.35, y1, zb), (x1 - 0.35, y1, 18), tom("onibus", 1))
    # para-brisa e farois
    c.face([(x1, y1 - 0.08, 11), (x1, y0 + 0.08, 11), (x1, y0 + 0.08, 19),
            (x1, y1 - 0.08, 19)], tom("vidro", 2))
    c.aresta((x1, y1 - 0.2, 18), (x1, y1 - 0.45, 18), tom("vidro", 3))
    for yy in (y1 - 0.14, y0 + 0.14):
        px, py = c.iso(x1, yy, 6)
        t.ret(int(px) - 1, int(py) - 1, int(px), int(py), (0xf4, 0xe6, 0xa8))
    # letreiro de destino em cima do para-brisa
    c.face([(x1, y1 - 0.15, 19.5), (x1, y0 + 0.15, 19.5), (x1, y0 + 0.15, 20.8),
            (x1, y1 - 0.15, 20.8)], TREVA)
    # rodas
    for xr in (x0 + 0.5, x1 - 0.75):
        px, py = c.iso(xr, y1, 2)
        t.elipse(int(px), int(py), 4, 4, CONTORNO)
        t.elipse(int(px), int(py), 2, 2, tom("metal", 1))
    t.contornar(CONTORNO)
    cx, cy = c.ancora
    t.sombra_chao(cx + 3, cy + 3, 40, 14, alpha=80)
    return registrar(nome, c, (3, 2), {"tipo": "nenhuma"})


def main():
    g = []
    g.append(casa("casa_01", 2, 2, telha="telha_rubi", porta="SO"))
    g.append(casa("casa_02", 2, 2, telha="telha_ardosia", porta="SE"))
    g.append(casa("casa_03", 3, 2, telha="telha_musgo", porta="SO",
                  h_parede=18, h_telhado=14))
    g.append(casa("casa_04", 2, 3, telha="telha_rubi", porta="SE",
                  h_parede=18, h_telhado=14))
    g.append(casa("casa_05", 2, 2, telha="telha_ardosia", porta="SO",
                  parede="madeira", h_parede=18, h_telhado=12))
    g.append(casa("casa_06", 3, 3, telha="telha_musgo", porta="SE",
                  h_parede=26, h_telhado=17))
    g.append(casa("celeiro", 3, 2, telha="palha", parede="madeira",
                  porta="SO", h_parede=22, h_telhado=18))

    g.append(arvore("arvore_01", tronco=9, raio=13, semente=1))
    g.append(arvore("arvore_02", tronco=7, raio=10, semente=2))
    g.append(arvore("arvore_03", tronco=11, raio=15, folha="folha_fria",
                    semente=3, copas=5))
    g.append(pinheiro("pinheiro_01", altura=36, raio=9, semente=4))
    g.append(pinheiro("pinheiro_02", altura=28, raio=7, semente=5))
    g.append(toco("toco_01"))
    g.append(flores("flores_01", (0xe8, 0xa8, 0xc0), semente=6))
    g.append(flores("flores_02", (0xef, 0xe4, 0x93), semente=7))

    g.append(pedra("pedra_01", raio=11, altura=14, semente=8))
    g.append(pedra("pedra_02", raio=8, altura=10, semente=9))
    g.append(pedra("pedra_03", raio=14, altura=19, semente=10))
    g.append(penhasco("penhasco_01", altura=16, semente=11))
    g.append(penhasco("penhasco_02", altura=22, semente=12))

    # --- ribeira, distrito industrial e fazenda (expansao do mundo) ---
    g.append(casa("cabana", 2, 2, telha="palha", parede="madeira", porta="SO",
                  h_parede=15, h_telhado=11, chamine=12))
    g.append(casa("padaria", 3, 2, telha="telha_rubi", parede="parede",
                  porta="SO", h_parede=20, h_telhado=13,
                  toldo="telha_rubi", chamine=14))
    g.append(casa("oficina", 2, 2, telha="telha_ardosia", parede="madeira",
                  porta="SE", h_parede=18, h_telhado=11, chamine=10))
    g.append(fabrica("fabrica", 3, 3))
    g.append(galpao("galpao_01", 3, 2, h_parede=20))
    g.append(galpao("galpao_02", 2, 3, h_parede=18, telha="ferrugem"))
    g.append(chamine("chamine", altura=44))
    g.append(maquinario("maquinario", semente=13))
    g.append(barril("barril", "ferrugem"))
    g.append(barril("barril_agua", "metal"))
    g.append(varal_peixe("varal_peixe"))
    g.append(barco("barco"))
    g.append(junco("junco_01", semente=14))
    g.append(junco("junco_02", semente=15))
    g.append(plantacao("plantacao_milho", "milho", altura=17, semente=16))
    g.append(plantacao("plantacao_folha", "folha", altura=11, semente=17))
    g.append(espantalho("espantalho"))

    g.append(poco("poco"))
    g.append(cerca("cerca_x", "x"))
    g.append(cerca("cerca_y", "y"))
    g.append(placa("placa"))
    g.append(caixa("caixa"))
    g.append(tunel("tunel", semente=18))
    g.append(onibus("onibus"))
    g.append(bolsa_perdida("bolsa_perdida"))

    destino = os.path.join(DIR_MUNDO, "props.json")
    with open(destino, "w", encoding="utf-8") as f:
        json.dump({
            "_meta": {
                "descricao": "Ancora, pegada em celulas e poligono de colisao de "
                             "cada prop do mundo. Gerado por "
                             "tools/arte/gerar_mundo_props.py — nao editar a mao.",
                "ancora": "pixel do sprite que cai sobre o centro da pegada",
                "colisao": "poligono em pixels relativos a ancora, ou tipo 'nenhuma'",
                "celula": [32, 16],
            },
            "props": _catalogo,
        }, f, indent=2, ensure_ascii=False)
        f.write("\n")

    salvar_folha_contato(g, os.path.join(DIR_PREVIEW, "mundo_props.png"), colunas=7)
    print(f"ok  {len(g)} props em {DIR_PROPS}")
    print(f"ok  {destino}")


if __name__ == "__main__":
    main()
