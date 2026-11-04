# Equipamento — o item na mão e a roda de itens

O jogador segura **um** item por vez. Ele aparece na mão, acompanha a direção
encarada e passa atrás ou na frente do corpo conforme o lado. A troca é feita
pela roda radial: segurar **Q**, apontar com o mouse, soltar.

```bash
godot --headless --path . -s res://tools/test_equipamento.gd   # geometria, poses, itens, save, input, nós
python3 tools/arte/gerar_itens.py                              # regera os ícones (arte/itens/)
```

```
Jogador (CharacterBody2D)
├── Corpo        CollisionShape2D
├── SlotDaMao    Marker2D      ← aqui quando olha para cima (atrás do corpo)
├── Sprite       AnimatedSprite2D
└── SlotDaMao    Marker2D      ← aqui nas outras três direções (na frente)
    └── ItemNaMao  Node2D      um só, reconfigurado a cada troca
        └── Arte   Sprite2D | cena   só quando o item declara arte final

RodaItens (CanvasLayer 88)     montada pela cena do mundo, não pelo jogador
└── Desenho  Control           _draw: anel, medalhões, miolo, textos
```

## Ordem de filho, não `z_index`

O item tem de ficar **atrás** do corpo quando o jogador olha para cima (a mão
está do outro lado) e **na frente** nas outras direções. O caminho óbvio seria
`z_index = -1 / +1` no slot, e é o errado aqui:

- o `Jogador` vive no container y-sorted `Entidades`, junto com árvores, casas e
  NPCs (ver `presentation/exploracao/README.md`);
- `z_index` é **global** ao canvas, e o y-sort só ordena irmãos de **mesmo** z;
- com `z = +1` a vara seria desenhada por cima da árvore que está **na frente**
  do jogador; com `z = -1` ela sumiria embaixo do chão.

Dentro do `Jogador` os filhos são desenhados na ordem da árvore, e o `Jogador`
inteiro continua sendo **um** item do y-sort. Então `"atras": true` move o
`SlotDaMao` para **antes** do nó `Sprite`; `false`, para **depois**
(`SlotDaMao._ordenar`). Nenhum `z_index` é tocado — o teste confere.

## Trocar de item não recria nada

`Jogador.equipar(item)` → `SlotDaMao.equipar(item)` → `ItemNaMao.configurar(item)`.
O slot e o nó de desenho são os **mesmos** do nascimento do jogador até o fim;
só o conteúdo muda. Quem guardou uma referência ao slot — a pesca, para tirar
a ponta da vara a cada quadro — continua válido depois da troca.

`equipar(null)` = mãos livres. Item sem o marcador `equipamento` é recusado
(com aviso): a roda só oferece equipáveis, mas o save é editável à mão.

`equipar()` funciona **antes** do `_ready`: a cena repõe o save logo depois de
criar o jogador, quando a mão ainda não existe. O item fica guardado e a mão o
recebe ao ser montada.

## Dados do item

Tudo em `data/itens/catalogo.json`, no próprio item — sem arquivo paralelo:

```json
{
  "id": "vara_de_pesca",
  "marcadores": ["pesca", "equipamento"],
  "mao": {"forma": "vara", "comprimento": 18.0, "cor": "8a5a3c"},
  "uso": "pescar"
}
```

| campo | o quê |
|---|---|
| marcador `equipamento` | vai para a mão e aparece na roda (`ItemJogo.equipavel()`) |
| `mao.forma` | placeholder: `vara` · `lanterna` · `pa` · `icone` (forma desconhecida cai em `icone`) |
| `mao.comprimento` | em pixels do mundo; a ponta da vara é `(0, -comprimento)` |
| `mao.cor` | cor principal do placeholder, `rrggbb` |
| `mao.escala` | só para `icone`; padrão 0.5 do ícone da bolsa |
| `mao.textura` / `mao.cena` | arte final — ver abaixo |
| `uso` | o que **F** faz com o item na mão. `"pescar"` = a pesca; `""` = só troca o sprite |

`uso` é texto, não enum, pelo mesmo motivo dos marcadores: o catálogo não pode
conhecer a pesca. Um uso novo é uma string nova no JSON e um consumidor novo
(que pergunta `item_atual().uso == "..."`), sem mexer em `ItemJogo`.

Item equipável **sem** `mao` aparece como o próprio ícone da bolsa, pequeno.
Marcar qualquer item como equipamento funciona antes de alguém desenhá-lo.

### Itens de exemplo

`lanterna` e `pa_de_jardim` (categoria `ferramentas`, permanentes, um de cada no
início) existem para a roda ter mais de um slot e para provar que a troca de
sprite funciona sem a pesca. `uso: ""` — por ora só mudam o que está na mão.

## Trocar o placeholder pela arte final

Uma linha no JSON, nenhuma em GDScript. O placeholder continua declarado como
reserva; a arte que chegar passa na frente dele.

```json
"mao": {"forma": "vara", "comprimento": 18.0,
        "textura": "res://arte/itens/mao/vara.png", "pivo": [3, 22], "ponta": [20, 0]}
```

- **`textura`** — PNG desenhado **em pé**, cabo embaixo. `pivo` é o pixel que
  fica na mão (padrão: meio da borda de baixo); `ponta`, o pixel de onde sai a
  linha (padrão: meio da borda de cima). Ambos em pixels da textura.
- **`cena`** — `.tscn` com raiz `Node2D`, cabo na origem, corpo para cima (−y).
  A ponta sai, nesta ordem, de um método `ponta_local()` da raiz, de um
  `Marker2D` filho chamado `Ponta`, de `mao.ponta`, ou do comprimento. É o
  caminho para arte animada.
- `cena` ganha de `textura`. Arquivo inexistente gera aviso e mantém o
  placeholder: arte faltando nunca tira o item da mão.

A rotação, o espelho e a ordem de desenho continuam vindo das poses — a arte
final só precisa respeitar a convenção "cabo na origem, corpo para cima".

## Poses — `data/itens/mao.json`

Onde fica a mão em cada direção, em pixels do mundo relativos ao **pé** do
jogador (o sprite é 24×24 com `offset (-12, -22)`):

```json
"direita": {"posicao": [6, -7], "rotacao": 35, "atras": false, "espelhar": false}
```

- `rotacao` em graus, **horário**; 0 = item em pé.
- `espelhar` = `scale.x = -1`. Vira o desenho (a linha pende para o outro lado),
  **não** a rotação — o `Node2D` aplica a escala antes de girar. Por isso a pose
  `baixo` (mão à esquerda da tela) tem rotação **negativa**: a vara se abre para
  fora, sem cruzar o rosto.
- `pesca` sobrescreve campos durante a pesca (vara erguida para a água).
- `arremesso`: recuo e avanço em graus somados à pose de pesca. O sinal se
  inverte nas poses espelhadas — "para trás" de quem olha para a esquerda é o
  sentido oposto de quem olha para a direita.

`PosesDaMao` tem os mesmos valores **embutidos**; o JSON os sobrescreve campo a
campo. Arquivo ausente ou torto degrada a calibragem, nunca o jogo — o padrão
de `ConfiguracaoEncontro`.

### O que pende não gira

A linha e a boia da vara e o corpo da lanterna caem na vertical do **mundo**,
não na do item: uma linha inclinada junto com a vara lê como arame. O `_draw`
desfaz a rotação e o espelho herdados antes de desenhar a parte pendente, e o nó
pede redesenho quando a orientação global muda (não quando só anda).

Depois do lance a boia sai da ponta (`ItemNaMao.boia_na_ponta = false`): a linha
passa a ser desenhada no mundo pela pesca, a partir de `SlotDaMao.ponta_global()`,
e desenhá-la aqui também daria duas linhas. `pose_de_pesca(false)` a devolve.

## A roda

| gesto | efeito |
|---|---|
| segurar **Q** (LB no controle) | a cena abre a roda com os equipáveis da bolsa |
| mover o mouse / analógico / tecla de andar | destaca o slot do **setor** apontado |
| mouse perto do centro | zona morta: nada destacado, soltar não troca nada |
| soltar **Q** / clique esquerdo | equipa o destacado e fecha |
| **ESC** / clique direito | fecha sem trocar |

- **Seleção por ângulo**, não por acerto no ícone: o slot `i` ocupa o setor
  `[aᵢ − passo/2, aᵢ + passo/2)`. A conta mora em `GeometriaRoda` (regra pura,
  testada fronteira por fronteira para 1–8 slots). Os ângulos são de
  **bússola** — 0 no topo, horário —, e a conversão para a tela fica num lugar
  só (`direcao_do_angulo`).
- **"Mãos livres"** é sempre o slot do topo (`item_escolhido(null)`).
- Abre na zona morta com o mouse **capturado**: a direção é a soma do movimento
  *relativo* desde a abertura (ponteiro virtual, desenhado como um ponto dourado),
  não a posição do cursor. No Wayland — inclusive via XWayland — o jogo não pode
  mover o cursor, e um `warp_mouse` até o centro vira no-op: lendo a posição
  absoluta, o primeiro movimento destacaria o slot na direção de onde o cursor
  estava, e não do gesto.
- Perder o foco da janela com a roda aberta a fecha **sem trocar**: o soltar do Q
  acontece fora do jogo e nunca chegaria como evento.
- **Modal**: enquanto aberta consome tecla, botão e clique — o F de usar, o E de
  falar e o ESC da pausa não disparam por baixo dela.
- A tecla de andar que **já estava segura** ao abrir não sequestra a seleção; só
  um aperto novo aponta.
- **Quem abre é a cena**, não a roda: o pressionar de `roda_itens` é tratado em
  `mundo.gd`, que sabe se pode (conversa, pesca, mapa...) e tem a `Bolsa`. A
  roda recebe a lista pronta e não conhece autoload nenhum. Travar o movimento
  enquanto ela está aberta também é da cena (`Jogador.congelar`).

Visual: a mesma família da roda de captura — madeira, pergaminho, ouro na
seleção, trilho pontilhado, fonte pixel nos tamanhos nativos —, mas desenhada
por `_draw` em vez de `PanelContainer`: cada slot é um medalhão com um ícone, e
dez Containers por abertura seriam layout pagando por nada. O item na mão tem um
selo verde; o destacado cresce 3px além de ficar dourado (a cor nunca é o único
canal).

## API

| quem | o quê |
|---|---|
| `Jogador` | `signal item_equipado_mudou(id)` · `item_equipado` · `mao` · `equipar(item)` · `item_atual()` |
| `SlotDaMao` | `signal arremesso_concluido()` · `item` · `direcao` · `pescando` · `equipar(item)` · `aplicar_direcao(dir)` · `pose_de_pesca(sim)` · `animar_arremesso()` · `ponta_global()` |
| `ItemNaMao` | `configurar(item)` · `ponta_local()` · `boia_na_ponta` · `tem_arte()` |
| `RodaItens` | `signal item_escolhido(item)` · `signal fechada(trocou)` · `abrir(itens, equipado_id)` · `fechar(confirmar)` · `aberta()` · `indice_destacado()` · `apontar(vetor)` |
| `GeometriaRoda` | `angulo_do_slot` · `posicao_do_slot` · `indice_por_vetor` |
| `PosesDaMao` | `carregar()` · `pose(dir, pescando)` · `sinal_do_giro(dir)` · `recuo_graus` · `avanco_graus` · `duracao_*` |

`arremesso_concluido` sai no fim do **avanço** — o instante em que a linha deixa
a ponta — e sai **sempre**: sem item (deferido, a tempo do `await` de quem
chamou) e com o lance interrompido por troca de pose. Um `await` nele nunca fica
pendurado.

## Arquivos

| arquivo | papel |
|---|---|
| `regras/geometria_roda.gd` | `GeometriaRoda` — ângulo → slot, zona morta (regra pura) |
| `regras/poses_da_mao.gd` | `PosesDaMao` — lê `data/itens/mao.json` com padrões embutidos (regra pura) |
| `item_na_mao.gd` | `ItemNaMao` — placeholder por `_draw` ou arte final |
| `slot_da_mao.gd` | `SlotDaMao` — pose, ordem de desenho, lance, ponta global |
| `roda_itens.gd` | `RodaItens` — a roda radial (camada 88) |
| `../exploracao/jogador.gd` | monta a mão depois do sprite; repassa a direção |
| `../../data/itens/mao.json` | poses por direção, pose de pesca, arremesso |
| `../../data/itens/catalogo.json` | `mao`, `uso` e o marcador `equipamento` de cada item |

Reaproveitados: `IconeCaptura.folha()` / `regiao(id)` (o recorte da folha de
ícones sem instanciar um `Control`), `TemaEncontro` (paleta e fonte).
