#!/usr/bin/env python3
"""
gerar_fabrica.py — o interior da fabrica do Distrito da Chamine.

Uma sala so: chao de calcamento, borda de rocha, pocas d'agua no chao (goteira de
um telhado que ninguem conserta), maquinas paradas, barris e caixas. O Otavio
espera no meio: e o segundo guardiao (autoral/guardioes/guardioes.json).

Mesmo formato e mesma classe do mundo (mundo_mapa.Mapa), entao o jogo carrega com
o mesmo MundoIso. O que muda e a chave "portas": de onde se entra, para onde se vai
e o que precisa para passar. A porta de saida fica na borda de baixo; a de entrada,
na calcada em frente a fabrica, no mapa do mundo (gerar_mundo.py).

Regerar:  python3 tools/mapas/gerar_fabrica.py
"""

import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from mundo_mapa import Mapa  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(AQUI))
DESTINO = os.path.join(RAIZ, "autoral", "mapas", "fabrica.json")
CAMINHO_NPCS = os.path.join(RAIZ, "autoral", "npcs", "npcs.json")

LARGURA, PROFUNDIDADE = 15, 13
SAIDA = (7, 12)            # vao na borda de baixo: pisar aqui volta para o mundo
CHEGADA = (7, 11)          # onde o jogador aparece ao entrar
# Celula do mundo em frente a porta da fabrica (prop 'fabrica' em [64,55], 3x3)
PORTA_NO_MUNDO = (65, 58)
VOLTA_NO_MUNDO = (65, 59)

POCAS = [(3, 3), (4, 3), (3, 4), (10, 4), (11, 4), (11, 5), (4, 8), (5, 8), (5, 9),
         (10, 9), (11, 9), (10, 8)]


def main():
    m = Mapa(LARGURA, PROFUNDIDADE)
    m.retangulo(0, 0, LARGURA - 1, PROFUNDIDADE - 1, "r")
    m.retangulo(1, 1, LARGURA - 2, PROFUNDIDADE - 2, "k")
    m.pintar(*SAIDA, "k")
    for p in POCAS:
        m.pintar(*p, "a")
    m.spawn = CHEGADA

    for prop, celula in (("maquinario", (2, 6)), ("maquinario", (12, 6)),
                         ("maquinario", (2, 10)), ("barril", (1, 1)), ("barril", (13, 1)),
                         ("barril_agua", (12, 10)), ("caixa", (2, 1)), ("caixa", (12, 1)),
                         ("caixa", (1, 2)), ("caixa", (13, 11))):
        m.por_prop("decoracao", prop, *celula)

    m.regiao("fabrica", "Fábrica Velha", (1, 1, LARGURA - 2, PROFUNDIDADE - 1),
             descricao="Três turnos, uma sirene e agora só goteira.",
             icone="chamine", cor="#8e8c8a")

    with open(CAMINHO_NPCS, encoding="utf-8") as f:
        npcs = [n for n in json.load(f)["npcs"] if n.get("mapa") == "fabrica"]
    erros, alcancaveis = m.validar(npcs)
    if SAIDA not in m.alcancaveis(CHEGADA):
        erros.append("a saida nao e alcancavel a partir da chegada")

    dados = m.para_dicionario(
        descricao="Interior da fabrica do Distrito da Chamine. Camada 1 — fixo.",
        gerado_por="tools/mapas/gerar_fabrica.py")
    dados["id"] = "fabrica"
    dados["mundo_aberto"] = False
    dados["portas"] = [{
        "celula": list(SAIDA), "destino": "mundo", "chegada": list(VOLTA_NO_MUNDO),
        "direcao": "baixo",
    }]
    with open(DESTINO, "w", encoding="utf-8") as f:
        json.dump(dados, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(f"ok  {DESTINO}  ({LARGURA}x{PROFUNDIDADE}, alcancaveis={alcancaveis})")
    if erros:
        print("    validacao: FALHOU")
        for e in erros:
            print("      - " + e)
        sys.exit(1)
    print("    validacao: OK")


if __name__ == "__main__":
    main()
