#!/usr/bin/env python3
"""
gerar_apendices.py — a arte de ASAS, NADADEIRAS e ESCAMAS das criaturas.

Mesma convencao dos corpos e das garras: PNG RGBA com o indice de paleta no canal R
    0 transparente | 63 contorno | 126 sombra | 189 base | 252 brilho
e a cor de verdade so entra no shader (paleta_indexada.gdshader). Um desenho serve
aos 8 elementos.

ONDE CADA PECA ENCOSTA. Cada peca declara um PIVO: o pixel dela que fica sobre a
ancora do corpo (arte/corpos/corpos_ancoras.json, medida na silhueta por
tools/arte/corpos_tipos.py):
    asas                -> 'dorso'       (ombro; a asa sobe e varre para tras)
    nadadeira dorsal    -> 'dorso_tras'  (mais atras no dorso)
    nadadeira peitoral  -> 'flanco'      (lateral do tronco; aponta para tras-baixo)
    escamas             -> sobreposicao do corpo inteiro, uma por corpo

AS ESCAMAS NAO SAO UM APENDICE. Sao uma textura sobre o corpo, e por isso nascem
RECORTADAS pela silhueta de cada um dos 32 corpos: uma mascara por corpo e por
modelo, desenhada so sobre pixels de base e brilho que nao tocam o contorno. Assim
elas nunca vazam para fora da criatura, e o contorno continua sendo o do corpo.

O EIXO DE CADA CONJUNTO vem de data/feature_variants.json (os nomes dos modelos e a
ordem deles). Este script le de la, e falha se o numero de modelos nao bater: o
arquivo de arte e o dado tem de dizer a mesma coisa.

Saida: arte/apendices/*.png, arte/apendices/escamas/*.png e arte/apendices/apendices.json
       tools/arte/_preview/apendices_folha_contato.png (conferencia, nao e asset)
"""

import json
import os
from PIL import Image

from corpos_lib import rasterizar, linha, S, TRANSP, OUTLINE, DARK, BASE, HILITE
from corpos_tipos import TIPOS, PORTES
from gerar_corpos import PALETAS, hexa

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
DIR_SAIDA = os.path.join(RAIZ, "arte", "apendices")
DIR_ESCAMAS = os.path.join(DIR_SAIDA, "escamas")
DIR_PREVIEW = os.path.join(AQUI, "_preview")
VARIANTES = os.path.join(RAIZ, "data", "feature_variants.json")

T = 16  # quadro de trabalho de cada peca, recortado depois


# ------------------------------------------------------------------ primitivas
def poligono(pts):
    """Poligono cheio por varredura. Retorna runs (y, x0, x1)."""
    runs = []
    ys = [p[1] for p in pts]
    for y in range(min(ys), max(ys) + 1):
        cy = y + 0.5
        xs = []
        n = len(pts)
        for i in range(n):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
            if (y0 <= cy < y1) or (y1 <= cy < y0):
                xs.append(x0 + (cy - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for a, b in zip(xs[0::2], xs[1::2]):
            x0, x1 = int(round(a)), int(round(b - 0.01))
            if x1 >= x0:
                runs.append((y, x0, x1))
    return runs


def pontos(runs):
    """Os pixels de uma lista de runs, como detalhes (x, y)."""
    return [(x, y) for y, x0, x1 in runs for x in range(x0, x1 + 1)]


def traco(x0, y0, x1, y1, idx):
    return [(x, y, idx) for x, y in pontos(linha(x0, y0, x1, y1))]


def translucida(g, veias=()):
    """Membrana fina: o miolo inteiro vira brilho e so as veias ficam escuras.
    Nao ha transparencia parcial nas mascaras (o shader descarta alpha < 0.5), entao
    'translucido' se le pelo valor claro e pelas nervuras, como num vitral."""
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x] == BASE:
                g[y][x] = HILITE
    for x, y, idx in veias:
        if 0 <= y < len(g) and 0 <= x < len(g[0]) and g[y][x] != TRANSP:
            g[y][x] = idx
    return g


def peca(runs, detalhes=(), membrana=None):
    g = rasterizar(runs, detalhes, (), tam=T)
    if membrana is not None:
        g = translucida(g, membrana)
    return g


# ------------------------------------------------------------------ asas
# Tamanho calibrado contra corpos de 32px cujo tronco tem 8 a 12px de altura: a asa
# fica com cerca de 10px, como o membro de uma criatura, e nao como uma vela que
# esconde o corpo (a primeira versao, de 15px, cobria metade da silhueta).
# Raiz da asa em (9, 10): a asa sobe e varre para TRAS (esquerda), como uma asa
# erguida vista de lado com a criatura voltada para a direita.
RAIZ_ASA = (9, 10)


def asa_emplumada():
    """Ave: borda de ataque cheia, borda de fuga recortada em penas."""
    runs = poligono([(9, 11), (11, 7), (8, 3), (4, 0), (1, 1), (2, 3), (0, 4),
                     (2, 6), (1, 8), (5, 8), (7, 11)])
    return peca(runs, traco(7, 4, 2, 3, DARK) + traco(8, 7, 2, 6, DARK))


def asa_membranosa():
    """Morcego: dedos longos saindo de uma junta, membrana em arcos entre eles."""
    runs = poligono([(9, 11), (11, 6), (8, 2), (5, 0), (0, 1), (2, 3), (0, 5),
                     (3, 6), (1, 9), (5, 8), (6, 11)])
    det = (traco(9, 10, 8, 2, OUTLINE) + traco(8, 2, 1, 1, OUTLINE)
           + traco(8, 2, 1, 5, OUTLINE) + traco(8, 2, 2, 9, OUTLINE))
    return peca(runs, det)


def asa_insetoide():
    """Inseto: dois pares estreitos e claros, com nervuras."""
    frente = poligono([(9, 10), (7, 5), (3, 1), (0, 0), (1, 2), (4, 6), (8, 11)])
    tras = poligono([(9, 11), (5, 8), (1, 7), (2, 9), (6, 12)])
    veias = traco(8, 9, 1, 1, DARK) + traco(8, 10, 2, 8, DARK)
    return peca(frente + tras, (), membrana=veias)


def asa_energia():
    """Elemental: estilhacos angulosos, como uma descarga congelada."""
    runs = poligono([(9, 11), (11, 6), (7, 6), (9, 2), (5, 4), (5, 0), (1, 3),
                     (3, 5), (0, 7), (4, 7), (2, 11), (6, 9)])
    return peca(runs, traco(8, 9, 5, 4, HILITE) + traco(5, 6, 2, 8, HILITE))


# ------------------------------------------------------------------ nadadeiras
# Dorsal: raiz no centro da base (4, 9); aponta para cima e para tras.
RAIZ_DORSAL = (4, 9)
# Peitoral: raiz no canto de cima a direita (7, 5); aponta para tras e para baixo.
RAIZ_PEITORAL = (7, 5)


def dorsal_curta():
    return peca(poligono([(1, 10), (2, 7), (4, 6), (6, 10)]))


def dorsal_larga():
    return peca(poligono([(0, 10), (1, 6), (3, 5), (6, 6), (7, 10)]), traco(4, 9, 3, 6, DARK))


def dorsal_espinhosa():
    runs = poligono([(0, 10), (1, 5), (2, 7), (3, 3), (4, 7), (5, 5), (7, 10)])
    return peca(runs, traco(3, 9, 3, 4, OUTLINE))


def dorsal_translucida():
    runs = poligono([(0, 10), (0, 5), (2, 3), (5, 4), (7, 7), (6, 10)])
    veias = traco(2, 9, 1, 5, DARK) + traco(4, 9, 3, 4, DARK)
    return peca(runs, (), membrana=veias)


def peitoral_curta():
    return peca(poligono([(8, 5), (8, 7), (5, 8), (4, 6)]))


def peitoral_larga():
    return peca(poligono([(8, 5), (8, 7), (5, 10), (1, 9), (2, 6)]), traco(7, 6, 3, 8, DARK))


def peitoral_espinhosa():
    runs = poligono([(8, 5), (8, 7), (5, 7), (3, 10), (3, 8), (1, 9), (2, 6)])
    return peca(runs, traco(7, 6, 3, 9, OUTLINE))


def peitoral_translucida():
    runs = poligono([(8, 5), (8, 8), (4, 10), (0, 10), (1, 7), (4, 6)])
    return peca(runs, (), membrana=traco(7, 6, 1, 9, DARK))


# ------------------------------------------------------------------ escamas
def _interior(g, x, y):
    """Pixel de miolo: base ou brilho, sem tocar o contorno nem o fundo."""
    if g[y][x] not in (BASE, HILITE):
        return False
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if not (0 <= nx < S and 0 <= ny < S) or g[ny][nx] in (TRANSP, OUTLINE):
            return False
    return True


def _padrao_lisas(x, y):
    return DARK if (x + 2 * y) % 6 == 0 else None


def _padrao_granuladas(x, y):
    return DARK if y % 2 == 0 and (x + (y // 2) * 2) % 3 == 0 else None


def _padrao_placas(x, y):
    if y % 3 == 0:
        return DARK
    if (x + (y // 3) * 2) % 4 == 0:
        return DARK
    return HILITE if y % 3 == 1 and (x + (y // 3) * 2) % 4 == 1 else None


def _padrao_cristalinas(x, y):
    if (x + y) % 5 == 0 or (x - y) % 5 == 0:
        return DARK
    return HILITE if (x + y) % 5 == 2 and (x - y) % 5 == 2 else None


PADROES_ESCAMAS = [_padrao_lisas, _padrao_granuladas, _padrao_placas, _padrao_cristalinas]


def escamas_do_corpo(g_corpo, padrao):
    """Sobreposicao 32x32: so os pixels de padrao, e so no miolo do corpo."""
    s = [[TRANSP] * S for _ in range(S)]
    for y in range(S):
        for x in range(S):
            if _interior(g_corpo, x, y):
                v = padrao(x, y)
                if v is not None:
                    s[y][x] = v
    return s


# ------------------------------------------------------------------ saida
def recortar(g, pivo):
    """Recorta a peca ao seu retangulo ocupado e reposiciona o pivo."""
    ocupados = [(x, y) for y in range(len(g)) for x in range(len(g[0])) if g[y][x]]
    x0 = min(x for x, _ in ocupados)
    y0 = min(y for _, y in ocupados)
    x1 = max(x for x, _ in ocupados)
    y1 = max(y for _, y in ocupados)
    sub = [linha_[x0:x1 + 1] for linha_ in g[y0:y1 + 1]]
    return sub, [pivo[0] - x0, pivo[1] - y0]


def salvar(g, caminho):
    h, w = len(g), len(g[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            i = g[y][x]
            if i:
                v = round(i * 255 / 4)
                px[x, y] = (v, v, v, 255)
    img.save(caminho)


def colar(dest, g, ox, oy):
    """Compoe g sobre dest (grades de indice), transparente onde g e 0."""
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x] and 0 <= oy + y < len(dest) and 0 <= ox + x < len(dest[0]):
                dest[oy + y][ox + x] = g[y][x]


def main():
    with open(VARIANTES) as f:
        variantes = json.load(f)
    nomes = {f: variantes[f]["modelos"] for f in ("asas", "nadadeiras", "escamas")}

    asas = [asa_emplumada, asa_membranosa, asa_insetoide, asa_energia]
    dorsais = [dorsal_curta, dorsal_larga, dorsal_espinhosa, dorsal_translucida]
    peitorais = [peitoral_curta, peitoral_larga, peitoral_espinhosa, peitoral_translucida]
    for f, desenhos in (("asas", asas), ("nadadeiras", dorsais), ("escamas", PADROES_ESCAMAS)):
        assert len(desenhos) == len(nomes[f]), \
            f"{f}: {len(desenhos)} desenhos para {len(nomes[f])} modelos em feature_variants.json"

    os.makedirs(DIR_ESCAMAS, exist_ok=True)
    manifesto = {
        "_meta": {
            "descricao": "Arte de asas, nadadeiras e escamas, gerada por tools/arte/gerar_apendices.py. Nunca editar a mao. 'pivo' e o pixel da peca que fica sobre a ancora do corpo; 'ordem' e a ordem de desenho, de tras para frente.",
            "versao": 1,
        },
        "escala": 1.0,
    }
    pecas_por_feature = {}

    def exportar(feature, rotulo, desenhos, raiz, slot):
        arquivos, pivos = [], []
        for i, fn in enumerate(desenhos):
            g, pivo = recortar(fn(), raiz)
            nome = f"{rotulo}_{i + 1:02d}_{nomes[feature][i]}.png"
            salvar(g, os.path.join(DIR_SAIDA, nome))
            arquivos.append(nome)
            pivos.append(pivo)
        pecas_por_feature.setdefault(feature, []).append(
            {"slot": slot, "arquivos": arquivos, "pivos": pivos})

    exportar("nadadeiras", "nadadeira_dorsal", dorsais, RAIZ_DORSAL, "dorso_tras")
    exportar("nadadeiras", "nadadeira_peitoral", peitorais, RAIZ_PEITORAL, "flanco")
    exportar("asas", "asa", asas, RAIZ_ASA, "dorso")
    manifesto["asas"] = {"ordem": 30, "pecas": pecas_por_feature["asas"]}
    manifesto["nadadeiras"] = {"ordem": 10, "pecas": pecas_por_feature["nadadeiras"]}

    # escamas: uma sobreposicao por corpo e por modelo
    corpos = {}
    for tipo, fn in TIPOS.items():
        for p, porte in enumerate(PORTES):
            runs, det, anc, fundo = fn(p)
            body = f"{tipo}_{p + 1}_{porte}"
            corpos[body] = (rasterizar(runs, det, fundo), anc)
            for i, padrao in enumerate(PADROES_ESCAMAS):
                s = escamas_do_corpo(corpos[body][0], padrao)
                salvar(s, os.path.join(DIR_ESCAMAS,
                                       f"escamas_{body}_{i + 1:02d}_{nomes['escamas'][i]}.png"))
    manifesto["escamas"] = {
        "ordem": 5,
        "sobreposicao": "escamas/escamas_{corpo}_{n}_{nome}.png",
        "modelos": nomes["escamas"],
    }
    with open(os.path.join(DIR_SAIDA, "apendices.json"), "w") as f:
        json.dump(manifesto, f, indent=2, ensure_ascii=False)

    folha_de_contato(corpos, manifesto, nomes)
    print(f"ok  asas {len(asas)}, nadadeiras {len(dorsais)}x2, escamas {len(corpos)}x{len(PADROES_ESCAMAS)}")
    print("ok  arte/apendices/apendices.json")


def _peca_carregada(nome):
    img = Image.open(os.path.join(DIR_SAIDA, nome))
    w, h = img.size
    px = img.load()
    return [[round(px[x, y][0] * 4 / 255) if px[x, y][3] else 0 for x in range(w)]
            for y in range(h)]


def compor(corpo, anc, body, manifesto, nomes, modelo, tracos):
    """Corpo com os `tracos` pedidos no modelo `modelo`, compostos como o jogo compoe
    (mesma ordem de desenho, mesmo pivo sobre a mesma ancora)."""
    margem = 10
    tam = S + 2 * margem
    g = [[TRANSP] * tam for _ in range(tam)]
    colar(g, corpo, margem, margem)
    if "escamas" in tracos:
        esc = _peca_carregada(os.path.join("escamas",
                f"escamas_{body}_{modelo + 1:02d}_{nomes['escamas'][modelo]}.png"))
        colar(g, esc, margem, margem)
    for feature in ("nadadeiras", "asas"):
        if feature not in tracos:
            continue
        for p in manifesto[feature]["pecas"]:
            a = anc.get(p["slot"])
            if a is None:
                continue
            peca_ = _peca_carregada(p["arquivos"][modelo])
            px, py = p["pivos"][modelo]
            colar(g, peca_, margem + a[0] - px, margem + a[1] - py)
    return g


def folha_de_contato(corpos, manifesto, nomes):
    """Linhas: os 8 animais em porte medio. Colunas: corpo nu, depois os 4 modelos
    de cada traco SOZINHO (asas, nadadeiras, escamas) e por ultimo os tres juntos.
    Um traco por coluna e o que deixa ver ONDE cada peca encosta."""
    esc, pad = 3, 3
    lado = S + 20
    cel = lado * esc
    colunas = [((), 0)]
    for f in ("asas", "nadadeiras", "escamas"):
        colunas += [((f,), m) for m in range(4)]
    colunas.append((("escamas", "nadadeiras", "asas"), 1))
    animais = list(TIPOS)
    folha = Image.new("RGBA", (pad + len(colunas) * (cel + pad),
                               pad + len(animais) * (cel + pad)), (24, 24, 28, 255))
    paletas = list(PALETAS.values())
    for r, tipo in enumerate(animais):
        body = f"{tipo}_2_medio"
        corpo, anc = corpos[body]
        cores = [(0, 0, 0, 0)] + [hexa(x) for x in paletas[r % len(paletas)]]
        for c, (tracos, modelo) in enumerate(colunas):
            g = compor(corpo, anc, body, manifesto, nomes, modelo, tracos)
            img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
            px = img.load()
            for y in range(lado):
                for x in range(lado):
                    px[x, y] = cores[g[y][x]]
            img = img.resize((cel, cel), Image.NEAREST)
            folha.alpha_composite(img, (pad + c * (cel + pad), pad + r * (cel + pad)))
    os.makedirs(DIR_PREVIEW, exist_ok=True)
    folha.save(os.path.join(DIR_PREVIEW, "apendices_folha_contato.png"))
    print("ok  apendices_folha_contato.png")


if __name__ == "__main__":
    main()
