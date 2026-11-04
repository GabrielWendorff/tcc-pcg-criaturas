# Camada 1 — Núcleo Autoral (fixo)

Conteúdo escrito à mão, **não muda entre partidas** nem depende da seed.
Princípio adotado de Spelunky (templates autorais + aleatoriedade controlada).

```
autoral/
├── mapas/mundo.json      o mundo inteiro: 4 regiões numa grade 96×88
├── npcs/npcs.json        quem mora onde, com que arte e que árvore de diálogo
│   ├── <id>_1x.png       folha de caminhada (4 direções × 4 quadros)
│   └── retratos/*.png    busto 32×32 para a caixa de diálogo
├── dialogos/<id>.json    uma árvore por personagem (+ anselmo_tutorial: falas da lição)
├── guardioes/guardioes.json  guardiões: NPC, selo e regra (a equipe vem da seed)
├── tutoriais/<id>.json   tutoriais como sequência de passos (pesca.json: a lição do Anselmo)
├── protagonista*.png     folha do personagem jogável
├── gerar_protagonista.py desenha a folha do protagonista, pixel a pixel
└── gerar_npcs.py         deriva as folhas e os retratos dos NPCs
```

> A aleatoriedade da seed atua nas camadas 2 e 3 (`procedural/`), nunca aqui. A exceção
> declarada é a equipe do guardião: o guardião é fixo, e as criaturas dele são lidas do
> bestiário (`docs/mudancas-estruturais.md`, 2026-11-03).

## O mapa é saída de ferramenta

`autoral/mapas/mundo.json` **não se edita à mão** — edite
`tools/mapas/regioes/<região>.py` e rode `python3 tools/mapas/gerar_mundo.py`.

O compilador é uma **ferramenta de autoria** — o equivalente, neste projeto, a um
editor de fases —, não um gerador procedural: não recebe seed, produz o mesmo
arquivo byte a byte a cada execução, e existe porque compor à mão uma grade de
96×88 com rio de contorno orgânico e ~1.700 props sem sobreposição é trabalho
mecânico e propenso a erro.

Ele também **valida**, e falha em vez de gerar um mundo quebrado:

- construção sem nenhuma célula vizinha acessível;
- zona de encontro comida pela água, por uma estrada ou pela borda;
- **região inteiramente inalcançável a pé** desde o spawn (é o critério de mundo
  contínuo: sem isso, duas regiões poderiam ficar separadas por um rio sem ponte
  e só se descobriria jogando);
- **NPC dentro de um prop ou inalcançável** — as fichas de `npcs/npcs.json` são
  conferidas contra o mapa na hora de compilá-lo.

## Os NPCs são dado, não código

Não há script por personagem: `presentation/exploracao/npc.gd` é genérico e se
configura pela ficha; o comportamento específico mora na árvore de diálogo, que
também é dado. Acrescentar um NPC é acrescentar uma entrada em `npcs/npcs.json` e
um arquivo em `dialogos/`.

O formato das árvores, as condições, os efeitos e os ganchos de loja/missão estão
documentados em `presentation/dialogo/README.md`.

## Tutoriais são dado, não código

`tutoriais/<id>.json` descreve uma lição como **sequência de passos**: que
conversa abrir, que dica mostrar no topo da tela, que evento esperar (equipar um
item, lançar a linha, fisgar) e o que entregar ao jogador. As falas ficam numa
árvore de diálogo comum (`dialogos/anselmo_tutorial.json`, nós em `entradas`), e
os textos de interface ("[P] pular lição", "Tem certeza?") no próprio JSON do
tutorial — os dois arquivos juntos são tudo o que um tradutor precisa abrir.

A primeira conversa com o Anselmo abre a lição por um **início condicional**
(`"inicios"` em `dialogos/anselmo.json`); concluída ou pulada, a bandeira
`tutorial_pesca_concluido` vai para o save e ele passa a oferecer repeti-la.
Executor, formato e validação: `presentation/tutorial/README.md`;
`tools/test_tutorial.gd` confere os passos, a árvore, os itens entregues e cada
glifo.

## A arte dos NPCs reaproveita o protagonista

`gerar_npcs.py` importa `gerar_protagonista.py` e reusa a **mesma geometria**
(torsos, pernas, fases), trocando só a paleta. Um segundo conjunto de desenhos de
24 px produziria personagens que não parecem do mesmo mundo, e qualquer correção
na silhueta teria de ser feita duas vezes.

Duas chaves da paleta carregam a caracterização: as linhas do **boné** (pintadas
com a cor do cabelo dão um personagem sem chapéu; em amarelo-palha, um chapéu de
palha) e as da **mochila**, que num NPC parado leem como avental ou colete.

```bash
python3 autoral/gerar_protagonista.py
python3 autoral/gerar_npcs.py          # folhas + retratos + folha de conferência
```
