# Batalha (RF06) e o arco do jogo

Batalha 1×1 por turnos, com equipe de até 3. Serve ao encontro selvagem e ao duelo
contra guardião: há um sistema de combate só. Fecha o que faltava para o jogo ter
começo, meio e fim.

```bash
godot --headless --path . -s res://tools/test_batalha.gd       # regra, sem cena
godot --headless --path . res://tools/test_encontro.tscn       # gerenciador, com cena
godot --headless --path . res://tools/test_arco.tscn           # o jogo de ponta a ponta
godot --headless --path . -s res://tools/simular_batalha.gd -- --seeds 200   # balanceamento
DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 --rendering-driver opengl3 \
  --path . res://tools/screenshot_batalha.tscn                 # as telas
```

## O arco

```
partida nova ──▶ Mirela oferece 3 criaturas da seed ──▶ salva sozinho
                                 │
              mato alto: batalha, captura, equipe de até 3
                                 │
              Dulce (guardiã do sítio) ──▶ salva sozinho e duela
                    │                              │
                 venceu                     equipe inteira caiu
                    │                              │
          selo ──▶ tela de VITÓRIA          tela de DERROTA ──▶ último save
```

A derrota vale para **qualquer** batalha, inclusive com selvagem. As zonas de encontro
ficam desligadas até a primeira criatura: sem isso, o jogador cairia em batalha
desarmado no caminho até quem dá a criatura.

## Stats e golpes são derivados, não declarados

Nenhuma tabela por espécie, e o `GeradorCriaturas` **não foi tocado**. É o mesmo
caminho da afinidade de captura e do perfil de pesca: `FichaCombate` lê a morfologia e
o porte já sorteados.

| origem | efeito |
|---|---|
| fórmula do vigor (`data/captura/balanceamento.json`) | vida |
| garras | ataque, e o golpe Rasgar (forte, pode errar) |
| escamas | defesa, e o golpe Couraça (sobe a defesa) |
| asas | velocidade, e o golpe Rasante (age primeiro) |
| nadadeiras | esquiva, e o golpe Deslize (sobe a esquiva) |
| variante do traço | escala o stat e o golpe, pelo eixo de `data/feature_variants.json` |
| porte | compacto: defesa e vida; alongado: velocidade |
| elemento | um golpe próprio e a vantagem; **não** dá stat |

O jogador vê garras no sprite e tem um golpe de garra. E o contrapeso já existia: cada
traço que fortalece aqui também aumenta a evasão na captura. Criatura sem traços é
fraca, porém fácil de pegar.

**No trade-off:** derivar custa quase nada em tempo real e não altera o bestiário, logo
coerência e métricas ficam preservadas. Uma busca ao estilo de Togelius et al. (2011)
pagaria desempenho sem ganho para este objetivo.

## Arquivos

### Regra — `regras/`, sem engine, testável fora de cena

| arquivo | papel |
|---|---|
| `tabelas_batalha.gd` | `TabelasBatalha` — carrega `data/batalha/*.json` e valida contra o vocabulário |
| `golpe.gd` | `Golpe` — uma entrada do catálogo |
| `ficha_combate.gd` | `FichaCombate` — atributos sorteados → stats e golpes |
| `combatente.gd` | `Combatente` — ficha + vida atual + reforços |
| `calculo_batalha.gd` | `CalculoBatalha` — **único** lugar que decide dano, acerto, fuga e efeito de item |
| `ia_batalha.gd` | `IaBatalha` — como o adversário escolhe; o simulador usa a mesma |
| `motor_batalha.gd` | `MotorBatalha` — recebe uma ação, devolve os eventos do turno |
| `equipe_jogador.gd` | `EquipeJogador` — equipe ativa e depósito |
| `selecao_bestiario.gd` | `SelecaoBestiario` — iniciais e equipes de guardião, por percentil de força |
| `catalogo_guardioes.gd` | `CatalogoGuardioes` — `autoral/guardioes/guardioes.json` |

### Apresentação

| arquivo | papel |
|---|---|
| `texto_batalha.gd` | como os números viram texto, igual em todas as telas |
| `tela_escolha_inicial.gd` | 1 entre 3, com o que cada corpo faz em batalha |
| `tela_equipe.gd` | equipe e depósito, no menu de pausa |
| `tela_bestiario.gd` | o bestiário da seed (N ou pausa), com marca nas capturadas; existe também na build de entrega |
| `tela_desfecho.gd` | vitória e derrota |

A batalha em si é desenhada por `presentation/encontro/interface_encontro.gd` e
conduzida por `gerenciador_encontro.gd`, que percorre os eventos do motor. O arco é
costurado em `presentation/exploracao/mundo.gd`.

## Equipe não é autoload

`sistemas/README.md` previa um autoload `Equipe`. A régua daquele diretório é o tempo de
vida, e uma `Criatura` só resolve contra o bestiário, que nasce e morre com a cena do
mundo. Por isso `EquipeJogador` vive no `GerenciadorEncontro`, e o save a colhe por seção
de cena. O save guarda índice, seed e vida (`CriaturaSalva.hp_atual`).

## Guardiões

`autoral/guardioes/guardioes.json` declara o NPC, o selo, os elementos da região, o
tamanho da equipe e o percentil de força. A **equipe** vem do bestiário da seed: seed
diferente, guardião diferente, e o percentil mantém a dificuldade parecida.

Acrescentar um guardião é uma entrada ali e os nós no diálogo dele. `selos_para_vencer`
diz quantos selos encerram o jogo. Hoje só a Dulce existe, então vale 1.

## Balanceamento

`tools/simular_batalha.gd` joga automaticamente e sai com erro se um critério falhar.
Medido com 1000 seeds (5000 batalhas):

| critério | meta | medido |
|---|---|---|
| turnos no duelo com a Dulce | 3 a 8 | 7,61 |
| vitórias da equipe mediana de 3 | 55% a 80% | 77,1% |
| criatura invencível | nenhuma | nenhuma (maior taxa 97,5%) |
| mesma seed, mesma batalha | sim | sim |

Só com a primeira criatura, a vitória contra a Dulce cai para cerca de 8%: capturar é
obrigatório na prática. A "equipe mediana" é jogada pela IA, sem curar, trocar ou
escolher vantagem de propósito, então o número é um **piso de jogabilidade**, não uma
previsão de como pessoas jogam. Só o playtest responde isso.

**Rodar de novo depois do gerador v2:** ele muda a distribuição de traços, e com isso
todo este equilíbrio.
