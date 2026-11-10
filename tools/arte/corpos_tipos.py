"""
corpos_tipos.py — as 8 bases animais, 4 portes cada.

Eixo interno (indice do modelo 0..3): compacto -> alongado.
Alongar = tronco mais comprido e mais baixo + membros mais longos.

Cada funcao recebe p (0..3) e devolve (runs, detalhes, ancoras, fundo).
Ancoras em pixels no canvas 32x32:
    pe_frente / pe_tras : ponto de acoplagem das garras (a PONTA dela)
    cabeca              : topo da cabeca (chifres, cristas)
    cauda               : ponta da cauda (None se nao tem)
    dorso               : ombro, sobre a borda de cima do tronco (asas)
    dorso_tras          : mais atras no dorso (nadadeira dorsal)
    flanco              : lateral do tronco, abaixo da linha media (nadadeira peitoral)

dorso e dorso_tras sao MEDIDOS na silhueta (ancora_no_topo), nao calculados da
elipse: a cabeca, o peito e a crista mudam a borda de cima, e uma asa ancorada no
topo teorico da elipse flutuaria um pixel acima do contorno real.

Asas e nadadeiras NAO fazem parte dos corpos: a ave e o peixe nascem sem elas, e
so as recebem se o gerador sortear o traco (tools/arte/gerar_apendices.py). Antes
a asa da ave e as nadadeiras do peixe estavam pintadas no corpo, e uma ave que nao
sorteou asas aparecia com uma — o quadro contradizia o dado.

CADA ANIMAL TEM ESQUELETO PROPRIO. Nao ha uma funcao _quadrupede parametrizada:
gato, canino, roedor e reptil compartilhavam uma so, e o resultado eram quatro
variacoes do mesmo cachorro — se animal_base mal muda a silhueta, o atributo
primario perde poder discriminativo e as correlacoes derivadas ficam penduradas
numa forma que o jogador nao consegue distinguir. A assinatura de cada um esta
comentada na sua funcao.
"""

import math
from corpos_lib import (elipse, disco, ret, triangulo, perna, stroke, linha,
                        leque, leque_h, ancora_no_topo,
                        OUTLINE, DARK, HILITE)

CHAO = 30


# ------------------------------------------------------------------ caudas
def cauda_arco(tx, ty, R, r0, r1, n=10):
    """Quarto de arco: sai para tras e enrola para cima.

    R e limitado ao espaco livre a esquerda: o porte alongado pede cauda maior,
    mas o quadro continua com 32px e uma ponta em x negativo seria cortada em
    silencio — a ancora 'cauda' apontaria para fora da mascara.
    """
    R = max(2.0, min(R, tx - 2))
    pts, rs = [], []
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(270 - 95 * t)
        pts.append((int(round(tx + R * math.cos(a))),
                    int(round(ty - R - R * math.sin(a)))))
        rs.append(max(0, int(round(r0 + (r1 - r0) * t))))
    return stroke(pts, rs), pts[-1]


def cauda_reta(tx, ty, comp, r0, r1, queda=0.0, n=10):
    """Cauda esticada para tras, com leve queda ou subida. Ver clamp em cauda_arco."""
    comp = max(3.0, min(comp, tx - 2))
    pts, rs = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append((int(round(tx - comp * t)), int(round(ty + queda * comp * t))))
        rs.append(max(0, int(round(r0 + (r1 - r0) * t))))
    return stroke(pts, rs), pts[-1]


# ------------------------------------------------------------------ membros
def _quatro_patas(xf, xb, y_topo, larg=2, pe=1, recuo=2):
    """Par da frente + par de tras, com o membro do lado oposto COLADO ao seu.

    Devolve (runs, fundo). O membro oposto entra em `fundo`, que o rasterizador
    forca a DARK. Ele fica a `recuo` px do par, e nao a meia distancia entre os
    dois pares: espalhados, os quatro membros viram barras equidistantes e a
    silhueta le como cerca. Colados, leem como um membro com o seu par atras —
    que e o que a perspectiva lateral de fato mostra.
    """
    runs = perna(xf, y_topo, CHAO, larg, pe) + perna(xb, y_topo, CHAO, larg, pe)
    fundo = (perna(xf - recuo, y_topo, CHAO - 1, larg, pe)
             + perna(xb - recuo, y_topo, CHAO - 1, larg, pe))
    return runs, fundo


# ------------------------------------------------------------------ os 8 tipos
def gato(p):
    """Felino: tronco baixo e curto, peito estreito, cabeca pequena e redonda,
    orelhas triangulares eretas e juntas, cauda fina e MUITO longa em arco alto.
    O que o distingue do canino: cabeca menor que o peito e cauda dominante."""
    rx = 5.8 + 0.85 * p
    ry = 3.9 - 0.42 * p
    plen = 4.6 + 0.7 * p
    cx = 13
    cy = CHAO - plen - ry

    runs = elipse(cx, cy, rx, ry)
    runs += elipse(cx + rx * 0.5, cy - 0.4, rx * 0.42, ry * 0.92)   # peito

    r = 2.9
    hx = int(round(cx + rx + 0.5))
    hy = int(round(cy - ry - r + 2.5))
    runs += disco(hx, hy, r)
    runs += ret(hx + 2, hy, hx + 4, hy + 1)                          # focinho curto
    yo = int(round(hy - r + 1))
    runs += leque(hx - 3, hx - 1, yo, yo - 4, pontax=hx - 3)         # orelhas
    runs += leque(hx + 1, hx + 3, yo, yo - 4, pontax=hx + 3)

    xf = int(round(cx + rx - 3))
    xb = int(round(cx - rx + 1))
    y_topo = int(round(cy + ry - 2))
    runs_p, fundo = _quatro_patas(xf, xb, y_topo, larg=2, pe=1, recuo=3)
    runs += runs_p

    seg, ponta = cauda_arco(xb, int(round(cy - ry * 0.3)),
                            max(3, 6 + 0.7 * p), 1, 0)
    runs += seg

    det = [(hx + int(r) - 2, hy - 1, OUTLINE)]
    anc = {"pe_frente": [xf + 1, CHAO], "pe_tras": [xb + 1, CHAO],
           "cabeca": [hx, int(round(hy - r))], "cauda": list(ponta),
           "dorso": ancora_no_topo(runs, cx + rx * 0.25),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.35),
           "flanco": [int(round(cx + rx * 0.15)), int(round(cy + ry * 0.35))]}
    return runs, det, anc, fundo


def canino(p):
    """Canideo: dorso INCLINADO (peito alto, garupa baixa), focinho longo,
    orelhas caidas para tras, pernas altas e retas, cauda grossa e reta.
    O que o distingue do gato: linha do dorso descendente e cabeca alongada."""
    rx = 6.6 + 0.95 * p
    ry = 4.2 - 0.4 * p
    plen = 6.0 + 0.75 * p
    cx = 13
    cy = CHAO - plen - ry

    runs = elipse(cx, cy, rx, ry)
    # peito erguido e garupa rebaixada: duas elipses deslocadas em y dao a
    # inclinacao do dorso sem precisar de rotacao (cara em 32x32).
    runs += elipse(cx + rx * 0.45, cy - 1.4, rx * 0.5, ry * 0.95)
    runs += elipse(cx - rx * 0.5, cy + 0.8, rx * 0.45, ry * 0.8)

    r = 3.0
    hx = int(round(cx + rx + 1))
    hy = int(round(cy - ry - r + 1.5))
    runs += disco(hx, hy, r)
    runs += ret(hx + 1, hy + 1, hx + 6, hy + 3)                      # focinho longo
    yo = int(round(hy - r + 1))
    runs += leque(hx - 4, hx - 1, yo, yo + 4, pontax=hx - 5)         # orelha caida
    runs += leque(hx - 1, hx + 2, yo, yo + 3, pontax=hx - 1)

    xf = int(round(cx + rx - 3))
    xb = int(round(cx - rx + 1))
    y_topo = int(round(cy + ry - 2))
    runs_p, fundo = _quatro_patas(xf, xb, y_topo, larg=2, pe=1, recuo=4)
    runs += runs_p

    seg, ponta = cauda_reta(xb, int(round(cy - ry * 0.6)),
                            max(4, 7 + 0.9 * p), 2, 1, queda=-0.25)
    runs += seg

    det = [(hx + int(r) - 2, hy - 1, OUTLINE)]
    anc = {"pe_frente": [xf + 1, CHAO], "pe_tras": [xb + 1, CHAO],
           "cabeca": [hx, int(round(hy - r))], "cauda": list(ponta),
           "dorso": ancora_no_topo(runs, cx + rx * 0.2),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.4),
           "flanco": [int(round(cx + rx * 0.15)), int(round(cy + ry * 0.35))]}
    return runs, det, anc, fundo


def roedor(p):
    """Roedor SENTADO: garupa alta apoiada no chao, patinhas dianteiras curtas
    junto ao peito, cabeca grande em relacao ao corpo, orelhas em disco, cauda
    fina arrastando no chao. E o unico bipede-por-postura entre os quadrupedes —
    a silhueta e vertical, nao horizontal."""
    rx = 4.4 + 0.5 * p
    ry = 5.2 - 0.35 * p
    cx = 13
    cy = CHAO - ry + 1

    runs = elipse(cx, cy, rx, ry)                                    # garupa
    runs += elipse(cx + 2.5, cy - ry * 0.55, rx * 0.72, ry * 0.5)    # peito

    r = 3.2 + 0.1 * p
    hx = int(round(cx + 3.5))
    hy = int(round(cy - ry - r + 3.0))
    runs += disco(hx, hy, r)
    runs += leque_h(hy, hy + 2, hx + 2, hx + 5)                      # focinho
    runs += disco(hx - 2, int(round(hy - r + 0.5)), 2.4)             # orelhas
    runs += disco(hx + 2, int(round(hy - r)), 2.4)

    # pata dianteira curta, encolhida junto ao peito; pe traseiro grande no chao
    braco_y = int(round(cy - ry * 0.25))
    runs += ret(hx - 1, braco_y, hx + 1, braco_y + 3)
    xf = int(round(cx + 1))
    runs += ret(xf, CHAO - 1, xf + 4, CHAO)
    fundo = ret(xf - 3, CHAO - 1, xf + 1, CHAO)

    seg, ponta = cauda_reta(int(round(cx - rx + 1)), CHAO - 2,
                            max(5, 8 + 1.2 * p), 1, 0, queda=0.12)
    runs += seg

    det = [(hx + 1, hy - 1, OUTLINE)]
    anc = {"pe_frente": [xf + 4, CHAO], "pe_tras": [xf - 2, CHAO],
           "cabeca": [hx, int(round(hy - r))], "cauda": list(ponta),
           # sentado: o "dorso" e as costas, atras da cabeca e acima da garupa
           "dorso": ancora_no_topo(runs, cx - rx * 0.15),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.6),
           "flanco": [int(round(cx)), int(round(cy + 1))]}
    return runs, det, anc, fundo


def reptil(p):
    """Lagarto ESPARRAMADO: tronco quase colado ao chao, pernas curtas e abertas
    para os lados (a de tras aparece deslocada), cabeca em cunha alinhada ao
    dorso, crista serrilhada e cauda longa e grossa afilando. O que o distingue:
    altura minima e comprimento maximo — o extremo horizontal do conjunto."""
    rx = 7.4 + 1.0 * p
    ry = 2.9 - 0.18 * p
    plen = 2.6 + 0.3 * p
    cx = 14
    cy = CHAO - plen - ry

    runs = elipse(cx, cy, rx, ry)

    # cabeca em cunha, na mesma linha do dorso
    hx = int(round(cx + rx - 1))
    hy = int(round(cy - 0.5))
    runs += leque_h(hy - 2, hy + 2, hx + 5, hx)
    runs += elipse(hx, hy, 3.0, 2.4)

    # crista dorsal serrilhada: assinatura visual do arquetipo
    topo = int(round(cy - ry))
    for i in range(4 + p):
        x = int(round(cx - rx + 2 + i * 2))
        runs += [(topo - 1, x, x)]

    xf = int(round(cx + rx - 4))
    xb = int(round(cx - rx + 2))
    y_topo = int(round(cy + ry - 1))
    # pernas abertas: o pe projeta para FORA (frente na frente, tras para tras)
    runs += ret(xf, y_topo, xf + 1, CHAO) + ret(xf, CHAO - 1, xf + 3, CHAO)
    runs += ret(xb, y_topo, xb + 1, CHAO) + ret(xb - 2, CHAO - 1, xb + 1, CHAO)
    fundo = (ret(xf - 4, y_topo, xf - 3, CHAO - 1)
             + ret(xb + 4, y_topo, xb + 5, CHAO - 1))

    seg, ponta = cauda_reta(xb - 1, int(round(cy + 0.5)),
                            max(5, 8 + 1.1 * p), 2, 0, queda=0.10)
    runs += seg

    det = [(hx + 1, hy - 1, OUTLINE)]
    anc = {"pe_frente": [xf + 2, CHAO], "pe_tras": [xb, CHAO],
           "cabeca": [hx, int(round(hy - 2))], "cauda": list(ponta),
           "dorso": ancora_no_topo(runs, cx + rx * 0.3),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.15),
           "flanco": [int(round(cx + rx * 0.25)), int(round(cy + 1))]}
    return runs, det, anc, fundo


def anfibio(p):
    """Anuro agachado: coxa traseira BOJUDA e mais alta que o dorso, boca larga
    varrendo toda a frente da cabeca, olho protuberante acima da linha do cranio,
    patas dianteiras finas e verticais. A assinatura e o perfil em rampa: sobe do
    focinho ate a coxa."""
    rx = 6.0 + 0.6 * p
    ry = 2.7 - 0.14 * p
    plen = 1.6 + 0.6 * p
    cx = 14
    cy = CHAO - plen - ry

    runs = elipse(cx, cy, rx, ry)

    # coxa traseira: culmina ACIMA da linha do dorso. Sem esse degrau os tres
    # volumes (coxa, tronco, cabeca) alinham no topo e a silhueta vira um bloco.
    xt = int(round(cx - rx + 1))
    yt = int(round(cy - 1.6))
    runs += elipse(xt, yt, 3.6, 4.2)
    runs += ret(xt - 3, yt + 2, xt - 2, CHAO)                        # canela
    runs += ret(xt - 4, CHAO - 1, xt + 1, CHAO)                      # pe palmado
    fundo = elipse(xt + 3, yt + 1, 2.6, 3.0)
    fundo += ret(xt + 2, yt + 3, xt + 3, CHAO)

    # cabeca larga e baixa, projetada para a frente
    hx = int(round(cx + rx - 1))
    hy = int(round(cy - ry + 2.5))
    runs += elipse(hx, hy, 4.4, 2.6)
    ox, oy = hx + 1, hy - 3
    runs += disco(ox, oy, 2.3)                                       # olho bulboso

    xd = hx - 1
    runs += ret(xd, int(cy + ry - 1), xd + 1, CHAO)
    runs += ret(xd, CHAO - 1, xd + 3, CHAO)
    fundo += ret(xd - 4, int(cy + ry - 1), xd - 3, CHAO - 1)

    det = [(ox, oy, OUTLINE), (ox + 1, oy, OUTLINE), (ox, oy - 1, HILITE)]
    for dx in range(-4, 5):                                          # boca larga
        det.append((hx + dx, hy + 2, DARK))

    anc = {"pe_frente": [xd + 1, CHAO], "pe_tras": [xt - 2, CHAO],
           "cabeca": [ox, oy - 3], "cauda": None,
           "dorso": ancora_no_topo(runs, cx + rx * 0.15),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.25),
           "flanco": [int(round(cx + rx * 0.2)), int(round(cy + 1))]}
    return runs, det, anc, fundo


def ave(p):
    """Avial: corpo em ovo INCLINADO, pescoco em curva, bico em cunha e cauda em
    leque projetada para tras-cima. Pernas finas e altas, o oposto do reptil. A asa
    nao e do corpo: vem do traco 'asas' (ver o cabecalho)."""
    rx = 4.8 + 0.35 * p
    ry = 5.4 - 0.45 * p
    plen = 3.6 + 1.2 * p
    cx = 15
    cy = CHAO - plen - ry

    runs = elipse(cx, cy, rx, ry)
    runs += elipse(cx + 1.5, cy - ry * 0.35, rx * 0.8, ry * 0.55)    # peito alto

    # pescoco curvo: arco de discos, nao um segmento reto
    nx, ny = int(round(cx + rx - 2)), int(round(cy - ry + 1))
    pesc = 3 + p // 2
    pts = [(nx + int(round(pesc * t)), ny - int(round(pesc * t * t)))
           for t in (0.0, 0.34, 0.67, 1.0)]
    runs += stroke(pts, [2, 2, 2, 2])
    hx, hy = pts[-1]
    runs += disco(hx, hy, 2.6)
    runs += leque_h(hy - 1, hy + 2, hx + 2, hx + 6)                  # bico

    runs += leque(int(cx - rx - 4), int(cx - rx + 3),
                  int(cy - 2), int(cy - 7), pontax=int(cx - rx - 5))  # leque caudal
    fundo = []

    xf = int(round(cx + 1))
    runs += ret(xf, int(cy + ry - 1), xf + 1, CHAO)
    runs += ret(xf, CHAO - 1, xf + 3, CHAO)
    fundo += ret(xf - 4, int(cy + ry - 1), xf - 3, CHAO - 1)
    fundo += ret(xf - 5, CHAO - 1, xf - 2, CHAO)

    det = [(hx + 1, hy - 1, OUTLINE)]
    anc = {"pe_frente": [xf + 2, CHAO], "pe_tras": [xf - 3, CHAO],
           "cabeca": [hx, hy - 3],
           "cauda": [int(cx - rx - 5), int(cy - 7)],
           "dorso": ancora_no_topo(runs, cx - rx * 0.05),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.55),
           "flanco": [int(round(cx)), int(round(cy + 1))]}
    return runs, det, anc, fundo


def peixe(p):
    """Aquatico flutuante: corpo em gota (massa a frente, afilando para o
    pedunculo) e caudal em MEIA-LUA de dois lobos. Nao toca o chao — a silhueta e
    centrada verticalmente, nao apoiada."""
    rx = 7.2 + 0.9 * p
    ry = 6.2 - 0.75 * p
    cx, cy = 14, 16

    runs = elipse(cx, cy, rx, ry)
    runs += leque_h(int(cy - ry * 0.55), int(cy + ry * 0.55),
                    int(cx + rx - 1), int(cx + rx + 3))              # focinho

    bx = max(7, int(round(cx - rx + 1)))
    runs += ret(bx - 3, cy - 1, bx, cy + 1)                          # pedunculo
    # caudal em meia-lua: dois lobos com o vao no meio
    runs += triangulo(bx - 2, cy - 1, bx - 6, int(cy - ry - 1), 3)
    runs += triangulo(bx - 2, cy + 1, bx - 6, int(cy + ry + 1), 3)
    runs += ret(bx - 3, cy - 1, bx - 2, cy + 1)

    # Dorsal, ventral e peitoral NAO sao do corpo: vem do traco 'nadadeiras'.
    # A caudal fica: e a cauda do peixe, e sem ela a silhueta deixa de ler peixe.
    fundo = []

    ox = int(round(cx + rx - 4))
    det = [(ox, cy - 2, OUTLINE), (ox + 1, cy - 2, OUTLINE),
           (ox + 1, cy - 3, HILITE)]
    for dy in range(-3, 4):                                          # guelra
        det.append((ox - 4, cy + dy, DARK))

    ventral = int(round(cy + ry + 5))
    # Ver nota em CatalogoCorpos.SLOTS_DE_FEATURE: o corpo sem patas tambem
    # declara acoplagem de garra, ancorada na PONTA dela, abaixo da barriga.
    anc = {"pe_frente": [int(cx + 3), ventral], "pe_tras": [int(cx - 3), ventral],
           "cabeca": [ox, int(cy - ry)],
           "cauda": [bx - 6, cy],
           "dorso": ancora_no_topo(runs, cx + rx * 0.1),
           "dorso_tras": ancora_no_topo(runs, cx - rx * 0.05),
           "flanco": [int(round(cx + 2)), int(round(cy + 2))]}
    return runs, det, anc, fundo


def inseto(p):
    """Insetoide: tres segmentos separados por constricao, seis pernas
    ARTICULADAS (femur para cima e tibia para baixo, nao fios retos), mandibulas
    e antenas. A assinatura e a silhueta em zigue-zague das pernas."""
    abx = 4.6 + 0.5 * p
    aby = 4.2 - 0.3 * p
    rtx, rhx = 3.0, 2.3
    vao = 0.9

    ax = abx + 2.0
    tx = ax + abx + vao + rtx
    hx = tx + rtx + vao + rhx
    ay = 18

    runs = elipse(ax, ay, abx, aby)                                  # abdomen
    runs += elipse(tx, 16, rtx, rtx * 0.95)                          # torax
    runs += disco(hx, 15, rhx)                                       # cabeca

    itx, ihx = int(round(tx)), int(round(hx))
    fundo = []
    # perna articulada: sobe do quadril (femur), desce ate o solo (tibia)
    # Femur para cima, tibia para baixo. Traco de 1px: com esp=1 o stroke engrossa
    # para 3px e os tres pares se fundem num borrao unico em 32x32.
    for i, (ox, joelho, pe_x) in enumerate(((-4, -4, -8), (1, 0, 0), (6, 4, 8))):
        qx, qy = itx + ox, 18
        jx, jy = qx + joelho, 12
        px, py = qx + pe_x, 26
        runs += linha(qx, qy, jx, jy)
        runs += linha(jx, jy, px, py)
        runs += ret(px - 1, py, px + 1, py)
        fundo += linha(qx + 1, qy, jx + 2, jy + 3)
        fundo += linha(jx + 2, jy + 3, px + 2, py - 3)

    runs += ret(ihx + 1, 16, ihx + 3, 16)                            # mandibulas
    runs += ret(ihx + 1, 17, ihx + 2, 17)
    runs += linha(ihx + 1, 13, ihx + 3, 10)                          # antenas
    runs += linha(ihx - 1, 13, ihx, 10)

    det = [(ihx + 1, 14, OUTLINE), (ihx + 1, 15, DARK)]
    anc = {"pe_frente": [itx + 7, 26], "pe_tras": [itx - 7, 26],
           "cabeca": [ihx, 11], "cauda": [int(round(ax - abx)), ay],
           # as asas de inseto nascem do torax; a dorsal, do abdomen
           "dorso": ancora_no_topo(runs, tx),
           "dorso_tras": ancora_no_topo(runs, ax),
           "flanco": [int(round(ax + 1)), int(round(ay + 1))]}
    return runs, det, anc, fundo


TIPOS = {
    "gato": gato, "canino": canino, "roedor": roedor, "reptil": reptil,
    "anfibio": anfibio, "ave": ave, "peixe": peixe, "inseto": inseto,
}

PORTES = ["compacto", "medio", "esbelto", "alongado"]

# Arquetipo estrutural de cada base animal. E o arquetipo — nao o animal — que
# governa quais apendices fazem sentido anatomicamente e onde eles nascem, entao
# ele viaja junto com a mascara no JSON de ancoras.
ARQUETIPOS = {
    "gato": "quadrupede", "canino": "quadrupede", "roedor": "bipede",
    "reptil": "serpentiforme", "anfibio": "bipede", "ave": "avial",
    "peixe": "aquatico", "inseto": "insetoide",
}

# Quais bases animais tem membros locomotores desenhados. Metadado DESCRITIVO: nao
# e veto. Todo corpo declara ancoras de acoplagem de garra, inclusive os sem patas —
# ver a nota em peixe(). Serve para calibrar tabelas e para futuras features que
# dependam de perna (ex.: pose de caminhada).
TEM_PATAS = {"gato", "canino", "roedor", "reptil", "anfibio", "ave", "inseto"}

PESO_ANIMAL_BASE = {
    "gato": 0.14, "peixe": 0.13, "ave": 0.13, "reptil": 0.13,
    "roedor": 0.12, "inseto": 0.12, "anfibio": 0.11, "canino": 0.12,
}
