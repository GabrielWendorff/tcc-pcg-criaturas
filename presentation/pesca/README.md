# Pesca — arremesso, recolhimento e a silhueta

Segunda forma de encontrar uma criatura do bestiário gerado pela seed (Camada 2),
depois do mato: na beira da água, com a vara na mão, o jogador arremessa, recolhe
a linha e tenta convencer a sombra que segue a isca a morder.

```bash
godot --headless --path . -s res://tools/test_pesca.gd   # regra inteira, sem janela
godot --path .                                           # vara na mão, beira d'água, [F]
```

## Roteiro

```
OCIOSO ── vara na mão + água à frente ──→ "[F] PESCAR" sobre o jogador
   │  usar_item
   ▼
ARREMESSO ── arco de 180° oscilando (verde → amarelo → vermelho → volta)
   │  usar_item trava a força ─→ a vara gira ─→ a boia voa e cai na água
   ▼
RECOLHENDO ── corte da água: mouse X = velocidade, mouse Y = altura
   │           silhueta surge → igualar altura E velocidade → INTERESSE enche
   ├──────────→ FISGADO  "FISGOU!" + tremor ─→ peixe_fisgado(criatura)
   └──────────→ FALHOU   "ESCAPOU..." (interesse zerou) · "Nada mordeu a isca."
   ▼                     (a isca chegou à margem) · cancelada (ui_cancel)
OCIOSO ── tela fechada, linha recolhida, jogador livre ─→ pesca_encerrada
```

| fase | o que o jogador vê | o que decide |
|---|---|---|
| 1. arremesso | `MedidorArremesso` embaixo-centro; no tutorial, FRACO / MÉDIO / MÁXIMO sobre as zonas | a força (0..1) vira distância: `lerp(1.5, 7.0)` células, presa ao trecho de água à frente |
| 2. recolhimento | `MinigameRecolhimento` em tela cheia, com o topo livre para a dica do tutorial | a isca anda para a margem; chegar nela sem fisgar é FALHOU |
| 3. silhueta | `SilhuetaCriatura` atrás da isca, chegando perto quando o interesse sobe | ALTURA OK + VELOCIDADE OK ao mesmo tempo enchem o interesse; fora, ele cai mais devagar |
| 4. resultado | letreiro no centro, depois a tela fecha | FISGADO emite `peixe_fisgado` e **para aí** |

`ui_cancel` cancela em qualquer fase ativa. O jogador fica congelado de
`ARREMESSO` até `encerrar()`, a vara fica erguida (`SlotDaMao.pose_de_pesca`) e o
lance tem o giro da vara (`SlotDaMao.animar_arremesso`).

## Arquivos

### Regra — `regras/`, sem engine, testável fora de cena

| arquivo | papel |
|---|---|
| `configuracao_pesca.gd` | `ConfiguracaoPesca` — todos os números e textos (`data/pesca/configuracao.json`) |
| `estado_pesca.gd` | `EstadoPesca` — máquina de estados com tabela de transições |
| `arco_de_forca.gd` | `ArcoDeForca` — vai-e-volta, zonas e geometria do arco |
| `perfil_pesca.gd` | `PerfilPesca` — altura, velocidade, folgas e raridade **derivadas** da criatura |
| `ponto_de_pesca.gd` | `PontoDePesca` — o "FishingSpot": pesos por elemento/animal, roleta, monstro mais fácil |
| `tabelas_pesca.gd` | `TabelasPesca` — carrega e valida `perfil.json` e `pontos.json` |
| `simulacao_recolhimento.gd` | `SimulacaoRecolhimento` — o minigame inteiro como regra pura e determinística |

### Apresentação

| arquivo | papel |
|---|---|
| `gerenciador_pesca.gd` | `GerenciadorPesca` — orquestra tudo; **único** nó que conhece as partes |
| `interface_pesca.gd` | `InterfacePesca` — `CanvasLayer` 84: arco, minigame, letreiro, legenda de teclas |
| `medidor_arremesso.gd` | `MedidorArremesso` — o arco de força (`_draw` + `draw_arc`) |
| `minigame_recolhimento.gd` | `MinigameRecolhimento` — corte da água; lê a entrada, chama `passo()`, desenha |
| `silhueta_criatura.gd` | `SilhuetaCriatura` — a máscara do corpo da criatura, pintada de uma cor só |
| `lancamento_mundo.gd` | `LancamentoMundo` — linha e boia no mundo: voo em parábola, respingo, recolher |

Também usa `presentation/exploracao/indicador_interacao.gd` (`configurar("[F]",
"PESCAR")` — o mesmo aviso do "[E] FALAR" dos NPCs) e, do equipamento, `Jogador.mao`
(`SlotDaMao`) e `ItemJogo.uso == "pescar"`.

Nenhum nó tem `.tscn`: tudo é montado por código, como o resto do projeto. Os nós
de interface expõem `@export` para os parâmetros **visuais** (cores, folgas,
tremor) e recebem a calibragem do JSON por `configurar(cfg)`.

## Por que o perfil é derivado da morfologia, e não uma tabela por espécie

O bestiário muda com a seed. Uma tabela "espécie → altura/velocidade" valeria para
uma seed só — e, pior, seria uma segunda fonte de verdade sobre a criatura,
independente da que o gerador produziu.

`PerfilPesca` é uma **soma de contribuições** sobre o que o gerador já sorteou por
probabilidade condicionada — `animal_base`, `elemento`, `porte`, traços de
morfologia (`data/pesca/perfil.json`). É o mesmo espírito da afinidade na captura
(`encontro/README.md`): a coerência semântica do trabalho (RF04) **vira mecânica**
sem regra extra.

- o que **emerge** das tabelas condicionais é o efeito dos traços: nadadeiras
  deixam a criatura **rápida** e estreitam a folga de velocidade; escamas puxam
  para o fundo e **alargam** as duas folgas; asas puxam para a superfície;
  compacto puxa para o fundo e devagar;
- o contraste peixe **fundo e rápido** × anfíbio **raso e devagar** vem sobretudo
  de `por_animal` em `perfil.json` (é declarado, não emergente). Por isso o peixe
  pede arremesso longo;
- `água + peixe` recebe nadadeiras **e** escamas com alta probabilidade em
  `conditional_morphology.json`, e as escamas compensam as nadadeiras: o mais
  escorregadio é quem tem nadadeiras **sem** escamas (tipicamente o anfíbio).
  Pela `PerfilPesca.dificuldade()`, na seed de teste o peixe é em média **mais
  fácil** que o anfíbio (16,2 × 18,4; `tools/test_pesca.gd` imprime a tabela).

O monstro de ensino do tutorial não é "o anfíbio": é o candidato de menor
`dificuldade()` do ponto (`PontoDePesca.mais_facil`). Na seed de teste, um
anfíbio com escamas (Gelo-Anfibio #050). Ler a silhueta — o tamanho, a altura em
que nada, a pressa — é ler a saída do gerador. A própria silhueta é a **máscara
do corpo** daquela criatura (`CatalogoCorpos.textura_corpo(body_id)`): um
alongado dá uma sombra comprida, um compacto uma sombra redonda.

O **ponto de pesca** muda *quem* aparece ali, nunca *como* a criatura é gerada:
declara pesos por elemento e animal, e os candidatos são calculados sobre o
bestiário da seed depois da geração (lago da vila, ribeira do Anselmo, rio da
fábrica; região sem ponto cai na ribeira).

## Determinismo (RF03)

- Os perfis são calculados **uma vez**, depois da geração, com um RNG próprio por
  criatura (`seed_individual + 0x9E5CA`). Não consomem nada do RNG do gerador: o
  bestiário de uma seed e as métricas de RF04/RF08 são **os mesmos** de antes da
  pesca existir.
- Todo sorteio do lance (surgir ou não, qual monstro, fase e período da deriva)
  sai de **um** `RandomNumberGenerator` do `GerenciadorPesca`, semeado com
  `world_seed + 0x9E5CA0` (o encontro usa `0x5E7A`) e consumido em sequência por
  todos os lances da partida. Nenhum `randf()` global.
- `SimulacaoRecolhimento` avança por `passo(delta, altura, x)` numa ordem fixa:
  mesma configuração + mesma seed + mesma sequência de entradas ⇒ mesmo desfecho no
  mesmo instante. É o que `tools/test_pesca.gd` verifica, jogando a pesca com uma
  política perfeita, uma errada e a do tutorial, sem janela.

O cenário do minigame (nuvens, pedras do leito, bolhas) é função do relógio, não
de sorteio: o fundo não consome RNG da pesca.

## O que a pesca NÃO faz

Não captura, não batalha, não guarda criatura nenhuma. Ao fisgar, emite
`peixe_fisgado(criatura)` e encerra (ou, com `encerrar_ao_fisgar = false`, fica em
FISGADO com o jogador congelado até alguém chamar `encerrar()`). Batalha e captura
(RF06) entram **ali**, sem mudar nada da pesca.

## O ponto de integração: `peixe_fisgado`

```gdscript
pesca.peixe_fisgado.connect(_ao_fisgar)        # em presentation/exploracao/mundo.gd

func _ao_fisgar(criatura: Criatura) -> void:
	# hoje: nota no HUD. amanhã: abrir a batalha/captura com esta criatura.
	_nota("Fisgou %s!" % criatura.nome())
```

Para uma batalha que precise da tela, a cena faz `pesca.encerrar_ao_fisgar = false`,
abre a batalha no `peixe_fisgado` e chama `pesca.encerrar()` quando ela acabar. Em
FISGADO com `encerrar_ao_fisgar = false`, o `ui_cancel` é ignorado pela pesca: a
fisgada já pertence a quem recebeu o sinal.

Outros sinais para a cena e o tutorial: `pesca_iniciada`, `arremessado(forca, zona,
distancia)`, `silhueta_surgiu(criatura)`, `pesca_falhou(motivo)` (`"cancelada"`,
`"recolhida"`, `"fugiu"`), `pesca_encerrada`, `aviso(texto)` (sem vara / sem água,
para o HUD) e `estado_mudou`.

## Montagem (o que `mundo.gd` faz)

```gdscript
pesca = GerenciadorPesca.new()
pesca.name = "Pesca"
add_child(pesca)          # filha da CENA: recebe o ESC antes do _unhandled_input dela
pesca.preparar(jogador, camera, encontros.bestiario, seed_do_mundo, _e_agua,
		_regiao_em, mundo.celula, encontros.catalogo)
pesca.permissao = func() -> bool: return _dono_da_tela() == ""   # um dono da tela por vez

func _e_agua(p: Vector2) -> bool:
	return mundo.terreno_em(mundo.mundo_para_celula(p)) == "agua"

func _regiao_em(p: Vector2) -> String:
	var r := _regiao_da_celula(mundo.mundo_para_celula(p))
	return r.id_regiao if r != null else ""
```

`e_agua` e `regiao_em` são `Callable`: o gerenciador não conhece o `MundoIso`. Uma
cena de teste liga a pesca a um retângulo de água e a dois monstros de exemplo sem
carregar o mapa.

Entrada só por ações do InputMap: `usar_item` (F / clique / botão 2 do controle)
começa e trava o arco; `ui_cancel` cancela. Sem vara **e** sem água à frente, o
`usar_item` não é tratado como tentativa de pescar (não avisa nem consome) — o
clique do mouse também é `usar_item`, e avisar "equipe a vara" a cada clique no
mapa seria ruído.

## Como testar

```bash
GODOT=godot   # ou o wrapper do ambiente
$GODOT --headless --path . -s res://tools/test_pesca.gd   # regra, calibragem e RF03
$GODOT --headless --path . res://tools/test_pesca_integracao.tscn   # no mundo: CENA, nao -s
$GODOT --path . res://tools/cena_teste_pesca.tscn         # sandbox (ou F6 no editor)
$GODOT --headless --path . --check-only -s res://presentation/pesca/medidor_arremesso.gd
```

- **`tools/cena_teste_pesca.tscn`** — sandbox para calibrar: chão plano, uma faixa
  de água (`Polygon2D` com colisão), o `Jogador` de verdade com a vara, a câmera, a
  roda e a pesca com **duas criaturas de exemplo** montadas à mão (Agua-Peixe
  esbelto com nadadeiras e escamas; Gelo-Anfibio compacto sem traços). `e_agua` e
  `regiao_em` leem o polígono. Teclas: **Q** roda, **F** pescar, **ESC** cancela,
  **T** liga/desliga o modo tutorial, **R** reinicia. O console imprime os perfis
  das duas criaturas e os pesos no ponto; o HUD mostra estado, sombra, interesse e
  o último resultado. A região da água (e com ela o ponto de pesca) é `@export`.
- **`tools/test_pesca_integracao.tscn`** — instancia `mundo.tscn`, acha uma beira
  perto do Anselmo e joga: sem vara → aviso (pela tecla F); roda pelo Q; lance com
  política perfeita até `peixe_fisgado`; ESC no recolhimento cancela sem abrir a
  pausa; a lição inteira do Anselmo; pular a lição; save do item na mão e da
  bandeira.

Os nós desta pasta que citam a câmera (`GerenciadorPesca`, e o `IndicadorInteracao`
que ele usa) não compilam sob `-s` no Godot 4.7: `CameraExploracao` cita o autoload
`Opcoes`, que só existe com a cena rodando. Eles são conferidos rodando o jogo (ou
uma cena de teste em `tools/`) normalmente, sem `-s`. Para jogar o minigame sem o
mouse, troque a entrada:

```gdscript
pesca.interface.minigame.fonte_de_entrada = func() -> Vector2:
	var s := pesca.simulacao()
	if s == null or s.perfil == null:
		return Vector2(1.0, 0.5)                     # devagar, meia-água
	return Vector2(1.0 - s.velocidade_monstro, s.profundidade_monstro)   # política perfeita
```

## Calibragem

Todos os números estão em `data/pesca/` (ver `data/README.md`): arco, distâncias,
velocidades de recolhimento, chance de surgimento, ganho e perda de interesse,
deriva, tutorial e textos em `configuracao.json`; a fórmula do perfil em
`perfil.json`; os habitats em `pontos.json`. Nada disso aparece como literal no
código desta pasta.
