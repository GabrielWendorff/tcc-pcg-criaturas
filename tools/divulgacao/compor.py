#!/usr/bin/env python3
"""Monta o banner e a capa da pagina do itch.io a partir das pecas renderizadas pelo jogo.

  godot --path . res://tools/divulgacao/renderizar.tscn   # mapa e criaturas (precisa de tela)
  python3 tools/divulgacao/compor.py                       # banner e capa

Saida em arte/divulgacao/: cada peca no tamanho nativo e em 2x, ampliada sem suavizar.
Conceito: o banner mostra o ALGORITMO (primarios -> tabela -> criatura), sobre o mapa do jogo.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fonte_pixel import FontePixel  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RECURSOS = os.path.join(RAIZ, "docs", "poster", "recursos")
SAIDA = os.path.join(RAIZ, "arte", "divulgacao")

# Cores do jogo (presentation/encontro/tema_encontro.gd).
OURO = (242, 193, 78)
OURO_C = (255, 233, 168)
PERG_C = (247, 235, 205)
PERG_E = (176, 138, 94)
CONTORNO = (31, 21, 15)
PAINEL = (36, 30, 48)
VERDE = (91, 191, 91)

TITULO = "TCC: COERÊNCIA SEMÂNTICA"
FONTE = FontePixel()
NOMES = {"fogo": "FOGO", "agua": "ÁGUA", "terra": "TERRA", "ar": "AR", "planta": "PLANTA",
         "eletrico": "ELÉTRICO", "gelo": "GELO", "sombra": "SOMBRA", "gato": "GATO",
         "peixe": "PEIXE", "ave": "AVE", "reptil": "RÉPTIL", "roedor": "ROEDOR",
         "inseto": "INSETO", "anfibio": "ANFÍBIO", "canino": "CANINO"}


def pecas():
    return json.load(open(os.path.join(RECURSOS, "pecas.json"), encoding="utf-8"))


def criatura(arquivo, recortar=True):
    im = Image.open(os.path.join(RECURSOS, arquivo)).convert("RGBA")
    return im.crop(im.getbbox()) if recortar and im.getbbox() else im


def fundo_do_mapa(largura, altura, centro, escurecer=0.6):
    mapa = Image.open(os.path.join(RECURSOS, "mapa.png")).convert("RGBA")
    x0 = max(0, min(mapa.width - largura, centro[0] - largura // 2))
    y0 = max(0, min(mapa.height - altura, centro[1] - altura // 2))
    recorte = mapa.crop((x0, y0, x0 + largura, y0 + altura))
    veu = Image.new("RGBA", recorte.size, (14, 12, 22, int(255 * escurecer)))
    return Image.alpha_composite(recorte, veu)


def gradiente_lateral(img, ate, alfa_max=0.5):
    """Escurece mais a faixa do texto, sumindo para a direita."""
    veu = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(veu)
    for x in range(ate):
        a = int(255 * alfa_max * (1 - x / ate))
        d.line([(x, 0), (x, img.height)], fill=(10, 8, 16, a))
    return Image.alpha_composite(img, veu)


def colar(base, img, x, y):
    base.alpha_composite(img, (int(x), int(y)))


def texto(base, s, x, y, cor=PERG_C, escala=1, centro=False):
    img = FONTE.render(s, cor, escala=escala, sombra=CONTORNO)
    if centro:
        x -= img.width // 2
    colar(base, img, x, y)
    return img.width, img.height


def moldura(base, caixa, fundo=PAINEL + (225,), borda=PERG_E):
    d = ImageDraw.Draw(base)
    x0, y0, x1, y1 = caixa
    d.rectangle(caixa, fill=fundo)
    d.rectangle(caixa, outline=CONTORNO, width=1)
    d.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), outline=borda, width=1)


def chance(linhas, atributo):
    for l in linhas:
        if l["atributo"] == atributo:
            return l["valor"], l["p"]
    return "", 0.0


def cartao(base, c, x, y, largura, altura):
    """Um exemplo do algoritmo: primarios -> chance do traco tipico -> a criatura."""
    moldura(base, (x, y, x + largura, y + altura))
    texto(base, "%s + %s" % (NOMES[c["elemento"]], NOMES[c["animal"]]), x + largura // 2, y + 6,
          OURO, centro=True)
    sprite = criatura(c["arquivo"])
    colar(base, sprite, x + (largura - sprite.width) // 2, y + 22 + (64 - sprite.height) // 2)
    traco = c["tracos"][-1] if c["tracos"] else ""
    _, p = chance(c["linhas"], traco)
    texto(base, "%s %d%%" % (traco, round(p * 100)), x + largura // 2, y + altura - 32,
          PERG_C, centro=True)
    valor, p = chance(c["linhas"], "paleta")
    texto(base, "%s %d%%" % (valor, round(p * 100)), x + largura // 2, y + altura - 18,
          PERG_C, centro=True)


def banner(p):
    """960 x 320: titulo e fluxo do algoritmo a esquerda, tres exemplos a direita."""
    img = fundo_do_mapa(960, 320, (1430, 420), escurecer=0.55)
    img = gradiente_lateral(img, 620, 0.55)
    texto(img, TITULO, 32, 30, OURO, escala=3)
    texto(img, "atributos correlacionados por", 34, 92, PERG_C, escala=2)
    texto(img, "probabilidade condicionada", 34, 118, PERG_C, escala=2)
    exemplos = {(c["elemento"], c["animal"]): c for c in p["criaturas"]}
    escolhidos = [exemplos[k] for k in (("fogo", "gato"), ("agua", "peixe"), ("ar", "ave"))]
    for i, c in enumerate(escolhidos):
        cartao(img, c, 548 + i * 134, 30, 124, 138)
    fluxo = "SEED  >  ELEMENTO + ANIMAL  >  P(traço | primários)  >  CRIATURA"
    moldura(img, (24, 250, 936, 290), fundo=(20, 16, 28, 200))
    texto(img, fluxo, 480, 262, OURO_C, escala=2, centro=True)
    texto(img, "nenhuma criatura é desenhada à mão: cada seed gera 100", 34, 160, PERG_E)
    texto(img, "e o corpo segue o elemento e o animal", 34, 176, PERG_E)
    return img


def banner_bestiario(p):
    """Alternativa 960 x 320: titulo e a primeira dezena do bestiario de uma seed."""
    img = fundo_do_mapa(960, 320, (1500, 820), escurecer=0.62)
    img = gradiente_lateral(img, 520, 0.5)
    texto(img, TITULO, 32, 40, OURO, escala=3)
    texto(img, "cada seed, um bestiário", 34, 104, PERG_C, escala=2)
    texto(img, "de 100 criaturas coerentes", 34, 130, PERG_C, escala=2)
    texto(img, "SEED %d" % 123456789, 34, 266, OURO_C, escala=2)
    for i, c in enumerate(p["grade"][:10]):
        sprite = criatura(c["arquivo"])
        cx = 524 + (i % 5) * 84
        base_y = 132 + (i // 5) * 112
        colar(img, sprite, cx + (84 - sprite.width) // 2, base_y - sprite.height)
        texto(img, NOMES[c["elemento"]], cx + 42, base_y + 6, PERG_E, centro=True)
    return img


def capa(p):
    """630 x 500 (capa do itch.io): titulo, seis exemplos e a frase."""
    img = fundo_do_mapa(630, 500, (1430, 470), escurecer=0.58)
    texto(img, "TCC", 315, 34, OURO_C, escala=3, centro=True)
    texto(img, "COERÊNCIA", 315, 78, OURO, escala=5, centro=True)
    texto(img, "SEMÂNTICA", 315, 146, OURO, escala=5, centro=True)
    for i, c in enumerate(p["criaturas"][:6]):
        x = 20 + i * 100
        moldura(img, (x, 222, x + 92, 350))
        texto(img, NOMES[c["elemento"]], x + 46, 228, OURO, centro=True)
        sprite = criatura(c["arquivo"])
        colar(img, sprite, x + (92 - sprite.width) // 2, 318 - sprite.height)
        texto(img, NOMES[c["animal"]], x + 46, 328, PERG_C, centro=True)
    texto(img, "o corpo segue o elemento e o animal", 315, 392, PERG_C, escala=2, centro=True)
    texto(img, "cada seed, um bestiário de 100 criaturas", 315, 440, PERG_E, centro=True)
    return img


def salvar(img, nome):
    os.makedirs(SAIDA, exist_ok=True)
    img = img.convert("RGB")
    img.save(os.path.join(SAIDA, nome + ".png"))
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(
        os.path.join(SAIDA, nome + "_2x.png"))
    print("ok  %s (%dx%d e 2x)" % (nome, img.width, img.height))


def main():
    p = pecas()
    salvar(banner(p), "banner_960x320")
    salvar(banner_bestiario(p), "banner_bestiario_960x320")
    salvar(capa(p), "capa_630x500")


if __name__ == "__main__":
    main()
