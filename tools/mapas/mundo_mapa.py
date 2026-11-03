#!/usr/bin/env python3
r"""
mundo_mapa.py — a grade do mundo e as ferramentas de autoria que operam sobre ela.

ISTO NAO E UM GERADOR PROCEDURAL. E o motor de uma FERRAMENTA DE AUTORIA — o
equivalente, neste projeto, a um editor de fases. O mundo e conteudo da Camada 1
(autoral): nao depende da world_seed, nao muda entre partidas e o jogo em nenhum
momento o sorteia. O unico "acaso" e `ruido()`, um hash de (x, y) sem estado:
rodar duas vezes produz o MESMO arquivo byte a byte.

O arquivo existe porque o mundo passou de uma vila de 40x36 para quatro regioes
contiguas, e um unico script linear de 500 linhas deixou de caber na cabeca de
quem edita. Aqui ficam as OPERACOES (pintar terreno, encaixar casa, registrar
regiao); em regioes/ fica o CONTEUDO, um arquivo por lugar.

Acrescentar uma regiao nova:
    1. crie tools/mapas/regioes/<nome>.py com REGIAO = {...} e construir(m)
    2. importe-o na lista REGIOES de gerar_mundo.py
Nada mais precisa mudar: o JSON, o gatilho de visita em jogo, o mapa geral (M) e
a validacao leem a lista de regioes que sair daqui.
"""

import json
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, os.path.join(RAIZ, "tools", "arte"))

from mundo_lib import ruido  # noqa: E402

# Um caractere por terreno. Os nomes tem que bater com as linhas do atlas
# (arte/mundo/atlas_terreno.json) e com a legenda lida por MundoIso.
LEGENDA = {
    ".": "grama",
    "c": "caminho",
    "t": "terra",
    "s": "areia",
    "a": "agua",
    "r": "rocha",
    "g": "grama_alta",
    "k": "calcada",
    "l": "lavoura",
    "p": "ponte",
}
BLOQUEIA = ("a", "r")          # terrenos que o jogador nao atravessa

# Terrenos sobre os quais NAO se espalha vegetacao nem pedra solta: sao chao
# construido ou cultivado, e um pinheiro no meio da calcada desmente a regiao.
CONSTRUIDO = ("k", "l", "p", "c")

CATEGORIAS = ("casas", "arvores", "pedras", "penhascos", "decoracao")


class Mapa:
    """Grade de terreno + listas de props, regioes e pontos de encontro."""

    def __init__(self, largura, profundidade, celula=(32, 16)):
        self.largura = largura
        self.profundidade = profundidade
        self.celula = list(celula)
        self.grade = [["." for _ in range(largura)] for _ in range(profundidade)]
        self.casas = []
        self.arvores = []
        self.pedras = []
        self.penhascos = []
        self.decoracao = []
        self.pontos = []
        self.regioes = []
        self.spawn = (0, 0)
        self._ocupado = set()
        self._tamanhos = {}

    # -------------------------------------------------------------- terreno
    def dentro(self, gx, gy):
        return 0 <= gx < self.largura and 0 <= gy < self.profundidade

    def ler(self, gx, gy):
        return self.grade[gy][gx] if self.dentro(gx, gy) else "r"

    def pintar(self, gx, gy, ch):
        if self.dentro(gx, gy):
            self.grade[gy][gx] = ch

    def retangulo(self, x0, y0, x1, y1, ch, so_sobre=None):
        for gy in range(int(y0), int(y1) + 1):
            for gx in range(int(x0), int(x1) + 1):
                if so_sobre is None or self.ler(gx, gy) in so_sobre:
                    self.pintar(gx, gy, ch)

    def disco(self, cx, cy, raio, ch, deformacao=0.0, fase=0.0, so_sobre=None):
        """Mancha aproximadamente circular. `deformacao` soma harmonicos ao raio:
        e o que tira do lago o ar de circulo perfeito sem contorno a mao.

        Um circulo na GRADE aparece na tela como elipse 2:1 — que e exatamente
        como uma poca redonda no chao se projeta em vista isometrica. Deformar na
        grade, e nao na tela, mantem essa leitura.
        """
        r_max = int(math.ceil(raio * (1.0 + deformacao))) + 1
        pintadas = []
        for gy in range(int(cy - r_max), int(cy + r_max) + 1):
            for gx in range(int(cx - r_max), int(cx + r_max) + 1):
                dx, dy = gx - cx, gy - cy
                d = math.hypot(dx, dy)
                if d < 1e-6:
                    r = raio
                else:
                    ang = math.atan2(dy, dx) + fase
                    r = raio * (1.0 + deformacao * (
                        0.55 * math.sin(3 * ang + 0.7)
                        + 0.30 * math.sin(5 * ang + 2.1)
                        + 0.15 * math.sin(7 * ang + 4.4)))
                if d <= r and (so_sobre is None or self.ler(gx, gy) in so_sobre):
                    self.pintar(gx, gy, ch)
                    pintadas.append((gx, gy))
        return pintadas

    def faixa(self, p0, p1, largura, ch, so_sobre=None):
        """Caminho de p0 a p1 com espessura `largura` em celulas."""
        x0, y0 = p0
        x1, y1 = p1
        passos = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
        meia = largura / 2.0
        pintadas = []
        for i in range(passos + 1):
            t = i / passos
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for gy in range(int(cy - meia - 1), int(cy + meia + 2)):
                for gx in range(int(cx - meia - 1), int(cx + meia + 2)):
                    if math.hypot(gx - cx, gy - cy) <= meia:
                        if so_sobre is None or self.ler(gx, gy) in so_sobre:
                            self.pintar(gx, gy, ch)
                            pintadas.append((gx, gy))
        return pintadas

    def curva(self, pontos, largura, ch, so_sobre=None, ruido_largura=0.0,
              semente=0):
        """Faixa por uma POLILINHA, com a largura variando ao longo dela.

        E o que separa um rio de um cano: largura constante em linha reta le
        como obra de engenharia. A variacao vem de `ruido`, nao de sorteio — o
        mesmo rio sai igual a cada execucao.
        """
        pintadas = []
        for i in range(len(pontos) - 1):
            a, b = pontos[i], pontos[i + 1]
            passos = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) * 3) + 1
            for k in range(passos + 1):
                t = k / passos
                cx = a[0] + (b[0] - a[0]) * t
                cy = a[1] + (b[1] - a[1]) * t
                larg = largura
                if ruido_largura:
                    larg += ruido_largura * (ruido(int(cx), int(cy), semente) - 0.5) * 2
                meia = max(0.6, larg / 2.0)
                for gy in range(int(cy - meia - 1), int(cy + meia + 2)):
                    for gx in range(int(cx - meia - 1), int(cx + meia + 2)):
                        if math.hypot(gx - cx, gy - cy) <= meia:
                            if so_sobre is None or self.ler(gx, gy) in so_sobre:
                                self.pintar(gx, gy, ch)
                                pintadas.append((gx, gy))
        return pintadas

    def anel(self, ch_de, ch_para, espessura=1, so_sobre=(".",)):
        """Pinta de `ch_para` toda celula que faz fronteira com `ch_de`.

        E assim que a praia nasce em volta da agua: como consequencia do contorno
        do lago, e nao como uma segunda forma desenhada a mao que teria de ser
        reajustada toda vez que o lago mudasse.
        """
        for _ in range(espessura):
            novas = []
            for gy in range(self.profundidade):
                for gx in range(self.largura):
                    if self.ler(gx, gy) not in so_sobre:
                        continue
                    if any(self.ler(gx + dx, gy + dy) == ch_de
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        novas.append((gx, gy))
            for gx, gy in novas:
                self.pintar(gx, gy, ch_para)
            ch_de = ch_para

    # ---------------------------------------------------------------- props
    def tamanho(self, prop):
        if not self._tamanhos:
            caminho = os.path.join(RAIZ, "arte", "mundo", "props.json")
            with open(caminho, encoding="utf-8") as f:
                for nome, meta in json.load(f)["props"].items():
                    self._tamanhos[nome] = tuple(meta["celulas"])
        return self._tamanhos.get(prop, (1, 1))

    def livre(self, gx, gy, W=1, D=1, exigir=(".",)):
        for dy in range(D):
            for dx in range(W):
                c = (gx + dx, gy + dy)
                if not self.dentro(*c) or c in self._ocupado:
                    return False
                if exigir is not None and self.ler(*c) not in exigir:
                    return False
        return True

    def ocupar(self, gx, gy, W=1, D=1):
        for dy in range(D):
            for dx in range(W):
                self._ocupado.add((gx + dx, gy + dy))

    def por_prop(self, categoria, prop, gx, gy, **extra):
        W, D = self.tamanho(prop)
        item = {"prop": prop, "celula": [gx, gy]}
        item.update(extra)
        getattr(self, categoria).append(item)
        self.ocupar(gx, gy, W, D)
        return item

    def acessos(self, gx, gy, W, D, chao=("c", "t", "k")):
        """Quantas celulas da cintura da construcao dao para chao de circulacao.

        Uma casa tem que ter FRENTE para alguma coisa. Sem esta conta, a busca de
        encaixe poe a casa no primeiro buraco de grama que couber, e o resultado
        e um casario disperso pelo mato em vez de um nucleo urbano.
        """
        volta = ([(gx + i, gy + D) for i in range(W)]
                 + [(gx + W, gy + j) for j in range(D)]
                 + [(gx + i, gy - 1) for i in range(W)]
                 + [(gx - 1, gy + j) for j in range(D)])
        return sum(1 for c in volta if self.ler(*c) in chao)

    def encaixar(self, nome, prop, gx, gy, raio=6, exigir=(".", "g"),
                 chao=("c", "t", "k")):
        """Posicao valida mais proxima da desejada, preferindo a de melhor frente.

        A busca e DETERMINISTICA e o ajuste e impresso: a intencao continua sendo
        a coordenada escrita na planta da regiao. Existe porque mexer num rio ou
        numa estrada move o terreno debaixo de uma duzia de construcoes ao mesmo
        tempo, e realinhar tudo a mao a cada ajuste torna o mundo impossivel de
        iterar.
        """
        W, D = self.tamanho(prop)
        for r in range(raio + 1):
            candidatos = []
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    if self.livre(gx + dx, gy + dy, W, D, exigir=exigir):
                        candidatos.append((-self.acessos(gx + dx, gy + dy, W, D, chao),
                                           abs(dx) + abs(dy), dx, dy))
            if not candidatos:
                continue
            candidatos.sort()
            _, _, dx, dy = candidatos[0]
            if (dx, dy) != (0, 0):
                print(f"    ajuste: '{nome}' de ({gx},{gy}) para "
                      f"({gx + dx},{gy + dy})")
            return (gx + dx, gy + dy)
        raise SystemExit(
            f"'{nome}': nenhum encaixe {W}x{D} livre a ate {raio} celulas de "
            f"({gx},{gy}). Abra espaco no terreno ou mova a construcao na planta.")

    def construcao(self, nome, prop, gx, gy, papel="", chao="t", raio=6,
                   exigir=(".", "g"), **extra):
        """Encaixa a construcao, bate o chao sob ela e registra o prop."""
        pos = self.encaixar(nome, prop, gx, gy, raio=raio, exigir=exigir)
        W, D = self.tamanho(prop)
        if chao:
            for dy in range(D):
                for dx in range(W):
                    self.pintar(pos[0] + dx, pos[1] + dy, chao)
        return self.por_prop("casas", prop, pos[0], pos[1],
                             id=nome, papel=papel, **extra)

    # ------------------------------------------------- regioes e encontros
    def regiao(self, id, nome, retangulo, descricao="", icone="casa",
               cor="#000000"):
        """Registra uma regiao do mundo.

        O retangulo e a area que o gatilho de visita cobre em jogo E a moldura
        do rotulo no mapa geral (M). As duas coisas saem do MESMO dado de
        proposito: uma regiao que o mapa anuncia num lugar e reconhece em outro
        e pior que nenhuma regiao.
        """
        x0, y0, x1, y1 = retangulo
        self.regioes.append({
            "id": id,
            "nome": nome,
            "descricao": descricao,
            "icone": icone,
            "cor": cor,
            "retangulo": [int(x0), int(y0), int(x1), int(y1)],
        })

    def ponto_de_encontro(self, id_ponto, cx, cy, raio, bioma, elementos,
                          deformacao=0.30):
        """Mancha de grama alta + o marcador da zona de encontro sobre ela."""
        mancha = self.disco(cx, cy, raio, "g", deformacao=deformacao, fase=cx,
                            so_sobre=(".",))
        if len(mancha) < 8:
            raise SystemExit(
                f"area de encontro '{id_ponto}' em ({cx},{cy}) so rendeu "
                f"{len(mancha)} celulas de grama alta — agua, estrada ou borda "
                f"comeram a mancha. Mova a area ou o que a corta.")
        # A celula do marcador sai da mancha REAL, e nao do centro pedido: se o
        # terreno mudar, o ponto acompanha a grama que sobrou em vez de acabar
        # dentro do rio.
        mx = sum(c[0] for c in mancha) / len(mancha)
        my = sum(c[1] for c in mancha) / len(mancha)
        centro = min(mancha, key=lambda c: (c[0] - mx) ** 2 + (c[1] - my) ** 2)
        self.ocupar(*centro)
        self.pontos.append({
            "id": id_ponto,
            "celula": [centro[0], centro[1]],
            "raio_celulas": round(raio, 1),
            "bioma": bioma,
            # Nomes do vocabulario canonico (data/vocabulary.json). A regiao
            # filtra QUEM aparece ali, por rejeicao sobre o bestiario ja gerado —
            # nao muda COMO a criatura e gerada. Ver docs/mudancas-estruturais.md.
            "elementos_provaveis": list(elementos),
            "celulas_de_grama_alta": len(mancha),
            "arbustos_sugeridos": int(raio * 2),
        })
        return centro

    # ------------------------------------------------------------- validacao
    def celulas_solidas(self):
        """Celulas que algum prop COM colisao ocupa. Props sem colisao (flores,
        juncos, plantacao) nao entram: trata-los como solidos fecharia passagens
        que o jogador de fato atravessa."""
        sem_colisao = self._props_sem_colisao()
        solidos = set()
        for categoria in ("arvores", "pedras", "penhascos", "decoracao"):
            for p in getattr(self, categoria):
                if p["prop"] in sem_colisao:
                    continue
                W, D = self.tamanho(p["prop"])
                gx, gy = p["celula"]
                solidos |= {(gx + dx, gy + dy) for dx in range(W) for dy in range(D)}
        for c in self.casas:
            gx, gy = c["celula"]
            W, D = self.tamanho(c["prop"])
            solidos |= {(gx + dx, gy + dy) for dx in range(W) for dy in range(D)}
        return solidos

    def _props_sem_colisao(self):
        caminho = os.path.join(RAIZ, "arte", "mundo", "props.json")
        with open(caminho, encoding="utf-8") as f:
            props = json.load(f)["props"]
        return {nome for nome, meta in props.items()
                if meta.get("colisao", {}).get("tipo", "nenhuma") == "nenhuma"}

    def alcancaveis(self, origem):
        """Inundacao a pe a partir de `origem`, sobre terreno pisavel e livre de
        props solidos."""
        solidos = self.celulas_solidas()
        vistos = {tuple(origem)}
        fila = [tuple(origem)]
        while fila:
            gx, gy = fila.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (gx + dx, gy + dy)
                if p in vistos or not self.dentro(*p):
                    continue
                if self.ler(*p) in BLOQUEIA or p in solidos:
                    continue
                vistos.add(p)
                fila.append(p)
        return vistos

    def validar(self, npcs=()):
        """Erros que tornariam o mundo injogavel. Uma regiao atras de uma parede
        de arvores seria um bug invisivel no JSON."""
        erros = []
        spawn = tuple(self.spawn)
        if self.ler(*spawn) in BLOQUEIA:
            erros.append(f"spawn {spawn} cai em terreno bloqueado")
        if spawn in self.celulas_solidas():
            erros.append(f"spawn {spawn} cai dentro de um prop")

        vistos = self.alcancaveis(spawn)
        for ponto in self.pontos:
            if tuple(ponto["celula"]) not in vistos:
                erros.append(f"ponto de encontro '{ponto['id']}' em "
                             f"{ponto['celula']} nao e alcancavel a pe")
        for c in self.casas:
            gx, gy = c["celula"]
            W, D = self.tamanho(c["prop"])
            vizinhas = ([(gx + dx, gy + D) for dx in range(W)]
                        + [(gx + W, gy + dy) for dy in range(D)]
                        + [(gx + dx, gy - 1) for dx in range(W)]
                        + [(gx - 1, gy + dy) for dy in range(D)])
            if not any(v in vistos for v in vizinhas):
                erros.append(f"construcao '{c.get('id', c['prop'])}' nao tem "
                             f"nenhuma celula vizinha acessivel")
        # TODA regiao precisa ser alcancavel a pe desde o spawn: e o criterio de
        # "mundo continuo" — sem isto, duas regioes vizinhas no JSON poderiam
        # estar separadas por um rio sem ponte, e so se descobriria jogando.
        for r in self.regioes:
            x0, y0, x1, y1 = r["retangulo"]
            if not any((gx, gy) in vistos
                       for gy in range(y0, y1 + 1) for gx in range(x0, x1 + 1)):
                erros.append(f"regiao '{r['id']}' e inteiramente inalcancavel "
                             f"a pe desde o spawn")
        for npc in npcs:
            c = tuple(npc["celula"])
            if c not in vistos:
                erros.append(f"NPC '{npc['id']}' em {list(c)} nao e alcancavel "
                             f"a pe desde o spawn")
            if c in self.celulas_solidas():
                erros.append(f"NPC '{npc['id']}' em {list(c)} esta dentro de um prop")
        return erros, len(vistos)

    # ------------------------------------------------------------------ saida
    def para_dicionario(self, descricao, gerado_por):
        return {
            "_meta": {
                "descricao": descricao,
                "gerado_por": gerado_por,
                "aviso": "Saida de ferramenta. Nao editar a mao — edite o script.",
                "versao": 2,
            },
            "celula": self.celula,
            "dimensoes": {"largura": self.largura,
                          "profundidade": self.profundidade},
            "legenda": LEGENDA,
            "bloqueia": list(BLOQUEIA),
            "spawn_jogador": list(self.spawn),
            "terreno": ["".join(linha) for linha in self.grade],
            "regioes": self.regioes,
            "casas": self.casas,
            "arvores": self.arvores,
            "pedras": self.pedras,
            "penhascos": self.penhascos,
            "decoracao": self.decoracao,
            "pontos_encontro": self.pontos,
        }
