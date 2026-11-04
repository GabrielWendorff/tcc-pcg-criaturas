#!/usr/bin/env python3
"""
ribeira.py — a ribeira e a cabana do pescador.

A regiao NASCE DO LAGO DA VILA: o rio sai da bacia leste, desce o vale e some ao
sul. Isso e deliberado e e o que faz o mundo parecer um lugar so — uma massa de
agua nova, sem origem, leria como outro mapa colado ao lado.

O QUE ESTA REGIAO PREPARA E NAO IMPLEMENTA: a pesca. Ha margem, barranco, juncos,
varal de peixe, bote encalhado e um pescador com o que dizer — nenhuma mecanica.
Quando a pesca existir, ela entra pelo `servico` do dialogo dele
(autoral/dialogos/anselmo.json), sem mudar mapa nem arte.
"""

REGIAO = {
    "id": "ribeira",
    "nome": "Ribeira do Anselmo",
    "descricao": "O rio que desce do lago. Juncos, barranco e uma cabana velha.",
    "icone": "peixe",
    "cor": "#3a84b0",
    "retangulo": (45, 1, 94, 42),
}

# Curso do rio, da boca do lago da vila ate a borda sul do mundo. E a espinha do
# mundo inteiro: separa oeste (vila, fazenda) de leste (ribeira, distrito), e por
# isso as duas pontes de `ligacoes.py` sao as unicas travessias.
CURSO = [(37, 10), (44, 12), (50, 16), (54, 24), (56, 36), (58, 50),
         (57, 64), (54, 76), (50, 88)]


def construir(m):
    m.regiao(**REGIAO)

    # --- o rio ---
    # Largura VARIAVEL por ruido: largura constante em linha reta le como canal
    # de concreto. O leito nao invade calcada nem lavoura (so_sobre) porque ele e
    # pintado antes das outras regioes, mas a guarda deixa a ordem explicita.
    m.curva(CURSO, 3.4, "a", so_sobre=(".", "g", "s", "t", "c"),
            ruido_largura=1.6, semente=5)

    # Remanso: um alargamento onde o rio faz a curva. E onde o pescador
    # trabalha — e a unica parte do rio em que a agua para de correr.
    m.disco(52, 20, 3.2, "a", deformacao=0.35, fase=1.1, so_sobre=(".", "g", "s"))

    # --- praia e barranco ---
    # A areia sai do CONTORNO da agua (anel), nao de uma forma desenhada a mao:
    # mexer no curso do rio reposiciona a margem sozinho.
    m.anel("a", "s", espessura=1, so_sobre=(".", "g"))

    # --- terreiro da cabana, na margem leste do remanso ---
    m.disco(60, 18, 4.2, "t", deformacao=0.22, fase=2.0, so_sobre=(".", "g", "s"))
    m.faixa((57, 19), (66, 22), 1.8, "t", so_sobre=(".", "g", "s"))

    m.construcao("cabana_do_pescador", "cabana", 60, 16, papel="moradia",
                 regiao="ribeira", exigir=(".", "g", "t", "s"))

    # --- narrativa de cenario: o que diz que alguem vive de pescar aqui ---
    for prop, gx, gy in (("varal_peixe", 58, 20), ("barril_agua", 63, 17),
                         ("caixa", 63, 20), ("toco_01", 57, 15),
                         ("placa", 56, 22)):
        if m.livre(gx, gy, exigir=(".", "g", "t", "s")):
            m.por_prop("decoracao", prop, gx, gy)

    # O bote fica ENCALHADO na areia, nao na agua: um barco boiando pediria
    # ancora, corda e sombra sobre a agua, e nenhum deles existe.
    for gx, gy in ((55, 25), (53, 14)):
        if m.livre(gx, gy, 2, 1, exigir=("s",)):
            m.por_prop("decoracao", "barco", gx, gy)

    # Juncos ao longo de toda a margem. Sem colisao (como as flores): o jogador
    # precisa poder encostar no rio, senao a margem vira parede.
    from mundo_lib import ruido
    for gy in range(2, m.profundidade):
        for gx in range(44, min(94, m.largura)):
            if m.ler(gx, gy) != "s" or not m.livre(gx, gy, exigir=("s",)):
                continue
            if ruido(gx, gy, 61) < 0.22:
                m.por_prop("decoracao",
                           "junco_01" if ruido(gx, gy, 62) < 0.5 else "junco_02",
                           gx, gy)

    # --- zonas de encontro da regiao ---
    m.ponto_de_encontro("juncal_do_remanso", 63, 26, 3.0, "juncal",
                        ["agua", "planta"])
    m.ponto_de_encontro("mata_da_ribeira", 72, 12, 3.4, "mata_ribeirinha",
                        ["agua", "sombra"])
    m.ponto_de_encontro("alto_da_ribeira", 82, 30, 3.2, "encosta_umida",
                        ["gelo", "agua"])
