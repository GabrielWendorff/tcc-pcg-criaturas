#!/usr/bin/env python3
r"""
preview_mundo.py — renderiza o mapa autoral inteiro num PNG, fora da engine.

Saida: tools/mapas/_preview/mundo.png (e _debug.png com os marcadores)

Serve para conferir o mapa sem abrir o Godot. Nao e uma ilustracao: usa a MESMA
projecao, a MESMA regra de escolha de tile e a MESMA ordenacao por profundidade
que MundoIso aplica em GDScript —

    centro(gx, gy) = ((gx - gy + 1) * 16, (gx + gy + 1) * 8)     [TileMapLayer.map_to_local]

— entao o que aparece aqui e o que aparece no jogo. Se as duas divergirem, uma
das duas esta errada, e essa e justamente a informacao que se quer.

Uso:
    python3 tools/mapas/preview_mundo.py            # mundo inteiro
    python3 tools/mapas/preview_mundo.py --debug    # + regioes, zonas e colisao
"""

import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, os.path.join(RAIZ, "tools", "arte"))

from mundo_lib import ruido  # noqa: E402

CEL_L, CEL_A = 32, 16
MAPA = os.path.join(RAIZ, "autoral", "mapas", "mundo.json")
DIR_ARTE = os.path.join(RAIZ, "arte", "mundo")
SAIDA = os.path.join(AQUI, "_preview")

# Mesma ordem de linhas da folha do protagonista (ver autoral/gerar_protagonista.py)
LINHA_DIRECAO = {"baixo": 0, "esquerda": 1, "direita": 2, "cima": 3}


def carregar():
    with open(MAPA, encoding="utf-8") as f:
        mapa = json.load(f)
    with open(os.path.join(DIR_ARTE, "atlas_terreno.json"), encoding="utf-8") as f:
        indice = json.load(f)
    with open(os.path.join(DIR_ARTE, "props.json"), encoding="utf-8") as f:
        props = json.load(f)["props"]
    atlas = Image.open(os.path.join(DIR_ARTE, indice["arquivo"])).convert("RGBA")
    return mapa, indice, props, atlas


def mascara_de_bordas(terreno, gx, gy, indice):
    """Bits das arestas em que o terreno da celula ACABA. Espelho exato de
    MundoIso._mascara_de_bordas()."""
    L, A = len(terreno[0]), len(terreno)
    ch = terreno[gy][gx]
    grupo = indice["grupos_de_transicao"].get(_nome(ch, indice), None)
    if grupo is None:
        return 0
    mascara = 0
    for bit, (dx, dy) in ((1, (-1, 0)), (2, (0, -1)), (4, (1, 0)), (8, (0, 1))):
        nx, ny = gx + dx, gy + dy
        # Fora do mapa conta como "acaba": a borda externa recebe acabamento em
        # vez de terminar num corte reto no vazio.
        viz = terreno[ny][nx] if 0 <= nx < L and 0 <= ny < A else None
        if viz is None or _nome(viz, indice) not in grupo:
            mascara |= bit
    return mascara


_LEGENDA = {}


def _nome(ch, _indice):
    return _LEGENDA.get(ch, "grama")


def variante_grama(gx, gy, pesos):
    """Escolha deterministica da variante de grama. Espelho de
    MundoIso._variante_de_grama()."""
    r = ruido(gx, gy, 907)
    acumulado = 0.0
    for i, w in enumerate(pesos):
        acumulado += w
        if r < acumulado:
            return i
    return len(pesos) - 1


def tile_de(terreno, gx, gy, indice):
    """(coluna, linha) da celula no atlas."""
    nome = _nome(terreno[gy][gx], indice)
    linha = indice["linhas"][nome]
    if nome == "grama":
        return variante_grama(gx, gy, indice["pesos_grama"]), linha
    return mascara_de_bordas(terreno, gx, gy, indice), linha


def render(debug=False):
    mapa, indice, props, atlas = carregar()
    _LEGENDA.update(mapa["legenda"])
    # NPCs entram so na conferencia: o mapa nao os carrega (quem instancia e
    # GerenciadorDialogo, do mesmo autoral/npcs/npcs.json).
    caminho_npcs = os.path.join(RAIZ, "autoral", "npcs", "npcs.json")
    if os.path.exists(caminho_npcs):
        with open(caminho_npcs, encoding="utf-8") as f:
            mapa["_npcs_conferencia"] = json.load(f).get("npcs", [])
    L = mapa["dimensoes"]["largura"]
    A = mapa["dimensoes"]["profundidade"]
    terreno = mapa["terreno"]

    larg_px, alt_px = (L + A) * CEL_L // 2, (L + A) * CEL_A // 2
    ox = (A - 1) * CEL_L // 2                      # desloca o x negativo do losango
    img = Image.new("RGBA", (larg_px, alt_px), (0x12, 0x16, 0x1c, 255))

    def centro(gx, gy, W=1, D=1):
        return (ox + (gx - gy + 1) * (CEL_L // 2) + (W - D) * (CEL_L // 4),
                (gx + gy + 1) * (CEL_A // 2) + (W + D) * (CEL_A // 4) - CEL_A // 2)

    # --- chao ---
    for gy in range(A):
        for gx in range(L):
            col, lin = tile_de(terreno, gx, gy, indice)
            tile = atlas.crop((col * CEL_L, lin * CEL_A,
                               (col + 1) * CEL_L, (lin + 1) * CEL_A))
            cx, cy = centro(gx, gy)
            img.alpha_composite(tile, (cx - CEL_L // 2, cy - CEL_A // 2))

    # --- props + jogador, ordenados por Y (o mesmo criterio do y-sort) ---
    fila = []
    for grupo in ("penhascos", "arvores", "pedras", "decoracao", "casas"):
        for p in mapa[grupo]:
            meta = props[p["prop"]]
            W, D = meta["celulas"]
            fila.append((centro(*p["celula"], W, D), meta, p))

    protagonista = os.path.join(RAIZ, "autoral", "protagonista_1x.png")
    jogador = None
    if os.path.exists(protagonista):
        folha = Image.open(protagonista).convert("RGBA")
        cel = folha.width // 4
        jogador = folha.crop((0, LINHA_DIRECAO["baixo"] * cel, cel, 
                              (LINHA_DIRECAO["baixo"] + 1) * cel))
        pos = centro(*mapa["spawn_jogador"])
        fila.append((pos, {"ancora": [cel // 2, cel - 3], "celulas": [1, 1]},
                     {"prop": "__jogador__"}))

    fila.sort(key=lambda item: item[0][1])
    for (px, py), meta, p in fila:
        if p["prop"] == "__jogador__":
            sprite = jogador
        else:
            sprite = Image.open(os.path.join(DIR_ARTE, "props",
                                             meta["arquivo"])).convert("RGBA")
        ax, ay = meta["ancora"]
        img.alpha_composite(sprite, (px - ax, py - ay))

    os.makedirs(SAIDA, exist_ok=True)
    destino = os.path.join(SAIDA, "mundo.png")
    img.save(destino)
    print(f"ok  {destino}  ({larg_px}x{alt_px} px)")

    if debug:
        dbg = img.copy()
        d = ImageDraw.Draw(dbg, "RGBA")
        for gy in range(A):                        # celulas bloqueadas
            for gx in range(L):
                if terreno[gy][gx] not in mapa["bloqueia"]:
                    continue
                cx, cy = centro(gx, gy)
                d.polygon([(cx, cy - 8), (cx + 16, cy), (cx, cy + 8), (cx - 16, cy)],
                          fill=(0xff, 0x30, 0x30, 40))
        for ponto in mapa["pontos_encontro"]:      # marcadores de encontro
            cx, cy = centro(*ponto["celula"])
            r = ponto["raio_celulas"]
            d.ellipse([cx - r * 22, cy - r * 11, cx + r * 22, cy + r * 11],
                      outline=(0xff, 0xe0, 0x40, 220), width=2)
            d.text((cx - 30, cy - 6), ponto["id"], fill=(0xff, 0xe0, 0x40, 255))
        for casa in mapa["casas"]:                 # etiqueta das casas
            W, D = props[casa["prop"]]["celulas"]
            cx, cy = centro(*casa["celula"], W, D)
            d.text((cx - 24, cy), f"{casa['id']}", fill=(0x8c, 0xe8, 0xff, 255))
        for r in mapa.get("regioes", []):          # contorno de cada regiao
            x0, y0, x1, y1 = r["retangulo"]
            quinas = [centro(x0, y0), centro(x1 + 1, y0),
                      centro(x1 + 1, y1 + 1), centro(x0, y1 + 1)]
            d.polygon(quinas, outline=(0x9c, 0xd8, 0xff, 200))
            mx, my = centro((x0 + x1) // 2, (y0 + y1) // 2)
            d.text((mx - 40, my - 8), r["nome"], fill=(0x9c, 0xd8, 0xff, 255))
        for npc in mapa.get("_npcs_conferencia", []):
            cx, cy = centro(*npc["celula"])
            d.ellipse([cx - 6, cy - 4, cx + 6, cy + 4], outline=(0xff, 0x9c, 0xd8), width=2)
            d.text((cx - 12, cy - 18), npc["id"], fill=(0xff, 0x9c, 0xd8, 255))
        cx, cy = centro(*mapa["spawn_jogador"])
        d.ellipse([cx - 8, cy - 5, cx + 8, cy + 5], outline=(0x40, 0xff, 0x80), width=2)
        d.text((cx - 14, cy - 20), "SPAWN", fill=(0x40, 0xff, 0x80, 255))
        destino_dbg = os.path.join(SAIDA, "mundo_debug.png")
        dbg.save(destino_dbg)
        print(f"ok  {destino_dbg}")


if __name__ == "__main__":
    render(debug="--debug" in sys.argv)
