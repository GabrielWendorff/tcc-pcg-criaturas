#!/usr/bin/env python3
"""Analise estatistica dos bestiarios exportados pelo Godot (RF08).

A engine so produz os dados; a estatistica e os graficos do artigo moram aqui.

Uso:
    godot --headless -s res://tools/exportar_bestiario.gd -- --n 5000 --out /tmp/b.json
    python3 tools/analise.py /tmp/b.json [mais.json ...] [--csv DIR] [--graficos DIR]

Sem dependencias obrigatorias (stdlib apenas). matplotlib e usado somente com
--graficos e, se ausente, o programa avisa e segue com as tabelas.

NOTA METODOLOGICA — tamanho de amostra
    O bestiario de jogo tem n~100, mas o estimador plug-in de informacao mutua e
    fortemente enviesado para cima nesse regime: com 8 elementos x ~50 combinacoes
    de cor, ha mais celulas que observacoes, e ate dados independentes exibem I>0.
    Para ESTIMAR I use n >= 5000 (o baseline cai para ~0 e a separacao fica nitida);
    para descrever o bestiario JOGAVEL use n=100. Sao dois usos distintos do mesmo
    gerador, e o artigo deve declarar qual n produziu cada numero.
"""
import argparse
import csv
import json
import math
import os
import sys
from collections import Counter

PARES_PRINCIPAIS = [
    "elemento->porte",
    "elemento->paleta",
    "elemento->matiz",
    "elemento->cor",
    "animal->morfologia",
]


# --- carga -----------------------------------------------------------------

def carregar(caminho):
    with open(caminho, encoding="utf-8") as fh:
        return json.load(fh)


def rotulo(dados, caminho):
    meta = dados["_meta"]
    return f"seed={meta['world_seed']} n={meta['n']}"


# --- tabelas ---------------------------------------------------------------

def tabela_moda(dados):
    """Coerencia por moda: observado contra o teto teorico das tabelas."""
    cond = dados.get("condicionado")
    if cond is None:
        return
    m = cond["metricas"]["moda"]
    b = dados["independente"]["metricas"]["moda"]

    print("\n[1] COERENCIA POR MODA")
    print("    O teto e o maximo que as condicionais vigentes permitem, nao 100%.")
    print("    A eficiencia (obs/teto) responde: o gerador amostra fielmente?")
    print(f"    {'dimensao':<12}{'obs':>9}{'teto':>9}{'efic.':>9}{'baseline':>11}")
    for dim in ("porte", "paleta", "matiz", "morfologia", "variante"):
        d = m[dim]
        print(f"    {dim:<12}{d['obs']:>8.1%}{d['teto']:>9.1%}"
              f"{d['razao']:>9.1%}{b[dim]['obs']:>11.1%}")
    print(f"    {'EFICIENCIA GERAL':<12} {m['eficiencia_pct']:>7.1%}")


def tabela_info_mutua(dados):
    """A metrica que testa a hipotese: I(primario; derivado) contra o baseline."""
    cond = dados.get("condicionado")
    if cond is None:
        return
    mi_c = cond["metricas"]["info_mutua"]
    mi_b = dados["independente"]["metricas"]["info_mutua"]

    print("\n[2] INFORMACAO MUTUA I(primario; derivado), em bits")
    print("    H0 (sorteio independente) => I -> 0. U = fracao da incerteza do")
    print("    derivado explicada pelo primario. 'razao' = I_cond / I_base.")
    print(f"    {'par':<22}{'I cond':>9}{'I base':>9}{'razao':>9}{'U':>8}{'H(Y)':>8}")
    for par in mi_c:
        c, b = mi_c[par], mi_b[par]
        razao = c["i_bits"] / b["i_bits"] if b["i_bits"] > 1e-9 else float("inf")
        marca = " *" if par in PARES_PRINCIPAIS else ""
        razao_txt = f"{razao:>8.1f}x" if math.isfinite(razao) else f"{'inf':>9}"
        print(f"    {par:<22}{c['i_bits']:>9.3f}{b['i_bits']:>9.3f}{razao_txt}"
              f"{c['u']:>8.1%}{c['h_y']:>8.3f}{marca}")

    n = dados["_meta"]["n"]
    if n < 2000:
        print(f"\n    ! n={n} e pequeno para estimar I: o valor do baseline acima e")
        print("      majoritariamente VIES do estimador, nao correlacao real.")
        print("      Reexporte com --n 5000 para os numeros do artigo.")


def tabela_unicidade(dados):
    cond = dados.get("condicionado")
    if cond is None:
        return
    u = cond["metricas"]["unicidade"]
    ub = dados["independente"]["metricas"]["unicidade"]
    total = cond["metricas"]["total"]
    print("\n[3] UNICIDADE (distancia de Hamming sobre o vetor de atributos)")
    print(f"    criatura unica <=> d >= k, com k={u['k']} de {u['dimensao']} posicoes")
    print(f"    {'':<22}{'condicionado':>14}{'independente':>14}")
    linhas = [
        ("distintas (cobertura)", f"{u['distintas']}/{total}", f"{ub['distintas']}/{total}"),
        ("isoladas", f"{u['isoladas']}", f"{ub['isoladas']}"),
        ("distancia media", f"{u['dist_media']:.2f}", f"{ub['dist_media']:.2f}"),
        ("duplicatas exatas", f"{u['duplicatas_exatas']}", f"{ub['duplicatas_exatas']}"),
    ]
    for nome, a, b in linhas:
        print(f"    {nome:<22}{a:>14}{b:>14}")
    print("\n    Nota: o baseline tende a MAIS criaturas distintas — descorrelacionar")
    print("    aumenta a dispersao. Unicidade sozinha nao mede qualidade; e a")
    print("    coerencia que distingue variedade de ruido.")


def contingencia(dados, primario, derivado):
    """Tabela P(derivado | primario) observada, para o heatmap do artigo."""
    cond = dados.get("condicionado")
    if cond is None:
        return {}, [], []
    pares = Counter()
    for c in cond["criaturas"]:
        pares[(c[primario], c[derivado])] += 1
    xs = sorted({k[0] for k in pares})
    ys = sorted({k[1] for k in pares})
    tabela = {}
    for x in xs:
        total = sum(pares[(x, y)] for y in ys) or 1
        tabela[x] = {y: pares[(x, y)] / total for y in ys}
    return tabela, xs, ys


def imprimir_contingencia(dados, primario="elemento", derivado="matiz"):
    tabela, xs, ys = contingencia(dados, primario, derivado)
    if not tabela:
        return
    print(f"\n[4] P({derivado} | {primario}) OBSERVADA — condicionado")
    print(f"    {'':<10}" + "".join(f"{y[:6]:>7}" for y in ys))
    for x in xs:
        celulas = "".join(
            (f"{tabela[x][y]:>6.0%} " if tabela[x][y] >= 0.005 else f"{'.':>7}")
            for y in ys
        )
        print(f"    {x:<10}{celulas}")


# --- exportacao ------------------------------------------------------------

def exportar_csv(dados, destino, nome_base):
    os.makedirs(destino, exist_ok=True)
    cond = dados.get("condicionado")
    if cond is None:
        return []
    escritos = []

    caminho = os.path.join(destino, f"{nome_base}_info_mutua.csv")
    with open(caminho, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["par", "i_cond_bits", "i_cond_corrigido", "u_cond",
                    "i_base_bits", "h_y", "n"])
        mi_c = cond["metricas"]["info_mutua"]
        mi_b = dados["independente"]["metricas"]["info_mutua"]
        for par in mi_c:
            c, b = mi_c[par], mi_b[par]
            w.writerow([par, f"{c['i_bits']:.6f}", f"{c['i_corrigido']:.6f}",
                        f"{c['u']:.6f}", f"{b['i_bits']:.6f}", f"{c['h_y']:.6f}",
                        dados["_meta"]["n"]])
    escritos.append(caminho)

    caminho = os.path.join(destino, f"{nome_base}_criaturas.csv")
    with open(caminho, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        features = dados["_meta"]["vocabulario"]["derivados"]["morfologia"]
        w.writerow(["modo", "id", "elemento", "animal_base", "porte", "body_id",
                    "paleta", "matiz"]
                   + features + [f"var_{f}" for f in features])
        for modo in ("condicionado", "independente"):
            for c in dados[modo]["criaturas"]:
                w.writerow(
                    [modo, c["id"], c["elemento"], c["animal_base"],
                     c["porte"], c["body_id"], c["paleta"], c["matiz"]]
                    + [int(bool(c["morfologia"].get(f))) for f in features]
                    + [c["variantes"].get(f, "") for f in features]
                )
    escritos.append(caminho)
    return escritos


def gerar_graficos(dados, destino, nome_base):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("\n! matplotlib nao encontrado — graficos ignorados.", file=sys.stderr)
        return []

    cond = dados.get("condicionado")
    if cond is None:
        return []
    os.makedirs(destino, exist_ok=True)
    escritos = []

    # (a) barras pareadas de informacao mutua
    mi_c = cond["metricas"]["info_mutua"]
    mi_b = dados["independente"]["metricas"]["info_mutua"]
    pares = [p for p in PARES_PRINCIPAIS if p in mi_c]
    fig, ax = plt.subplots(figsize=(7.2, 3.6))
    pos = range(len(pares))
    larg = 0.38
    ax.bar([p - larg / 2 for p in pos], [mi_c[p]["i_bits"] for p in pares],
           larg, label="Condicionado (proposta)", color="#3b6ea5")
    ax.bar([p + larg / 2 for p in pos], [mi_b[p]["i_bits"] for p in pares],
           larg, label="Independente (H0)", color="#b0b6c0")
    ax.set_xticks(list(pos))
    ax.set_xticklabels([p.replace("->", "→") for p in pares], fontsize=8)
    ax.set_ylabel("I(primario; derivado)  [bits]")
    ax.set_title(f"Informacao mutua — {rotulo(dados, '')}", fontsize=10)
    ax.legend(fontsize=8, frameon=False)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    caminho = os.path.join(destino, f"{nome_base}_info_mutua.png")
    fig.savefig(caminho, dpi=200)
    plt.close(fig)
    escritos.append(caminho)

    # (b) heatmap da contingencia P(matiz|elemento)
    tabela, xs, ys = contingencia(dados, "elemento", "matiz")
    if tabela:
        matriz = [[tabela[x][y] for y in ys] for x in xs]
        fig, ax = plt.subplots(figsize=(7.2, 3.8))
        im = ax.imshow(matriz, cmap="viridis", aspect="auto", vmin=0)
        ax.set_xticks(range(len(ys)), ys, rotation=45, ha="right", fontsize=8)
        ax.set_yticks(range(len(xs)), xs, fontsize=8)
        ax.set_title("P(matiz | elemento) observada — condicionado", fontsize=10)
        fig.colorbar(im, ax=ax, shrink=0.85)
        fig.tight_layout()
        caminho = os.path.join(destino, f"{nome_base}_contingencia.png")
        fig.savefig(caminho, dpi=200)
        plt.close(fig)
        escritos.append(caminho)

    return escritos


# --- main ------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("arquivos", nargs="+", help="JSON(s) de tools/exportar_bestiario.gd")
    ap.add_argument("--csv", metavar="DIR", help="exporta tabelas em CSV neste diretorio")
    ap.add_argument("--graficos", metavar="DIR", help="gera as figuras do artigo (PNG)")
    args = ap.parse_args()

    for caminho in args.arquivos:
        dados = carregar(caminho)
        nome_base = os.path.splitext(os.path.basename(caminho))[0]
        print("=" * 72)
        print(f"BESTIARIO: {caminho}   ({rotulo(dados, caminho)})")
        print("=" * 72)
        tabela_moda(dados)
        tabela_info_mutua(dados)
        tabela_unicidade(dados)
        imprimir_contingencia(dados)
        for saida in (exportar_csv(dados, args.csv, nome_base) if args.csv else []):
            print(f"\n  CSV: {saida}")
        for saida in (gerar_graficos(dados, args.graficos, nome_base) if args.graficos else []):
            print(f"  PNG: {saida}")
        print()


if __name__ == "__main__":
    main()
