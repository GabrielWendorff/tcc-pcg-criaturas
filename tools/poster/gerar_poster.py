#!/usr/bin/env python3
"""Gera o poster A0 (841 x 1189 mm) do Poster + Demo Day.

  godot --headless --path . -s res://tools/poster/dados_poster.gd   # numeros (docs/poster/dados.json)
  godot --path . res://tools/divulgacao/renderizar.tscn               # mapa e criaturas (precisa de tela)
  godot --path . res://tools/divulgacao/capturar_telas.tscn           # telas do jogo (precisa de tela)
  PYTHONPATH=<segno> python3 tools/poster/gerar_poster.py             # este script

Saida em docs/poster/: poster.html, poster.pdf (vetorial, A0) e poster_previa.png.
Segue o template oficial (cabecalho com logo, titulo, nome, e-mail e curso; faixas vermelhas;
Arial; secoes INTRODUCAO, DESENVOLVIMENTO, RESULTADOS, CONCLUSOES, REFERENCIAS) com a
identidade do jogo: titulo na fonte pixel e o mapa do jogo como faixa de destaque.
Todo numero vem de dados.json, medido no gerador real.
"""
import json
import math
import os
import shutil
import subprocess
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from PIL import Image  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, os.path.join(RAIZ, "tools", "divulgacao"))
from fonte_pixel import FontePixel  # noqa: E402

POSTER = os.path.join(RAIZ, "docs", "poster")
RECURSOS = os.path.join(POSTER, "recursos")
GERADO = os.path.join(POSTER, "gerado")
LOGO = os.path.join(POSTER, "logo_catolica_sc.jpeg")

VERMELHO = "#c00000"
AZUL = "#000099"
TINTA = "#1d1a22"
CINZA = "#6b6670"
OURO = "#f2c14e"
PAINEL = "#241e30"
COR_BRACO = {"independente": "#a7a3ad", "v1": "#e3a8a8", "v2": VERMELHO}
NOME_BRACO = {"independente": "Sorteio independente", "v1": "Condicionado v1",
              "v2": "Condicionado v2 (no jogo)"}
COR_MATIZ = {"vermelho": "#d23c3c", "laranja": "#e8812a", "amarelo": "#e8c53a",
             "verde": "#5bbf5b", "ciano": "#4ccfd8", "azul": "#3a6fd8", "roxo": "#8a52c8",
             "marrom": "#8b5a2b", "cinza": "#8d8d8d", "branco": "#ece9e2"}
NOME = {"fogo": "fogo", "agua": "água", "terra": "terra", "ar": "ar", "planta": "planta",
        "eletrico": "elétrico", "gelo": "gelo", "sombra": "sombra", "gato": "gato",
        "peixe": "peixe", "ave": "ave", "reptil": "réptil", "roedor": "roedor",
        "inseto": "inseto", "anfibio": "anfíbio", "canino": "canino"}

plt.rcParams.update({"font.family": ["Arial", "Liberation Sans", "DejaVu Sans"], "svg.fonttype": "none", "font.size": 22,
                     "axes.edgecolor": "#333", "axes.labelcolor": TINTA,
                     "xtick.color": TINTA, "ytick.color": TINTA})


def ler(caminho):
    return json.load(open(caminho, encoding="utf-8"))


def num(x, casas=1):
    return ("%.*f" % (casas, x)).replace(".", ",")


# ------------------------------------------------------------------ imagens

def ampliar(origem, destino, fator, recorte=None):
    """Pixel art ampliada sem suavizar: o leitor de PDF nao borra o que ja e grande."""
    im = Image.open(origem).convert("RGBA")
    if recorte:
        im = im.crop(recorte)
    elif im.getbbox():
        im = im.crop(im.getbbox()) if "criatura" in destino or "par_" in destino else im
    im.resize((im.width * fator, im.height * fator), Image.NEAREST).save(destino)
    return os.path.basename(destino)


def titulo_pixel(texto, destino, cor):
    fonte = FontePixel()
    img = fonte.render(texto, cor, escala=12, sombra=(60, 0, 0), deslocamento=1)
    img.save(destino)


def preparar_imagens(pecas):
    os.makedirs(GERADO, exist_ok=True)
    titulo_pixel("TCC: COERÊNCIA SEMÂNTICA", os.path.join(GERADO, "titulo.png"), (192, 0, 0))
    mapa = Image.open(os.path.join(RECURSOS, "mapa.png")).convert("RGB")
    # Faixa do mapa: a vila, o rio e o distrito industrial.
    faixa = mapa.crop((420, 120, 2620, 1000))
    faixa.resize((faixa.width * 3, faixa.height * 3), Image.NEAREST).save(
        os.path.join(GERADO, "mapa_faixa.png"))
    for c in pecas["criaturas"] + pecas["pares"]:
        ampliar(os.path.join(RECURSOS, c["arquivo"]),
                os.path.join(GERADO, "criatura_" + c["arquivo"]), 10)
    for c in pecas["grade"][:18]:
        ampliar(os.path.join(RECURSOS, c["arquivo"]),
                os.path.join(GERADO, "criatura_" + c["arquivo"]), 6)
    ampliar(os.path.join(RECURSOS, "tela_batalha.png"), os.path.join(GERADO, "tela_batalha.png"),
            3, recorte=(236, 66, 918, 582))
    ampliar(os.path.join(RECURSOS, "tela_bestiario.png"),
            os.path.join(GERADO, "tela_bestiario.png"), 3, recorte=(80, 72, 1072, 572))
    shutil.copy(LOGO, os.path.join(GERADO, "logo.jpeg"))


def qr(url, destino):
    import segno
    segno.make(url, error="m").save(destino, scale=10, border=2, dark="#1d1a22")
    return os.path.basename(destino)


# ------------------------------------------------------------------ graficos

def salvar(fig, nome):
    fig.savefig(os.path.join(GERADO, nome), format="svg", transparent=True,
                bbox_inches="tight", pad_inches=0.05)
    plt.close(fig)
    return nome


def grafico_informacao_mutua(d):
    pares = [("elemento->cor", "elemento → cor"), ("elemento->porte", "elemento → porte"),
             ("animal->morfologia", "animal → traços"), ("animal->porte", "animal → porte")]
    fig, ax = plt.subplots(figsize=(14.6, 3.4))
    largura = 0.26
    for i, braco in enumerate(("independente", "v1", "v2")):
        valores = [d["informacao_mutua"][braco][p] for p, _ in pares]
        xs = [k + (i - 1) * largura for k in range(len(pares))]
        barras = ax.bar(xs, valores, largura, color=COR_BRACO[braco], label=NOME_BRACO[braco])
        for b, v in zip(barras, valores):
            ax.text(b.get_x() + b.get_width() / 2, v + 0.03, num(v, 2), ha="center",
                    va="bottom", fontsize=20, color=TINTA)
    ax.set_xticks(range(len(pares)), [r for _, r in pares], fontsize=22)
    ax.set_ylabel("bits", fontsize=22)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(frameon=False, fontsize=20, loc="lower center", ncol=3,
              bbox_to_anchor=(0.5, 1.0), handlelength=1.2, columnspacing=1.4)
    ax.set_ylim(0, 1.9)
    return salvar(fig, "grafico_informacao_mutua.svg")


def grafico_cor(d):
    matizes = d["vocabulario"]["derivados"]["matiz"]
    elementos = d["vocabulario"]["primarios"]["elemento"]
    fig, eixos = plt.subplots(1, 2, figsize=(14.6, 4.2), sharey=True)
    for ax, braco, titulo in ((eixos[0], "v2", "condicionado"),
                              (eixos[1], "independente", "independente")):
        tabela = d["matiz_por_elemento"][braco]
        for i, e in enumerate(elementos):
            total = sum(tabela.get(e, {}).values()) or 1
            esquerda = 0.0
            for m in matizes:
                f = tabela.get(e, {}).get(m, 0) / total
                ax.barh(i, f, left=esquerda, color=COR_MATIZ[m], edgecolor="white", linewidth=0.6)
                esquerda += f
        ax.set_title(titulo, fontsize=24, color=VERMELHO if braco == "v2" else CINZA,
                     fontweight="bold")
        ax.set_xlim(0, 1)
        ax.set_xticks([0.25, 0.5, 0.75], ["25%", "50%", "75%"], fontsize=20)
        ax.spines[["top", "right", "left"]].set_visible(False)
        ax.tick_params(left=False)
    eixos[0].set_yticks(range(len(elementos)), [NOME[e] for e in elementos], fontsize=22)
    eixos[0].invert_yaxis()
    fig.subplots_adjust(wspace=0.12)
    return salvar(fig, "grafico_cor.svg")


def grafico_tracos(d):
    tracos = d["vocabulario"]["derivados"]["morfologia"]
    animais = d["vocabulario"]["primarios"]["animal_base"]
    fig, eixos = plt.subplots(1, 2, figsize=(14.6, 4.3), sharey=True)
    for ax, braco, titulo in ((eixos[0], "v2", "condicionado"),
                              (eixos[1], "independente", "independente")):
        m = [[d["traco_por_animal"][braco][a][t] for t in tracos] for a in animais]
        ax.imshow(m, cmap="Reds", vmin=0, vmax=1, aspect="auto")
        for i in range(len(animais)):
            for j in range(len(tracos)):
                v = m[i][j]
                ax.text(j, i, "%d" % round(v * 100), ha="center", va="center", fontsize=20,
                        color="white" if v > 0.55 else TINTA)
        ax.set_xticks(range(len(tracos)), tracos, fontsize=20)
        ax.set_title(titulo, fontsize=24, color=VERMELHO if braco == "v2" else CINZA,
                     fontweight="bold")
        ax.tick_params(length=0)
        for s in ax.spines.values():
            s.set_visible(False)
    eixos[0].set_yticks(range(len(animais)), [NOME[a] for a in animais], fontsize=21)
    fig.subplots_adjust(wspace=0.06)
    return salvar(fig, "grafico_tracos.svg")


def grafico_tabela(d):
    animais = d["vocabulario"]["primarios"]["animal_base"]
    elementos = d["vocabulario"]["primarios"]["elemento"]
    t = d["tabela"]["nadadeiras"]
    m = [[t[a][e] for e in elementos] for a in animais]
    fig, ax = plt.subplots(figsize=(14.6, 4.9))
    ax.imshow(m, cmap="Blues", vmin=0, vmax=1, aspect="auto")
    for i in range(len(animais)):
        for j in range(len(elementos)):
            v = m[i][j]
            ax.text(j, i, num(v, 2), ha="center", va="center", fontsize=20,
                    color="white" if v > 0.55 else TINTA,
                    fontweight="bold" if (animais[i], elementos[j]) in
                    (("peixe", "agua"), ("peixe", "fogo")) else "normal")
    ax.set_xticks(range(len(elementos)), [NOME[e] for e in elementos], fontsize=20)
    ax.set_yticks(range(len(animais)), [NOME[a] for a in animais], fontsize=21)
    ax.xaxis.tick_top()
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    for j, i in ((elementos.index("agua"), animais.index("peixe")),
                 (elementos.index("fogo"), animais.index("peixe"))):
        ax.add_patch(plt.Rectangle((j - 0.5, i - 0.5), 1, 1, fill=False, edgecolor=VERMELHO,
                                   linewidth=4))
    return salvar(fig, "grafico_tabela_nadadeiras.svg")


def grafico_surpresa(d):
    fig, ax = plt.subplots(figsize=(14.6, 5.0))
    bins = [i for i in range(0, 46, 1)]
    for braco in ("independente", "v2"):
        ax.hist(d["surpresa"][braco]["bits"], bins=bins, color=COR_BRACO[braco], alpha=0.85,
                label="%s: %d%% atípicas" % (NOME_BRACO[braco],
                                              round(d["surpresa"][braco]["atipicas"] * 100)))
    limiar = d["limiar_atipica_bits"]
    ax.axvline(limiar, color=TINTA, linestyle="--", linewidth=2.5)
    ax.text(limiar + 0.6, ax.get_ylim()[1] * 0.92, "atípica acima de %s bits" % num(limiar, 0),
            fontsize=19, color=TINTA)
    ax.set_xlabel("surpresa da criatura: −log₂ P(derivados | primários), em bits", fontsize=21)
    ax.set_yticks([])
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.legend(frameon=False, fontsize=19, loc="upper right")
    return salvar(fig, "grafico_surpresa.svg")


# ------------------------------------------------------------------ html

def campo(valor, rotulo):
    if valor:
        return valor
    return '<span class="preencher">%s</span>' % rotulo


def chance(c, atributo):
    for l in c["linhas"]:
        if l["atributo"] == atributo:
            return l["valor"], l["p"]
    return "", 0.0


def cartao_exemplo(c):
    traco = c["tracos"][-1] if c["tracos"] else "porte"
    valor, p = chance(c, traco) if c["tracos"] else chance(c, "porte")
    cor, pc = chance(c, "paleta")
    return f'''<div class="exemplo">
  <div class="ex-primarios">{NOME[c["elemento"]].upper()} + {NOME[c["animal"]].upper()}</div>
  <img class="pixel" src="gerado/criatura_{c["arquivo"]}">
  <div class="ex-linha">{traco} <b>{round(p * 100)}%</b></div>
  <div class="ex-linha">cor {cor} <b>{round(pc * 100)}%</b></div>
</div>'''


def par(pc, pi):
    def descr(c):
        tracos = ", ".join(c["tracos"]) or "sem traços"
        return f'{c["paleta"]} · {c["matiz"]}<br>{tracos}'
    return f'''<div class="par">
  <div class="par-titulo">{NOME[pc["elemento"]]} + {NOME[pc["animal"]]}</div>
  <div class="par-lados">
    <div class="lado bom"><img class="pixel" src="gerado/criatura_{pc["arquivo"]}">
      <div class="rot">condicionado</div><div class="desc">{descr(pc)}</div></div>
    <div class="lado ruim"><img class="pixel" src="gerado/criatura_{pi["arquivo"]}">
      <div class="rot">independente</div><div class="desc">{descr(pi)}</div></div>
  </div>
</div>'''


def html(cfg, d, pecas, graficos, qrs):
    mi = d["informacao_mutua"]
    razoes = [mi["v2"][p] / mi["independente"][p] for p in
              ("elemento->paleta", "elemento->matiz", "elemento->cor", "elemento->porte",
               "animal->morfologia")]
    exemplos = "\n".join(cartao_exemplo(c) for c in pecas["criaturas"][:6])
    pares = pecas["pares"]
    pares_html = "\n".join(par(pares[i], pares[i + 1]) for i in range(0, min(len(pares), 8), 2))
    grade = "\n".join(f'<img class="pixel" src="gerado/criatura_{c["arquivo"]}">'
                      for c in pecas["grade"][:18])
    qr_jogo = (f'<img src="gerado/{qrs["jogo"]}">' if qrs.get("jogo") else
               '<div class="qr-vazio">QR da build<br>(preencher url_jogo<br>em config.json)</div>')
    atip_v2 = round(d["surpresa"]["v2"]["atipicas"] * 100)
    atip_ind = round(d["surpresa"]["independente"]["atipicas"] * 100)
    return f'''<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="utf-8"><title>{cfg["titulo"]}</title>
<style>
@page {{ size: 841mm 1189mm; margin: 0; }}
* {{ box-sizing: border-box; }}
html, body {{ margin: 0; padding: 0; background: #fff; }}
body {{ width: 841mm; height: 1189mm; font-family: Arial, "Liberation Sans", sans-serif;
  color: {TINTA}; font-size: 26pt; line-height: 1.24; position: relative; overflow: hidden; }}
.pixel {{ image-rendering: pixelated; }}
header {{ height: 150mm; display: flex; align-items: center; padding: 0 22mm; gap: 14mm; }}
header .logo {{ width: 205mm; }}
header .cab {{ flex: 1; text-align: center; }}
header .titulo {{ width: 100%; max-width: 560mm; }}
header .nome {{ font-size: 40pt; font-weight: bold; font-style: italic; margin-top: 7mm; }}
header .email {{ font-size: 34pt; font-weight: bold; font-style: italic; color: {AZUL}; }}
header .curso {{ font-size: 30pt; font-weight: bold; font-style: italic; color: {VERMELHO}; }}
.faixa {{ height: 9mm; background: {VERMELHO}; }}
.heroi {{ position: relative; height: 232mm; overflow: hidden; background: #111; }}
.heroi > img.mapa {{ position: absolute; left: 0; top: 0; width: 100%; height: 100%;
  object-fit: cover; object-position: 50% 40%; }}
.heroi .veu {{ position: absolute; inset: 0;
  background: linear-gradient(90deg, rgba(14,12,22,.88) 0%, rgba(14,12,22,.72) 42%, rgba(14,12,22,.25) 100%); }}
.heroi .chamada {{ position: absolute; left: 24mm; top: 16mm; width: 560mm; color: #f7ebcd; }}
.heroi .chamada h2 {{ font-size: 60pt; line-height: 1.05; margin: 0 0 5mm; color: {OURO}; }}
.heroi .chamada p {{ font-size: 29pt; margin: 0; }}
.heroi .qrs {{ position: absolute; right: 22mm; top: 14mm; margin: 0; gap: 7mm; }}
.heroi .qr {{ background: #fff; padding: 3mm 3mm 2mm; color: {TINTA}; font-size: 22pt; }}
.heroi .qr img, .heroi .qr-vazio {{ width: 74mm; height: 74mm; }}
.heroi .exemplos {{ position: absolute; left: 22mm; right: 22mm; bottom: 12mm;
  display: grid; grid-template-columns: repeat(6, 1fr); gap: 5mm; }}
.exemplo {{ background: rgba(36,30,48,.92); border: 2.2mm solid #b08a5e; outline: .8mm solid #1f150f;
  color: #f7ebcd; text-align: center; padding: 4mm 3mm 5mm; }}
.exemplo img {{ height: 44mm; max-width: 100%; object-fit: contain; display: block; margin: 2mm auto 2mm; }}
.ex-primarios {{ color: {OURO}; font-weight: bold; font-size: 21pt; }}
.ex-linha {{ font-size: 21pt; }}
.ex-linha b {{ color: {OURO}; }}
main {{ display: grid; grid-template-columns: 1fr 1fr; gap: 18mm; padding: 6mm 22mm 0; }}
h3 {{ color: {VERMELHO}; font-size: 44pt; text-align: center; margin: 4mm 0 3mm; letter-spacing: .5mm; }}
h4 {{ font-size: 29pt; margin: 4mm 0 1.5mm; }}
p {{ margin: 0 0 3mm; text-align: justify; }}
ul {{ margin: 0 0 3mm; padding-left: 9mm; }}
li {{ margin-bottom: 1.6mm; }}
.destaque {{ color: {VERMELHO}; font-weight: bold; }}
.grafico {{ width: 100%; display: block; margin: 2mm 0; }}
.legenda {{ font-size: 21pt; color: {CINZA}; text-align: center; margin: 0 0 3mm; line-height: 1.15; }}
.pares {{ display: grid; grid-template-columns: 1fr 1fr; gap: 4mm; margin: 2mm 0; }}
.par {{ border: .9mm solid #ddd; padding: 2mm 3mm; }}
.par-titulo {{ font-weight: bold; text-align: center; font-size: 23pt; }}
.par-lados {{ display: grid; grid-template-columns: 1fr 1fr; gap: 2mm; text-align: center; }}
.lado img {{ height: 28mm; max-width: 100%; object-fit: contain; }}
.lado .rot {{ font-size: 20pt; font-weight: bold; }}
.lado.bom .rot {{ color: {VERMELHO}; }}
.lado.ruim .rot {{ color: {CINZA}; }}
.lado .desc {{ font-size: 20pt; line-height: 1.12; }}
.fluxo {{ display: flex; align-items: stretch; gap: 3mm; margin: 4mm 0; }}
.fluxo .passo {{ flex: 1; background: {PAINEL}; color: #f7ebcd; padding: 3mm 2mm; text-align: center;
  font-size: 21pt; border-bottom: 2mm solid {OURO}; line-height: 1.15; }}
.fluxo .passo b {{ display: block; color: {OURO}; font-size: 23pt; margin-bottom: 1mm; }}
.fluxo .seta {{ align-self: center; color: {VERMELHO}; font-size: 40pt; font-weight: bold; }}
.formula {{ font-family: "DejaVu Sans Mono", monospace; font-size: 23pt; background: #f6f2ea;
  border-left: 3mm solid {VERMELHO}; padding: 2mm 5mm; margin: 2mm 0; }}
.camadas {{ display: grid; grid-template-columns: 1fr 1fr; gap: 3mm; margin: 3mm 0; }}
.camada {{ border: 1mm solid {TINTA}; padding: 2mm 4mm; font-size: 21pt; line-height: 1.15; }}
.camada b {{ display: block; font-size: 23pt; }}
.camada.seed {{ grid-column: 1 / 3; background: {PAINEL}; color: {OURO}; text-align: center;
  font-weight: bold; border-color: {PAINEL}; }}
.camada.gerada {{ background: #fbecec; border-color: {VERMELHO}; }}
.kpis {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 4mm; margin: 2mm 0 4mm; }}
.kpi {{ background: {PAINEL}; color: #f7ebcd; text-align: center; padding: 4mm 2mm; }}
.kpi b {{ display: block; color: {OURO}; font-size: 42pt; line-height: 1.05; }}
.kpi span {{ font-size: 20pt; line-height: 1.1; display: block; }}
.telas {{ display: flex; gap: 4mm; justify-content: center; }}
.telas img {{ height: 78mm; border: .8mm solid {TINTA}; }}
.grade {{ display: grid; grid-template-columns: repeat(9, 1fr); gap: 1mm; background: {PAINEL};
  padding: 3mm; align-items: end; }}
.grade img {{ width: 100%; height: 22mm; object-fit: contain; }}
.qrs {{ display: flex; gap: 10mm; justify-content: center; margin: 4mm 0; }}
.qr {{ text-align: center; font-weight: bold; font-size: 25pt; }}
.qr img, .qr-vazio {{ width: 82mm; height: 82mm; display: block; margin: 0 auto 2mm; }}
.qr-vazio {{ border: 1.2mm dashed {VERMELHO}; background: #ffff00; font-size: 18pt; display: flex;
  align-items: center; justify-content: center; text-align: center; }}
.referencias p {{ font-size: 20pt; text-align: left; line-height: 1.2; margin-bottom: 2mm; }}
.preencher {{ background: #ffff00; padding: 0 3mm; }}
footer {{ position: absolute; left: 0; right: 0; bottom: 0; }}
footer .faixa {{ height: 9mm; }}
footer .rodape {{ height: 20mm; display: flex; align-items: center; justify-content: center;
  font-size: 22pt; color: {CINZA}; }}
</style></head><body>
<header>
  <img class="logo" src="gerado/logo.jpeg">
  <div class="cab">
    <img class="titulo pixel" src="gerado/titulo.png" alt="{cfg["titulo"]}">
    <div class="nome">{cfg["nome"]}</div>
    <div class="email">{campo(cfg["email"], "e-mail institucional @edu.catolicasc.org.br")}</div>
    <div class="curso">{cfg["curso"]}</div>
  </div>
</header>
<div class="faixa"></div>
<section class="heroi">
  <img class="mapa pixel" src="gerado/mapa_faixa.png">
  <div class="veu"></div>
  <div class="chamada">
    <h2>Cada seed gera um bestiário de 100 criaturas.</h2>
    <p>Nenhuma é desenhada à mão. O corpo de cada uma combina com o seu elemento e o seu
    animal, porque os atributos são sorteados de <b>tabelas de probabilidade condicionada</b>,
    e não de forma independente.</p>
    <p style="margin-top:3mm;font-size:23pt;color:#c9b38c">Ao fundo, o mapa do jogo, com a
    vegetação sorteada pela mesma seed. Abaixo, criaturas reais do gerador e a chance que a
    tabela dava a cada traço.</p>
  </div>
  <div class="qrs">
    <div class="qr">{qr_jogo}Jogar no navegador</div>
    <div class="qr"><img src="gerado/{qrs["repositorio"]}">Código e Wiki</div>
  </div>
  <div class="exemplos">
{exemplos}
  </div>
</section>
<main>
<div class="coluna">
  <h3>INTRODUÇÃO</h3>
  <ul>
    <li><b>Problema.</b> Jogos comerciais geram conteúdo em grande escala e em tempo real, mas
    sem coerência entre os atributos: em <i>No Man's Sky</i>, a cor, a forma e o habitat de uma
    criatura não conversam. Trabalhos acadêmicos alcançam coerência, mas com busca custosa,
    longe do tempo real.</li>
    <li><b>Objetivo.</b> Gerar criaturas <span class="destaque">em escala, coerentes e em tempo
    real ao mesmo tempo</span>, com um mecanismo leve, dentro de um RPG jogável.</li>
  </ul>
  <h4>O que é coerência semântica, aqui</h4>
  <p>É o corpo da criatura <b>fazer sentido</b> com o que ela é: um gato de fogo tende a ter
  garras e cores quentes; um peixe de água, nadadeiras, escamas e cores frias. É tendência, não
  regra: um peixe de fogo existe, e as chances se ajustam a ele.</p>
  <p>Os mesmos primários, sorteados de dois jeitos:</p>
  <div class="pares">
{pares_html}
  </div>
  <p class="legenda">Mesma seed e mesmos primários: à esquerda, derivados condicionados; à direita,
  sorteados sem olhar elemento nem animal.</p>

  <h3>DESENVOLVIMENTO</h3>
  <h4>Como as tabelas funcionam</h4>
  <div class="fluxo">
    <div class="passo"><b>SEED</b>um número</div><div class="seta">›</div>
    <div class="passo"><b>PRIMÁRIOS</b>elemento e animal</div><div class="seta">›</div>
    <div class="passo"><b>TABELAS</b>P(derivado | primários)</div><div class="seta">›</div>
    <div class="passo"><b>CRIATURA</b>porte, cor, traços</div>
  </div>
  <p>Cada atributo derivado tem uma tabela em JSON. Exemplo, a chance de nadadeiras:</p>
  <div class="formula">P(nadadeiras | peixe, água) = 0,92 + 0,20 → 0,98<br>
  P(nadadeiras | peixe, fogo) = 0,92 − 0,15 = 0,77</div>
  <img class="grafico" src="gerado/{graficos["tabela"]}">
  <p class="legenda">P(nadadeiras | animal, elemento): base do animal mais o ajuste do elemento.</p>
  <p>Na versão 2, os traços são sorteados em cadeia (asa reduz a chance de nadadeira), o porte
  depende também do animal e todos os 64 pares elemento×animal aparecem em toda seed.
  <b>Sem busca e sem rejeição:</b> o custo é linear.</p>
  <h4>Arquitetura</h4>
  <div class="camadas">
    <div class="camada seed">SEED DO MUNDO</div>
    <div class="camada"><b>1. Núcleo autoral</b>mapa, NPCs, diálogos, guardiões (fixo)</div>
    <div class="camada gerada"><b>2. Gerador de criaturas</b>tabelas condicionadas → 100 criaturas</div>
    <div class="camada gerada"><b>3. Ambientação</b>vegetação e achados conforme o bestiário</div>
    <div class="camada"><b>4. Apresentação</b>exploração, captura, pesca e batalha leem as criaturas</div>
  </div>
  <p style="font-size:24pt">Godot 4.7 e GDScript · tabelas em JSON · arte e som gerados por
  scripts próprios · 20 testes automatizados · GitHub Actions com <i>gdlint</i>,
  simulador de batalha e builds · publicação no itch.io</p>
</div>

<div class="coluna">
  <h3>RESULTADOS</h3>
  <div class="kpis">
    <div class="kpi"><b>{num(d["ms_por_bestiario"], 1)} ms</b><span>para gerar 100 criaturas</span></div>
    <div class="kpi"><b>64/64</b><span>pares em toda seed (antes: {num(d["cobertura"]["v1"], 0)})</span></div>
    <div class="kpi"><b>{round(min(razoes))}–{round(max(razoes))}×</b><span>mais informação que o sorteio</span></div>
    <div class="kpi"><b>{atip_v2}%</b><span>atípicas, contra {atip_ind}% no sorteio</span></div>
  </div>
  <h4>Informação mútua: o atributo primário explica o derivado?</h4>
  <img class="grafico" src="gerado/{graficos["informacao_mutua"]}">
  <p class="legenda">Média de 10 seeds com 5000 criaturas. No sorteio, fica perto de zero.</p>
  <h4>Cor por elemento</h4>
  <img class="grafico" src="gerado/{graficos["cor"]}">
  <p class="legenda">Matiz por elemento (n = 5000): fogo puxa vermelho; água, azul. No sorteio, tudo igual.</p>
  <h4>Traços por animal (% das criaturas)</h4>
  <img class="grafico" src="gerado/{graficos["tracos"]}">
  <h4>No jogo, o gerador fica à vista</h4>
  <div class="telas">
    <img class="pixel" src="gerado/tela_batalha.png">
    <img class="pixel" src="gerado/tela_bestiario.png">
  </div>
  <p class="legenda">Batalha com a linha SORTEIO e bestiário com a chance de cada atributo (tecla E).
  O corpo decide o combate: garras atacam, escamas defendem.</p>
  <h3>CONCLUSÕES</h3>
  <ul>
    <li>Tabelas condicionadas dão coerência medível sem busca, em milissegundos.</li>
    <li>O corpo da criatura decide combate e captura: o gerador é o núcleo do jogo.</li>
    <li>Próximo passo: validação humana, adivinhando o elemento pelo sprite.</li>
  </ul>
  <h3>REFERÊNCIAS</h3>
  <div class="referencias">
    <p>HENDRIKX, M. et al. Procedural content generation for games: a survey. <b>ACM TOMM</b>, v. 9, n. 1, 2013.</p>
    <p>TOGELIUS, J. et al. Search-based procedural content generation: a taxonomy and survey. <b>IEEE TCIAIG</b>, v. 3, n. 3, 2011.</p>
    <p>SHAKER, N.; TOGELIUS, J.; NELSON, M. J. <b>Procedural Content Generation in Games</b>. Springer, 2016.</p>
    <p>HELLO GAMES. <b>No Man's Sky</b>, 2016. MOJANG. <b>Minecraft</b>, 2011. MOSSMOUTH. <b>Spelunky</b>, 2008.</p>
  </div>
</div>
</main>
<footer><div class="faixa"></div>
<div class="rodape">Portfólio PAC VII/VIII · Católica SC · 2026 · {cfg["url_repositorio"]}</div>
</footer>
<script>
window.addEventListener("load", () => {{
  const alturaUtil = document.querySelector("footer").getBoundingClientRect().top;
  const fundos = [...document.querySelectorAll(".coluna")].map(c => {{
    const filhos = [...c.children]; return filhos[filhos.length - 1].getBoundingClientRect().bottom; }});
  document.body.dataset.medida = JSON.stringify({{rodape: alturaUtil, colunas: fundos}});
}});
</script>
</body></html>'''


def main():
    cfg = ler(os.path.join(AQUI, "config.json"))
    d = ler(os.path.join(POSTER, "dados.json"))
    pecas = ler(os.path.join(RECURSOS, "pecas.json"))
    if not os.path.exists(LOGO):
        sys.exit("falta o logo em " + LOGO)
    preparar_imagens(pecas)
    graficos = {"informacao_mutua": grafico_informacao_mutua(d), "cor": grafico_cor(d),
                "tracos": grafico_tracos(d), "tabela": grafico_tabela(d),
                "surpresa": grafico_surpresa(d)}
    qrs = {"repositorio": qr(cfg["url_repositorio"], os.path.join(GERADO, "qr_repositorio.svg"))}
    if cfg.get("url_jogo"):
        qrs["jogo"] = qr(cfg["url_jogo"], os.path.join(GERADO, "qr_jogo.svg"))
    caminho_html = os.path.join(POSTER, "poster.html")
    with open(caminho_html, "w", encoding="utf-8") as f:
        f.write(html(cfg, d, pecas, graficos, qrs))
    dom = subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--dump-dom",
                          "--window-size=3179,4494", "file://" + caminho_html],
                         capture_output=True, text=True).stdout
    import html as html_mod
    import re
    m = re.search(r'data-medida="([^"]+)"', dom)
    if m:
        medida = json.loads(html_mod.unescape(m.group(1)))
        px_mm = 3179 / 841
        print("colunas terminam em %s mm; o rodape comeca em %.0f mm" % (
            [round(c / px_mm) for c in medida["colunas"]], medida["rodape"] / px_mm))
    pdf = os.path.join(POSTER, "poster.pdf")
    subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--no-pdf-header-footer",
                    "--print-to-pdf=" + pdf, "file://" + caminho_html],
                   check=True, capture_output=True)
    previa = os.path.join(POSTER, "poster_previa")
    subprocess.run(["pdftoppm", "-r", "30", "-png", "-singlefile", pdf, previa], check=True)
    # PNG para impressao ou envio digital: 150 dpi em A0 (4967 x 7022 px).
    subprocess.run(["pdftoppm", "-r", "150", "-png", "-singlefile", pdf,
                    os.path.join(GERADO, "poster_150dpi")], check=True)
    paginas = subprocess.run(["pdfinfo", pdf], capture_output=True, text=True).stdout
    print("ok  %s\n%s" % (pdf, "\n".join(l for l in paginas.splitlines()
                                          if l.startswith(("Pages", "Page size")))))


if __name__ == "__main__":
    main()
