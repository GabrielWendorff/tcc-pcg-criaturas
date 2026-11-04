# Exploração — o mundo jogável (RF05)

Mundo contínuo em perspectiva isométrica, **uma grade de 96×88 células** com
quatro regiões vizinhas. O jogador nasce na praça da vila e atravessa para as
outras andando: não há carregamento, tela de transição nem mapa separado.

```
Vila do Poço ──estrada leste──▶ Ribeira ──margem──▶ Distrito da Chaminé
     │                                                      ▲
     └──estrada sul──▶ Sítio da Dulce ──ponte do sítio──────┘
```

```bash
godot --path .                                              # abre no menu principal
godot --headless --path . -s res://tools/test_mundo.gd      # mundo, regiões, NPCs, mapa
godot --headless --path . -s res://tools/test_interacao.gd  # fluxo de interação montado
godot --headless --path . res://tools/test_pesca_integracao.tscn  # pesca/roda/lição no mundo (CENA, não -s)
godot --path . res://tools/cena_teste_pesca.tscn            # sandbox da pesca (ou F6 no editor)
python3 tools/mapas/gerar_mundo.py                          # recompila o mapa
python3 tools/mapas/preview_mundo.py --debug                # confere fora da engine
```

> **Clone novo:** rode `godot --headless --path . --import` uma vez antes de
> qualquer coisa. Os `*.import` estão no `.gitignore`, e sem eles nenhum PNG
> carrega — e o `global_script_class_cache.cfg` também não existe, então nem os
> `class_name` deste diretório resolvem.

## Arquivos

| arquivo | papel |
|---|---|
| `mundo.tscn` / `.gd` | cena: monta mundo, jogador, câmera, encontros, diálogo, roda de itens, pesca, tutorial e mapa — e é o **único** lugar que os liga entre si |
| `mundo_iso.gd` | `MundoIso` — lê os dados e constrói chão, props, colisão, regiões e limites |
| `jogador.gd` | `Jogador` — `CharacterBody2D` com movimento isométrico e a mão (`SlotDaMao`, ver `equipamento/`) |
| `camera_exploracao.gd` | `CameraExploracao` — segue o jogador, confinada ao mapa |
| `ponto_de_encontro.gd` | `PontoDeEncontro` — zona de encontro (geometria + dados) |
| `regiao_mundo.gd` | `RegiaoMundo` — área de uma região; avisa a chegada, alimenta o mapa |
| `npc.gd` | `Npc` — **um** script para todos os NPCs, configurado por dado |
| `indicador_interacao.gd` | `IndicadorInteracao` — o `[E] FALAR` sobre a cabeça (e o `[F] PESCAR`, por `configurar`) |
| `anuncio_regiao.gd` | `AnuncioRegiao` — o nome da região ao entrar nela |
| `menu_pausa.gd` | `MenuPausa` — pausa a **árvore**; abre bolsa e opções |

Os dados vêm de fora e esta camada não gera nada:

- `autoral/mapas/mundo.json` — o mapa (Camada 1, fixo, **sem seed**)
- `autoral/npcs/npcs.json` + `autoral/dialogos/*.json` — quem mora onde e o que diz
- `arte/mundo/atlas_terreno.json` + `.png` — tiles do chão
- `arte/mundo/props.json` + `props/*.png` — casas, árvores, fábrica, plantação…

## Estrutura da cena

```
Mundo
├── Mundo                MundoIso
│   ├── Chao             TileMapLayer  · y-sort DESLIGADO
│   ├── Entidades        Node2D        · y-sort LIGADO
│   │   ├── Penhascos    Node2D        · y-sort LIGADO   grupo "penhascos"
│   │   ├── Arvores / Pedras / Decoracao / Casas          grupos idem
│   │   ├── Jogador      CharacterBody2D                  grupo "jogador"
│   │   │   ├── Corpo           CollisionShape2D
│   │   │   ├── Sprite          AnimatedSprite2D
│   │   │   ├── SlotDaMao       Marker2D · antes do Sprite olhando para cima
│   │   │   │   └── ItemNaMao   Node2D   · o item equipado (vara, lanterna...)
│   │   │   ├── AvisoEncontro   o "!" do encontro
│   │   │   └── IndicadorPesca  IndicadorInteracao "[F] PESCAR"
│   │   └── Npc_*        CharacterBody2D                  grupo "npcs"
│   ├── LimitesDoMapa    StaticBody2D
│   ├── PontosDeEncontro Node2D                           grupo "pontos_de_encontro"
│   └── Regioes          Node2D                           grupo "regioes"
├── Camera · Depuracao · HUD
├── Encontros            GerenciadorEncontro   (TransicaoEncontro 80, InterfaceEncontro 90)
├── Dialogos             GerenciadorDialogo    (CaixaDialogo 70)
├── RodaItens            CanvasLayer 88        roda de itens do Q
├── Pesca                GerenciadorPesca      (InterfacePesca 84, LancamentoMundo)
├── Tutorial             GerenciadorTutorial   (DicaTutorial 92)
├── AnuncioRegiao        CanvasLayer 60
├── MapaMundo            CanvasLayer 95
└── Pausa                MenuPausa 96 (a bolsa, 97, abre por dentro dela)
```

Três decisões carregam a árvore do mundo:

1. **O chão nunca entra no y-sort.** Ligar `y_sort_enabled` numa `TileMapLayer`
   joga os tiles na mesma lista de ordenação dos irmãos; basta um tile com
   `y_sort_origin != 0` para o chão passar *à frente* do jogador.
2. **Os containers de categoria têm y-sort ligado.** Em Godot 4 um filho
   y-sorted tem os próprios filhos *achatados* na lista do pai — é isso que
   permite agrupar por categoria sem quebrar a profundidade.
3. **Todo sprite é `centered = false` com `offset` no pé.** A chave do y-sort é a
   `position` do nó, nunca o desenho.

O **NPC entra no mesmo container y-sorted** do jogador e dos props: é o que o faz
passar atrás da casa ao norte dela e na frente ao sul.

## As quatro regiões

| região | o que é | zonas de encontro |
|---|---|---|
| **Vila do Poço** | praça, poço, 7 casas, lago — **preservada** da etapa anterior | 8 |
| **Ribeira do Anselmo** | o rio que sai do lago da vila, juncos, barranco, cabana | 3 |
| **Distrito da Chaminé** | fábrica parada, galpões, calçada, padaria, oficina | 2 |
| **Sítio da Dulce** | três talhões, celeiro, espantalhos, cercas | 3 |

O mapa é **um só**. Região é *dado* (um retângulo com nome), não fronteira de
carregamento: `RegiaoMundo` é uma `Area2D` que avisa a chegada e marca a região
como descoberta; o resto continua sendo o mesmo `TileMapLayer`.

A transição entre elas é gradual de propósito — estrada, cerca, mato alto
adensando perto da divisa, ponte sobre o rio. Nenhuma borda reta entre ambientes.

### A ponte é terreno, não prop

Um sprite de ponte sobre a água exigiria que a água deixasse de bloquear naquelas
células — isto é, uma exceção no dado do mapa. A colisão do tile é justamente o
que segura o jogador no resto do rio. Por isso `ponte` é uma **linha do atlas de
terreno**, como `calcada` e `lavoura`.

## Movimento isométrico

`Input.get_vector` já normaliza a diagonal; o eixo vertical é multiplicado por
`RAZAO_ISO = 0.5` porque, numa projeção 2:1, 32 px na horizontal e 16 px na
vertical cobrem a **mesma** distância no chão.

O corpo do jogador é um **círculo**, não um retângulo: a fronteira de um bloco de
losangos é uma serra de faces a 26,57°, e um retângulo engancha nos degraus. O
NPC usa o mesmo raio — dois corpos de raios diferentes dariam folgas de passagem
diferentes em corredores iguais.

## Limites do mapa

Duas camadas, por motivos diferentes:

- **Colisão de tile** na rocha da borda e na água — contra ela o jogador
  *escorrega*, o que é desejado na margem e insuficiente como limite de mundo;
- **`LimitesDoMapa`**: quatro paredes retas ao longo das arestas do losango. É o
  limite duro. A `Camera2D` usa o mesmo retângulo — que **não** é
  `(0, 0, L·tw, A·th)`: um mapa isométrico é um losango que invade *x* negativo.

## Teclas

| tecla | efeito |
|---|---|
| setas / WASD | andar |
| **E** | falar com o NPC ao alcance · avançar a fala · confirmar a escolha |
| **Q** | **segurar** abre a roda de itens; apontar com o mouse (ou analógico); **soltar** equipa · ESC/clique direito fecha sem trocar |
| **F** (ou clique) | usar o item na mão — com a vara, de frente para a água: pescar · no arco, trava a força |
| ESC | durante a pesca: cancela o lance (não abre a pausa) |
| **P** | durante a lição do Anselmo: pular (pergunta "Tem certeza?") |
| **B** | abre a bolsa direto (fechar devolve o jogo, sem passar pela pausa) |
| **ESC** | menu de pausa: continuar · bolsa · opções · salvar · menu principal |
| F5 | atalho de gravação (o mesmo que ESC → SALVAR) |
| **M** | abre e fecha o mapa geral |
| ESC | sai da conversa · fecha o mapa (só abre a pausa quando nada está na frente) |
| F3 (só debug) | sobrepõe zonas de encontro, terreno bloqueado e etiquetas das casas |
| F2 (só debug) | volta ao visualizador do bestiário (RF07/RF08) |
| F4 (só debug) | força um encontro na zona mais próxima |

F2, F3 e F4 valem no editor e na build de debug (`OS.is_debug_build()`). Na build de
entrega não existem nem aparecem no HUD, para não distorcer um playtest.

## Quem tem o controle

Encontro, diálogo, mapa, pausa, pesca, roda de itens e a pergunta "pular a
lição?" disputam o mesmo personagem. A coordenação fica **nesta cena** —
nenhum deles conhece os outros. Todas as permissões leem a **mesma** lista,
`mundo.gd::_dono_da_tela()`, que devolve quem está com a tela (`""` = ninguém):

```gdscript
dialogos.permissao = func() -> bool: return _dono_da_tela() == ""
pesca.permissao    = func() -> bool: return _dono_da_tela() == ""
func _pode_pausar() -> bool:         return _dono_da_tela() == ""
# _alternar_mapa, _forcar_encontro (F4) e _abrir_roda (Q) perguntam o mesmo
tutorial.permissao_pulo = func() -> bool:
	return not (_dono_da_tela() in ["roda", "mapa", "encontro", "pausa"])
```

Um sistema novo que tome a tela entra em `_dono_da_tela` uma vez, e não em seis
closures espalhadas. As ligações no outro sentido também são daqui:

| quando | a cena faz |
|---|---|
| `encontro_iniciado` / `encontro_terminado` | esconde/mostra o HUD; suspende/retoma o diálogo |
| `pesca_iniciada` | suspende o diálogo (some o "[E] FALAR") |
| `arremessado` | esconde o HUD (o minigame cobre a tela; o topo é da dica do tutorial) |
| `pesca_encerrada` | retoma o diálogo, mostra o HUD, atualiza a bolsa |
| `peixe_fisgado` | `_ao_fisgar(criatura)` — **ponto de integração** da batalha/captura futuras |
| `Q` pressionado | `roda.abrir(Bolsa.com_marcador("equipamento"), jogador.item_equipado)` + congela |
| `roda.item_escolhido` / `roda.fechada` | `jogador.equipar(item)` / descongela |
| `Bolsa.item_mudou(id, 0)` com `id` na mão | desequipa |
| `jogador.item_equipado_mudou` e os sinais da pesca | `tutorial.notificar(...)` |
| `tutorial_iniciado` / `tutorial_concluido` | `pesca.modo_tutorial = true / false` |
| serviço `tutorial` / `pesca` do diálogo | `tutorial.iniciar(...)` / nota com a dica de como pescar |
| dica do tutorial na tela | as duas linhas de cima do HUD cedem o topo (a nota fica) |

**Ordem da entrada.** O Godot entrega `_input` antes de tudo e
`_unhandled_input` dos filhos **antes** do pai, do último filho para o primeiro.
Por isso:

1. `_input`: o `Tutorial` lê o **P**; a `RodaItens`, aberta, é modal — lê o
   soltar do **Q**, o mouse e o ESC e consome qualquer tecla;
2. `_unhandled_input` dos filhos: a `Pesca` lê **F** e, com a pesca ativa,
   consome o **ESC** (cancela) e qualquer outro **F**; o `Dialogos` lê **E** e o
   ESC da conversa;
3. `_unhandled_input` desta cena, por último: ESC = pausa, B, M, **Q** (abrir a
   roda), F2–F5.

É essa ordem que faz o ESC no meio do recolhimento cancelar a pesca **sem**
abrir o menu de pausa — `tools/test_pesca_integracao.tscn` confere com uma tecla
de verdade.

O `GerenciadorEncontro` não precisou mudar: a detecção dele conta **distância
andada**, e durante conversa, mapa, roda ou pesca o jogador está congelado.

## O que esta etapa NÃO faz

Loja, missão, batalha de verdade, arbusto interativo e interior de casa. A pesca
existe desde 2026-10-27 (`presentation/pesca/`) e para na fisgada: a batalha ou a
captura que viriam depois entram em `_ao_fisgar`.

**A pausa pausa a árvore** (`get_tree().paused`), e não só congela o jogador como
o mapa e o diálogo fazem. Com a árvore correndo, o sorteio de encontro continua
rodando atrás do menu, e o jogador voltaria de uma pausa de dois minutos para um
encontro que começou sem ele. Congelar o personagem resolve o movimento, não o
tempo.
Os ganchos existem e estão documentados em `presentation/dialogo/README.md` e em
`docs/pendencias.md`.

**O save existe desde a Etapa 1** (`sistemas/`), e a seed não é mais constante:
`SEED_DO_MUNDO` virou o padrão de quando a cena é aberta direto (editor, teste
headless, screenshot), e a partida de verdade traz a sua em `Save.partida`. Esta
cena registra quatro seções no autoload — jogador, estado do mundo, itens e
criaturas — e não conhece o formato do arquivo. A seção "jogador" guarda também o
**item na mão** (`DadosPartida.item_equipado`), reposto antes do retorno cedo de
`_repor_jogador` e só se a bolsa ainda o tem; a lição de pesca concluída é uma
bandeira do `EstadoMundo` e viaja na seção "estado do mundo".
