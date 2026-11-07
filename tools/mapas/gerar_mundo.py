#!/usr/bin/env python3
r"""
gerar_mundo.py — compilador do mapa autoral do mundo.

Saida: autoral/mapas/mundo.json

ISTO NAO E UM GERADOR PROCEDURAL. E uma FERRAMENTA DE AUTORIA — o equivalente,
neste projeto, a um editor de fases. O mundo e conteudo da Camada 1 (autoral):
nao depende da world_seed, nao muda entre partidas e o jogo em nenhum momento o
sorteia. Rodar duas vezes produz o MESMO arquivo byte a byte; mexer no mundo e
mexer nestes scripts. A geracao por seed continua exclusiva de procedural/, que
e onde as metricas de RF04/RF08 a medem.

UM MAPA SO, e nao um por regiao. As quatro regioes sao contiguas na MESMA grade
porque o requisito e um mundo continuo: o jogador atravessa de uma a outra
andando, sem carregamento e sem corte. MundoIso nao mudou de forma para receber
isto — continua lendo um JSON e montando um TileMapLayer.

Regerar:  python3 tools/mapas/gerar_mundo.py
Nunca editar o JSON a mao — ele e saida.

    Vila do Poço ──estrada leste──▶ Ribeira ──margem──▶ Distrito da Chaminé
         │                                                      ▲
         └──estrada sul──▶ Sítio da Dulce ──ponte do sítio──────┘
"""

import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join(RAIZ, "tools", "arte"))

from mundo_lib import ruido            # noqa: E402
from mundo_mapa import LEGENDA, Mapa   # noqa: E402
from regioes import fazenda, industrial, ligacoes, ribeira, vila  # noqa: E402

LARGURA, PROFUNDIDADE = 96, 88

# A ORDEM E O DESENHO. Cada regiao pinta sobre o que ficou antes, e `livre()` ja
# considera o que as anteriores ocuparam. A vila vem primeiro porque o lago dela
# e a nascente do rio da ribeira; ligacoes.py vem por ultimo porque so faz
# sentido costurar o que ja existe.
REGIOES = [vila, ribeira, industrial, fazenda]

CAMINHO_NPCS = os.path.join(RAIZ, "autoral", "npcs", "npcs.json")


def _praia_irregular(m):
    """Terceira faixa de areia, so em parte do contorno.

    Margem de largura constante em toda a volta e a marca de forma obtida por
    dilatacao — o recorte irregular e o que faz a praia parecer erodida. So
    avanca sobre grama comum, entao nunca come uma zona de encontro, uma estrada
    ou um talhao.
    """
    for gy in range(m.profundidade):
        for gx in range(m.largura):
            if m.ler(gx, gy) == "." and ruido(gx, gy, 7) < 0.45 and any(
                    m.ler(gx + dx, gy + dy) == "s"
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                m.pintar(gx, gy, "s")


def _npcs_declarados():
    """Fichas de NPC, so para VALIDAR posicao. O mapa nao carrega NPC: quem os
    instancia e GerenciadorDialogo, a partir do mesmo arquivo. Duplicar a lista
    no mapa criaria duas verdades sobre onde cada um esta."""
    if not os.path.exists(CAMINHO_NPCS):
        return []
    with open(CAMINHO_NPCS, encoding="utf-8") as f:
        # So os NPCs DESTE mapa: quem mora num interior e validado pelo gerador dele.
        return [n for n in json.load(f).get("npcs", []) if n.get("mapa", "mundo") == "mundo"]


def _validar_chegada(m):
    """A coreografia da chegada so funciona se o caminho do onibus e as celulas
    onde o jogador desce e a Mirela para forem chao livre. Mexer na vila e
    quebrar isso falha aqui, e nao na tela."""
    c = vila.CHEGADA
    y = int(c["boca"][1])
    for gx in range(int(c["boca"][0]), int(c["parada"][0] + 2)):
        for gy in (y - 1, y, y + 1):
            if (gx, gy) in m._ocupado or m.ler(gx, gy) in ("a", "r"):
                raise SystemExit(f"chegada: ({gx},{gy}) bloqueia o caminho do onibus")
    for nome in ("desembarque", "encontro"):
        gx, gy = c[nome]
        if (gx, gy) in m._ocupado or m.ler(gx, gy) in ("a", "r"):
            raise SystemExit(f"chegada: '{nome}' em ({gx},{gy}) nao e chao livre")
    for gx, gy in c["caminho_mirela"]:
        if (gx, gy) in m._ocupado or m.ler(gx, gy) in ("a", "r"):
            raise SystemExit(f"chegada: caminho da Mirela passa por ({gx},{gy}), bloqueado")
    for (ax, ay), (bx, by) in zip(c["caminho_mirela"], c["caminho_mirela"][1:]):
        if ax != bx and ay != by:
            raise SystemExit("chegada: trechos do caminho da Mirela devem ser retos")
        for gx in range(min(ax, bx), max(ax, bx) + 1):
            for gy in range(min(ay, by), max(ay, by) + 1):
                if (gx, gy) in m._ocupado:
                    raise SystemExit(f"chegada: ({gx},{gy}) bloqueia a Mirela")
    if c["caminho_mirela"][-1] != c["encontro"]:
        raise SystemExit("chegada: o caminho da Mirela tem de terminar no 'encontro'")
    return dict(c)


def main():
    m = Mapa(LARGURA, PROFUNDIDADE)
    for modulo in REGIOES:
        print(f"  regiao: {modulo.REGIAO['nome']}")
        modulo.construir(m)
    _praia_irregular(m)
    print("  ligacoes: estradas, pontes, transicoes e borda do mundo")
    ligacoes.construir(m)

    npcs = _npcs_declarados()
    erros, alcancaveis = m.validar(npcs)

    dados = m.para_dicionario(
        descricao="Mundo autoral: vila inicial, ribeira, distrito industrial e "
                  "fazenda numa grade continua. Camada 1 — fixo, independente da "
                  "world_seed.",
        gerado_por="tools/mapas/gerar_mundo.py")
    dados["id"] = "mundo"
    dados["mundo_aberto"] = True
    # Portas para interiores. A da fabrica so abre com o selo da Dulce: e o que
    # garante a ordem dos guardioes (o Otavio espera la dentro).
    dados["portas"] = [{
        "celula": [65, 58], "destino": "fabrica", "chegada": [7, 11], "direcao": "cima",
        "requer": "selo_dulce",
        "aviso": "O portão está trancado. Um bilhete preso nele: \"Só entra quem traz o selo do sítio. — Otávio\"",
    }]

    dados["chegada"] = _validar_chegada(m)

    destino = os.path.join(RAIZ, "autoral", "mapas", "mundo.json")
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8") as f:
        json.dump(dados, f, indent=1, ensure_ascii=False)
        f.write("\n")

    conta = {}
    for linha in m.grade:
        for ch in linha:
            conta[ch] = conta.get(ch, 0) + 1
    pisavel = sum(n for ch, n in conta.items() if ch not in ("a", "r"))
    print(f"\nok  {destino}")
    print(f"    grade {LARGURA}x{PROFUNDIDADE} = {LARGURA * PROFUNDIDADE} celulas")
    print("    terreno: " + "  ".join(
        f"{LEGENDA[ch]}={n}" for ch, n in sorted(conta.items())))
    print(f"    regioes={len(m.regioes)}  casas={len(m.casas)}  "
          f"arvores={len(m.arvores)}  pedras={len(m.pedras)}  "
          f"penhascos={len(m.penhascos)}  decoracao={len(m.decoracao)}  "
          f"pontos_encontro={len(m.pontos)}")
    print(f"    pisavel={pisavel}  alcancavel a pe desde o spawn={alcancaveis} "
          f"({100.0 * alcancaveis / max(1, pisavel):.1f}%)")
    for r in m.regioes:
        x0, y0, x1, y1 = r["retangulo"]
        dentro = sum(1 for p in m.pontos
                     if x0 <= p["celula"][0] <= x1 and y0 <= p["celula"][1] <= y1)
        print(f"      {r['id']:12s} {x1 - x0 + 1:3d}x{y1 - y0 + 1:<3d} "
              f"zonas de encontro={dentro}")
    if erros:
        for e in erros:
            print("FALHOU: " + e)
        raise SystemExit(1)
    print("    validacao: OK")


if __name__ == "__main__":
    main()
