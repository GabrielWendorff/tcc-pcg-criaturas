"""
corpos_lib.py — primitivas de desenho e rasterizacao 32x32 para os corpos.

Mesma convencao das garras:
    0 transparente | 1 contorno | 2 sombra | 3 base | 4 brilho
Vista lateral, criatura voltada para a DIREITA, chao em y = 31.
"""

import math

S = 32
TRANSP, OUTLINE, DARK, BASE, HILITE = 0, 1, 2, 3, 4


# ------------------------------------------------------------------ primitivas
def elipse(cx, cy, rx, ry):
    """Elipse cheia. Retorna runs (y, x0, x1)."""
    runs = []
    for y in range(int(round(cy - ry)), int(round(cy + ry)) + 1):
        dy = (y - cy) / (ry + 0.5)
        d = 1.0 - dy * dy
        if d <= 0:
            continue
        w = int(round(rx * math.sqrt(d)))
        runs.append((y, int(round(cx - w)), int(round(cx + w))))
    return runs


def disco(cx, cy, r):
    return elipse(cx, cy, r, r)


def ret(x0, y0, x1, y1):
    return [(y, int(x0), int(x1)) for y in range(int(y0), int(y1) + 1)]


def stroke(pts, raios):
    """Uniao de discos ao longo de uma polilinha. Usado em caudas e pescocos."""
    runs = []
    for (x, y), r in zip(pts, raios):
        runs += disco(x, y, r)
    return runs


def cauda(x0, y0, dx, dy, n, r0, r1, curva=0.0):
    """Cauda afilada: n segmentos de (x0,y0) na direcao (dx,dy), raio r0 -> r1."""
    pts, rs = [], []
    for i in range(n):
        t = i / max(1, n - 1)
        cx = x0 + dx * i
        cy = y0 + dy * i - curva * i * i * 0.5
        pts.append((int(round(cx)), int(round(cy))))
        rs.append(max(0, int(round(r0 + (r1 - r0) * t))))
    return stroke(pts, rs)


def triangulo(x0, y0, x1, y1, largura):
    """Cunha: base de `largura` em (x0,y0) afunilando ate a ponta (x1,y1)."""
    runs = []
    n = max(abs(x1 - x0), abs(y1 - y0)) + 1
    for i in range(n):
        t = i / max(1, n - 1)
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        w = int(round(largura * (1 - t) / 2))
        if abs(x1 - x0) >= abs(y1 - y0):
            runs += [(y + k, x, x) for k in range(-w, w + 1)]
        else:
            runs.append((y, x - w, x + w))
    return runs


def leque(x0, x1, ybase, ytopo, pontax=None):
    """Triangulo de base horizontal [x0,x1] em ybase, vertice em (pontax, ytopo).
    Usado em nadadeiras dorsais/ventrais e cristas."""
    if pontax is None:
        pontax = (x0 + x1) // 2
    n = abs(ytopo - ybase)
    passo = 1 if ytopo > ybase else -1
    runs = []
    for i in range(n + 1):
        t = i / max(1, n)
        a = x0 + (pontax - x0) * t
        b = x1 + (pontax - x1) * t
        runs.append((ybase + passo * i, int(round(a)), int(round(b))))
    return runs


def leque_h(y0, y1, xbase, xponta):
    """Triangulo de base vertical [y0,y1] em xbase, vertice em xponta.
    Usado em bicos, focinhos e caudais de peixe."""
    n = abs(xponta - xbase)
    passo = 1 if xponta > xbase else -1
    ym = (y0 + y1) / 2
    runs = []
    for i in range(n + 1):
        t = i / max(1, n)
        a = y0 + (ym - y0) * t
        b = y1 + (ym - y1) * t
        for y in range(int(round(a)), int(round(b)) + 1):
            runs.append((y, xbase + passo * i, xbase + passo * i))
    return runs


def linha(x0, y0, x1, y1, esp=0):
    """Segmento de reta (Bresenham), opcionalmente engrossado por discos."""
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        pts.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy
    if esp <= 0:
        return [(py, px, px) for px, py in pts]
    return stroke(pts, [esp] * len(pts))


def perna(x, y_topo, y_base, larg=2, pe=0):
    """Membro vertical simples, com pe opcional projetado para a frente."""
    runs = ret(x, y_topo, x + larg - 1, y_base)
    if pe:
        runs += ret(x, y_base - 1, x + larg - 1 + pe, y_base)
    return runs


# ------------------------------------------------------------------ raster
def rasterizar(runs, detalhes=(), fundo=(), tam=S):
    """runs -> grade de indices, com sombreamento (luz no topo-esquerda) e contorno.

    `fundo` sao runs de partes do lado oposto do corpo (membros de tras):
    apos o sombreamento elas sao forcadas para DARK, criando profundidade
    sem exigir um vao de pixels vazios entre os membros.
    """
    g = [[TRANSP] * tam for _ in range(tam)]
    for y, x0, x1 in list(runs) + list(fundo):
        if not (0 <= y < tam):
            continue
        for x in range(max(0, x0), min(tam - 1, x1) + 1):
            g[y][x] = BASE

    sol = [[g[y][x] == BASE for x in range(tam)] for y in range(tam)]

    def cheio(x, y):
        return 0 <= x < tam and 0 <= y < tam and sol[y][x]

    for y in range(tam):
        for x in range(tam):
            if not sol[y][x]:
                continue
            if not cheio(x - 1, y) or not cheio(x, y - 1):
                g[y][x] = HILITE
            elif not cheio(x + 1, y) or not cheio(x, y + 1):
                g[y][x] = DARK

    borda = []
    for y in range(tam):
        for x in range(tam):
            if sol[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if cheio(x + dx, y + dy):
                    borda.append((x, y))
                    break
    for x, y in borda:
        g[y][x] = OUTLINE

    solido_frente = set()
    for y, x0, x1 in runs:
        for x in range(max(0, x0), min(tam - 1, x1) + 1):
            solido_frente.add((x, y))
    for y, x0, x1 in fundo:
        if not (0 <= y < tam):
            continue
        for x in range(max(0, x0), min(tam - 1, x1) + 1):
            if (x, y) in solido_frente:
                continue
            if g[y][x] in (BASE, HILITE):
                g[y][x] = DARK

    # detalhes (olho, listras) sobrescrevem o sombreamento
    for x, y, idx in detalhes:
        if 0 <= x < tam and 0 <= y < tam:
            g[y][x] = idx
    return g


ASCII = {TRANSP: ".", OUTLINE: "#", DARK: "+", BASE: "o", HILITE: "*"}


def imprimir(g, titulo=""):
    print(f"--- {titulo}")
    for y, linha in enumerate(g):
        print(f"{y:2d} " + "".join(ASCII[v] for v in linha))
