# Menu principal

A primeira tela do jogo e o único lugar onde a **seed** é escolhida (RF01).

```bash
godot --path .                                           # abre no menu
godot --headless --path . -s res://tools/test_save.gd    # save: regra + disco
```

## Três páginas, uma cena

```
RAIZ ──Novo jogo──▶ SLOTS (modo NOVO) ──▶ SEED ──Começar──▶ mundo.tscn
  │                                        │
  ├──Continuar──▶ SLOTS (modo CONTINUAR) ──┴──Carregar──▶ mundo.tscn
  ├──Opções────▶ (Etapa 2)
  └──Sair
```

Páginas e não cenas: a troca é instantânea e o fundo nunca pisca. Cena separada
só se justifica quando há estado próprio a montar e desmontar, e aqui são três
`Control` que se revezam na visibilidade.

**Um nó lê a entrada.** `menu_principal.gd::_unhandled_input` oferece o evento à
página ativa e não faz mais nada — a mesma política de `GerenciadorDialogo` e
pelo mesmo motivo: com três páginas lendo `ui_accept` por conta própria, uma
confirmação atravessaria duas delas no mesmo quadro.

## Arquivos

| arquivo | papel |
|---|---|
| `menu_principal.gd` / `.tscn` | **cena principal do projeto**; orquestra as três páginas |
| `fundo_menu.gd` | `FundoMenu` — pixel art gerada em tempo de carga, sem nenhum arquivo de imagem |
| `painel_slots.gd` | `PainelSlots` — os três cartões de slot, para carregar **e** para gravar |
| `painel_nova_partida.gd` | `PainelNovaPartida` — o campo de seed |

Reaproveitados, não recriados:

- `presentation/dialogo/menu_escolhas.gd` — a lista da página RAIZ é a **mesma**
  do diálogo. Ganhou duas coisas para servir aqui: `ancorar_acima` (desligado
  quando quem posiciona é um container, e não a caixa de fala) e o estado
  `{"ativo": false}`, que desenha a opção apagada e faz a navegação pulá-la.
- `presentation/encontro/tema_encontro.gd` — fonte, molduras 9-slice e paleta.
  O nome diz "encontro" por ser onde nasceu; hoje é o tema de todas as telas.

## O fundo não é um arquivo

`FundoMenu` desenha uma `Image` de **192×108** e a amplia 6× com filtro NEAREST —
a mesma técnica da vinheta do encontro, pelas mesmas duas razões:

1. **O pixel fica quadrado e grande.** Desenhar na resolução da tela produziria
   formas de 1 px que, ao lado de uma fonte bitmap 5×7 ampliada, leem como ruído:
   a tela teria duas escalas de pixel brigando.
2. **Custa 20.736 pixels, não 746.496.** Um laço por pixel em GDScript na
   resolução cheia levaria quase um segundo na abertura do jogo.

O céu é **banda chapada + trama de Bayer 2×2** na fronteira entre bandas, nunca
uma interpolação contínua — "um degradê liso no meio de uma tela de pixel art
denuncia a interface como estranha ao jogo" (README do encontro). Banda chapada
com trama é como um céu de pixel art é feito à mão.

Composição, do fundo para a frente: céu em 11 bandas → lua crescente (dois
círculos, o segundo recortando o primeiro) → estrelas com densidade caindo perto
do horizonte → três camadas de colina (perfil por soma de dois senos) → grade de
losangos 16×8, que é a assinatura da projeção 2:1 que o jogo usa → vinheta.

Tudo sai de um `RandomNumberGenerator` semeado por constante: o menu abre
idêntico toda vez. Um fundo que mudasse a cada abertura leria como instabilidade,
não como variedade.

Os vaga-lumes são uma camada à parte (`CamadaDeMotes`), e não pixels na imagem:
são o único elemento animado, e redesenhar a textura inteira por quadro para
mover dezoito pontos custaria o fundo todo a cada frame. `FundoMenu.animado`
desliga a camada — é o gancho da opção "efeitos de tela" da Etapa 2.

## A tela de seed

RF01 é "criação de mundo via seed" e RF03 é "reprodutibilidade total pela seed" —
e até aqui os dois eram uma **constante no código** (`SEED_DO_MUNDO = 123456789`).
Um trabalho cuja contribuição é que a mesma semente reproduz o mesmo bestiário
precisa deixar o jogador digitar a semente; sem isso a propriedade existe e não
se demonstra.

A tela mostra, **ao vivo**, o número em que o texto foi convertido:

```
"ribeira" → 4018126233
Mundo 123456789 — a mesma seed gera sempre o mesmo bestiário.
```

Texto puramente numérico vale por si: digitar `123456789` abre o **mesmo** mundo
do visualizador do bestiário (F2) e dos testes headless — é o que permite
conferir, criatura por criatura, o que apareceu no mato.

O resto passa por uma FNV-1a de 32 bits escrita no projeto
(`sistemas/regras/semente.gd`), e não por `String.hash()`: o hash da engine pode
mudar entre versões do Godot, e a mesma palavra passaria a abrir outro mundo
depois de uma atualização. `tools/test_save.gd` fixa dois valores esperados —
se mudarem, o teste quebra, e tem de quebrar.

## Cartões de slot

Um slot não é uma opção de menu: é um **mundo**. O que o distingue — a seed, a
região, quantas criaturas, há quanto tempo — é informação de várias linhas, e
uma lista vertical de rótulos de uma linha não a comporta. A **seed é o primeiro
campo, em dourado**: é ela que diz qual mundo está ali, e dois slots com a mesma
seed são o mesmo mundo em dois momentos.

O mesmo painel serve aos dois caminhos. Em `CONTINUAR` só slot gravado é
alcançável; em `NOVO` todos são, e o ocupado avisa que será sobrescrito. Duas
telas — "onde carregar" e "onde gravar" — seriam o mesmo desenho duas vezes,
divergindo na primeira correção.

**Save danificado é cartão, não caixa de erro.** Um JSON truncado aparece como um
cartão vermelho com o motivo escrito, ao lado dos outros. O jogador vê o que
houve, vê que os demais estão intactos, e pode apagar aquele (DEL, com
confirmação no próprio cartão) ou começar por cima dele.

## Teclas

| tecla | efeito |
|---|---|
| ↑ ↓ / W S | escolher na lista |
| ← → / A D | escolher o slot |
| **E** / ENTER | confirmar |
| ESC | voltar uma página · cancelar a confirmação de apagar |
| DEL | apagar o slot selecionado (pede confirmação) |

Mouse: passar o cursor seleciona, clique confirma — como em todo menu do projeto.
