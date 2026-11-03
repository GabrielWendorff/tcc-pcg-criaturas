# NPCs e diálogo

Personagens autorais com quem se conversa, e a árvore de diálogo que sustenta a
conversa. É a base sobre a qual missão, loja, pesca e agenda entram — todas têm
gancho declarado aqui. A **pesca** foi a primeira a ser atendida: o Anselmo ensina
a pescar pelo serviço `{"tipo": "tutorial"}` (ver `presentation/tutorial/`).

```bash
godot --headless --path . -s res://tools/test_dialogo.gd     # regras + árvores
godot --headless --path . -s res://tools/test_interacao.gd   # fluxo montado
DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 \
  --rendering-driver opengl3 --path . -s res://tools/screenshot_dialogo.gd
```

## Como adicionar um NPC

Três passos, **nenhum deles é escrever código**:

1. gere a arte (uma paleta nova em `autoral/gerar_npcs.py`, que reaproveita a
   geometria do protagonista) — ou aponte para uma folha 4×4 já existente;
2. escreva a árvore em `autoral/dialogos/<id>.json`;
3. acrescente a ficha em `autoral/npcs/npcs.json`.

```json
{
  "id": "anselmo", "nome": "Anselmo", "papel": "Pescador",
  "dialogo": "anselmo", "regiao": "ribeira",
  "celula": [60, 20], "direcao": "cima", "alcance": 1.8,
  "folha":   "res://autoral/npcs/anselmo_1x.png",
  "retrato": "res://autoral/npcs/retratos/anselmo.png",
  "servico": {"tipo": "pesca"}
}
```

`tools/mapas/gerar_mundo.py` **valida a célula**: NPC dentro de um prop ou
inalcançável a pé faz a geração do mapa falhar. `tools/test_mundo.gd` confere
que ele está na região que declara.

## Arquivos

### Regras — `regras/`, sem engine, testável fora de cena

| arquivo | papel |
|---|---|
| `estado_mundo.gd` | `EstadoMundo` — bandeiras, regiões visitadas, nós vistos, **provedores** e serialização |
| `condicao_dialogo.gd` | `CondicaoDialogo` — avalia e **valida** as condições declarativas |
| `no_dialogo.gd` | `NoDialogo` — falas, variantes, escolhas, efeitos de um nó |
| `arvore_dialogo.gd` | `ArvoreDialogo` — carrega e valida um `autoral/dialogos/*.json` |
| `catalogo_dialogos.gd` | `CatalogoDialogos` — acesso por id, carga sob demanda |
| `dados_npc.gd` | `DadosNpc` — ficha de um NPC |
| `catalogo_npcs.gd` | `CatalogoNpcs` — todas as fichas + validação contra diálogos e arte |
| `sessao_dialogo.gd` | `SessaoDialogo` — o percurso de **uma** conversa |

### Apresentação

| arquivo | papel |
|---|---|
| `gerenciador_dialogo.gd` | `GerenciadorDialogo` — instancia NPCs, detecta o mais próximo, conduz a sessão; `conversar_com(npc, id_arvore, no_inicial)`, `encerrar_conversa()`, `npc_por_id()` |
| `caixa_dialogo.gd` | `CaixaDialogo` — retrato, placa de nome, texto com máquina de escrever |
| `menu_escolhas.gd` | `MenuEscolhas` — lista navegável (teclado, mouse e controle) |

Fora deste diretório, mas parte do sistema:

- `presentation/exploracao/npc.gd` — `Npc`, **um** script para todos os NPCs
- `presentation/exploracao/indicador_interacao.gd` — o `[E] FALAR` sobre a cabeça

## Formato da árvore

```json
{
  "id": "mirela", "nome": "Mirela", "inicio": "raiz",
  "nos": {
    "raiz": {
      "falas": ["Você é novo por aqui?"],
      "variantes": [
        {"se": {"bandeira": "se_apresentou"}, "falas": ["De volta, hein?"]}
      ],
      "escolhas": [
        {"texto": "Sim, acabei de chegar.", "destino": "chegou",
         "efeitos": {"definir": {"se_apresentou": true}}},
        {"texto": "Não quero conversar.", "destino": "seco"}
      ]
    },
    "chegou":  {"falas": ["..."], "seguinte": "assuntos"},
    "assuntos":{"pergunta": "O que você quer perguntar?",
                "escolhas": [{"texto": "Sobre o rio", "destino": "rio"}]},
    "rio":     {"falas": ["..."], "seguinte": "assuntos"},
    "seco":    {"falas": ["..."], "fim": true}
  }
}
```

**Árvore, não corrente.** Um destino pode ser qualquer nó — inclusive um já
visitado, e é isso que fecha o ciclo "menu de assuntos → tópico → menu" sem
nenhuma estrutura extra. O destino reservado `"fim"` encerra a conversa.

Precedência ao acabarem as falas de um nó: `escolhas` › `seguinte` › fim.

### Inícios condicionais (`inicios`)

Por onde a conversa **abre** pode depender do mundo:

```json
"inicio": "raiz",
"inicios": [
  {"se": {"nao": {"bandeira": "tutorial_pesca_concluido"}}, "no": "licao"}
]
```

A **primeira** regra cuja condição passa substitui `inicio`; nenhuma passando, vale
`inicio` (`ArvoreDialogo.inicio_para(estado)`, chamado por `SessaoDialogo.iniciar()`).
É o "na primeira vez ele te chama para a lição; depois, conversa normal" sem um
nó-desvio vazio na raiz. Uma *variante* não serviria: ela troca as falas de um nó,
não o caminho inteiro. Regra sem `se` é recusada pela validação — ela venceria
sempre e `inicio` viraria texto morto.

### Entradas externas (`entradas`)

```json
"inicio": "apresentacao",
"entradas": ["apresentacao", "ensina_roda", "ensina_arremesso", "tentar_de_novo", "despedida", "pulou"]
```

Nós abertos **por fora** da árvore — hoje, pelo tutorial, que fala pela boca do
Anselmo com uma árvore própria (`anselmo_tutorial.json`) e abre direto no nó do
passo em que está:

```gdscript
dialogos.conversar_com(npc, "anselmo_tutorial", "ensina_roda")
```

Nenhum outro nó aponta para eles; declará-los em `entradas` é o que impede a
validação de chamá-los de órfãos — e, no sentido inverso, o que faz um órfão *de
verdade* continuar sendo apontado. Inícios condicionais contam do mesmo jeito.

### Condições (`se`)

```json
{"bandeira": "sabe_da_pesca"}              {"visitou": "ribeira"}
{"bandeira": "moedas", "pelo_menos": 10}   {"falou_com": "anselmo"}
{"item": "isca_frutada", "pelo_menos": 1}  {"viu": ["anselmo", "rio"]}
{"nao": {...}}   {"todos": [...]}   {"algum": [...]}
```

Servem em três lugares: escondendo uma **escolha**, trocando as falas de um nó
(**variantes**) e — no futuro — barrando um serviço.

A **ordem importa e é deliberada**: a variante de um nó é resolvida *antes* de o
nó ser marcado como visto. Sem isso, `{"falou_com": "anselmo"}` já seria
verdadeiro na primeira fala do próprio Anselmo, e a saudação de reencontro
apareceria na apresentação. (Esse bug existiu e foi pego pelo teste.)

### Efeitos

```json
"efeitos": {
  "definir": {"conheceu_anselmo": true},
  "somar":   {"moedas": -5},
  "visitar": "ribeira",
  "servico": {"tipo": "loja", "loja": "padaria"}
}
```

Aplicados ao **entrar** num nó, e ao escolher uma opção antes do salto. Nunca ao
sair — é por isso que fechar a caixa com ESC no meio de uma fala não deixa efeito
pendente.

## Provedores: como loja, missão e hora do dia entram sem mexer aqui

`EstadoMundo` guarda bandeiras. Uma condição que pergunta por algo que **não**
mora nele (quantos itens o jogador tem, quantas criaturas capturou) é resolvida
por um `Callable` registrado de fora:

```gdscript
estado.registrar_provedor("item",
        func(id): return encontros.inventario.quantidade(id))
estado.registrar_provedor("capturadas",
        func(_c): return encontros.inventario.colecao.size())
```

É o que mantém `regras/` sem nenhuma referência a `presentation/encontro/`, e o
que faz um domínio novo (`"missao"`, `"hora"`) custar **uma linha na cena**.

## Quem manda na entrada

Um só dono por vez, e a coordenação fica na cena (`presentation/exploracao/mundo.gd`),
que é quem já orquestrava HUD e encontro:

```
GerenciadorDialogo.permissao  →  "posso começar?"   (a cena responde)
GerenciadorDialogo.suspender()→  "saia de cena"     (mapa aberto, encontro)
Jogador.congelar(true/false)  →  quem tem o controle do personagem
```

O encontro **não precisou mudar**: a detecção dele conta *distância andada*, e
durante a conversa o jogador está congelado — logo não anda e não sorteia.

Dentro da conversa, o `GerenciadorDialogo` é o único `_unhandled_input`: ele
oferece o evento ao menu primeiro e só depois o trata como "avançar". Com dois
nós lendo `ui_accept`, uma confirmação avançaria a fala **e** escolheria a opção
no mesmo quadro.

## Detecção por distância, não por `Area2D`

`PontoDeEncontro` usa área porque a pergunta lá é "o jogador está *dentro* do
mato?". Aqui a pergunta é "*qual* NPC está mais perto e dentro do alcance?", e
duas áreas sobrepostas não respondem isso — `body_entered` dispara em ordem de
física, não de distância. Um laço por quadro sobre meia dúzia de NPCs custa menos
que duas áreas por NPC.

A distância é medida **em células do chão** (`Npc.distancia_em_celulas`), com a
projeção isométrica desfeita: um círculo na tela seria uma elipse no chão, e dar
para falar de mais longe pelo norte do que pelo leste.

## O que NÃO está implementado, de propósito

| gancho | estado |
|---|---|
| **pesca** | **atendido.** Na 1ª conversa o Anselmo pede `{"servico": {"tipo": "tutorial", "tutorial": "pesca"}}` e a cena entrega ao `GerenciadorTutorial` (`presentation/tutorial/`); depois, "Posso pescar agora?" pede `{"tipo": "pesca"}`, que a cena responde com a dica de como pescar |
| **loja** | padaria e fazenda oferecem a opção; o pedido chega pelo mesmo caminho e ainda vira uma nota no HUD |
| **missão / relacionamento / agenda** | nada implementado; o lugar deles é uma bandeira no `EstadoMundo` e um provedor |
| **save** | `EstadoMundo.para_dicionario()/de_dicionario()` vão no save da partida (seção `estado_mundo`, registrada pela cena) — inclusive `tutorial_pesca_concluido` |
