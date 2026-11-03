# Tutorial — a lição de pesca do Anselmo

Tutorial como **sequência de passos em dado**. A ordem, as dicas e o que cada passo
espera moram em `autoral/tutoriais/<id>.json`; as falas do NPC, numa árvore de
diálogo comum (`autoral/dialogos/anselmo_tutorial.json`). O código só executa —
mudar a lição, ou traduzi-la, é editar esses dois arquivos.

```bash
godot --headless --path . -s res://tools/test_tutorial.gd   # sequência + Anselmo + glifos
godot --headless --path . -s res://tools/test_dialogo.gd    # inícios/entradas das árvores
```

## Arquivos

| arquivo | papel |
|---|---|
| `regras/sequencia_tutorial.gd` | `SequenciaTutorial` — carrega, **valida** e percorre os passos (puro, sem engine) |
| `gerenciador_tutorial.gd` | `GerenciadorTutorial` — abre as conversas, mostra as dicas, recebe eventos, aplica efeitos, cuida do pulo |
| `dica_tutorial.gd` | `DicaTutorial` — `CanvasLayer` 92: dica no topo, aviso `[P] pular lição`, pergunta "Tem certeza?" |

Dados (Camada 1, autoral):

- `autoral/tutoriais/pesca.json` — os passos e os textos de interface
- `autoral/dialogos/anselmo_tutorial.json` — as falas de cada passo (`entradas`)
- `autoral/dialogos/anselmo.json` — `inicios` desvia a 1ª conversa para `licao`

## Como a lição começa

```
jogador fala com o Anselmo
  └─ anselmo.json: "inicios" → sem a bandeira tutorial_pesca_concluido, abre em "licao"
       └─ nó licao: {"servico": {"tipo": "tutorial", "tutorial": "pesca"}}
            └─ GerenciadorDialogo.servico_pedido → mundo.gd → tutorial.iniciar("pesca", npc)
                 └─ espera a fala da licao fechar → passo 1 (apresentacao)
```

Depois de concluída **ou pulada**, a bandeira está posta: o Anselmo volta a abrir
em `raiz`, e o menu de assuntos oferece **"Me ensina a pescar de novo?"**, que pede
o mesmo serviço. A bandeira mora no `EstadoMundo`, logo **o save já a guarda**
(seção `estado_mundo`) — o tutorial não tem seção própria.

## Um passo

```json
{"id": "equipar",
 "ao_iniciar": {"desequipar": true},
 "conversa": "ensina_roda",
 "dica": "Segure [Q] para abrir a roda de itens...",
 "esperar": {"evento": "item_equipado", "valor": "vara_de_pesca"},
 "se_falhar": "arremesso",
 "ao_concluir": {"dar_itens": {"minhoca": 5}, "concluir": true}}
```

1. **entra** — sinal `passo_iniciado`, efeitos `ao_iniciar`;
2. **conversa** (se houver) — aberta pelo `GerenciadorDialogo` com a árvore do
   tutorial, no nó pedido; o passo segue quando ela fecha;
3. **espera** (se houver) — mostra a `dica` no topo e aguarda o evento; sem
   `esperar`, o passo conclui assim que a conversa acaba;
4. **sai** — efeitos `ao_concluir`, próximo passo.

| eventos (`notificar`) | quem dispara (ligado em `mundo.gd`) |
|---|---|
| `item_equipado` (valor = id) | `Jogador.item_equipado_mudou` |
| `pesca_iniciada` · `arremessado` · `silhueta_surgiu` | sinais de mesmo nome do `GerenciadorPesca` |
| `fisgado` · `falhou` | `peixe_fisgado` · `pesca_falhou` |

| efeitos | o que fazem |
|---|---|
| `dar_itens` `{id: n}` | `Bolsa.adicionar` + sinal `nota("Recebeu: X ×n")` — só se algo entrou |
| `definir` `{bandeira: valor}` | `EstadoMundo.definir` |
| `desequipar` `true` | sinal `desequipar_pedido` (a cena desequipa o jogador) |
| `concluir` `true` | marca `bandeira_concluido` |

**Falha.** `falhou` num passo com `se_falhar` volta ao passo indicado e mostra a
conversa `tentar_de_novo` **no lugar** da conversa dele — quem cancelou o lance
precisa de "tente outra vez", não da explicação inteira do arco de novo. Num passo
sem `se_falhar`, `falhou` é ignorado (cancelar no arco, antes de lançar, não
desfaz nada).

**Eventos só contam enquanto o passo espera.** Durante a conversa do passo o
jogador está congelado, e nada do que acontecer pode pulá-la.

## Conversa pendente

Uma conversa só abre quando nada mais tem o controle. A primeira é pedida *dentro*
da fala do Anselmo que chamou a lição; a despedida, no quadro em que o peixe é
fisgado, com a pesca ainda na tela. Em vez de cada caso saber esperar o seu, o
pedido fica guardado e `_process` tenta `conversar_com()` a cada quadro até a
`permissao` da cena deixar. Abrir no quadro seguinte também evita abrir uma
conversa de dentro do `conversa_terminada` da anterior.

Falar de novo com o Anselmo no meio da lição **não recomeça** nada: `iniciar()`
com o mesmo tutorial em curso reabre a conversa do passo corrente (o lembrete do
que fazer agora) e devolve `true`. A fala de chamada, nesse caso, é a variante
"Vamos de onde a gente parou" (`{"viu": ["anselmo", "licao"]}`).

## Pular

`pular_tutorial` (**P**) abre "Pular a lição de pesca? Tem certeza?". A pergunta
**pausa a árvore** (`get_tree().paused`), como o menu de pausa — com ela correndo,
a linha continuaria sendo recolhida atrás da pergunta. A `DicaTutorial` roda com
`PROCESS_MODE_ALWAYS` e responde por teclado, mouse e controle com o mesmo
`MenuEscolhas` do diálogo. "Não" vem primeiro e é onde o cursor nasce; ESC = "não".

Confirmado, `pular()` aplica `ao_pular.efeitos` — **sempre entrega a vara** e
conclui —, fecha a conversa do tutorial que estiver aberta e deixa pendente a
conversa `pulou`. Os efeitos vêm antes da conversa: se o jogo for salvo enquanto
ela espera a pesca acabar, a lição já consta como feita.

`permissao_pulo` (Callable) é onde a cena barra o P com outra coisa na frente
(roda de itens aberta, mapa).

## Validação

`SequenciaTutorial.validar(arvore)` recusa, entre outros: evento ou efeito
desconhecido, id de passo repetido, chave de passo escrita errada (`"esprar"`),
`se_falhar` para passo inexistente, `dica` sem `esperar` (nunca apareceria),
conversa que não existe ou não está em `entradas`, molde de `recebeu` sem `%s` e
`%d`. O `GerenciadorTutorial` **não começa** um tutorial inválido — um passo
esperando um evento que ninguém emite prenderia o jogador numa dica eterna.

## Integração (o que `mundo.gd` liga)

```gdscript
tutorial = GerenciadorTutorial.new()
add_child(tutorial)
tutorial.preparar(dialogos, estado_mundo)
tutorial.nota.connect(_nota)
tutorial.desequipar_pedido.connect(func(): jogador.equipar(null))
tutorial.tutorial_iniciado.connect(func(_id): pesca.modo_tutorial = true)
tutorial.tutorial_concluido.connect(func(_id, _pulado): pesca.modo_tutorial = false)
jogador.item_equipado_mudou.connect(func(id): tutorial.notificar("item_equipado", id))
pesca.arremessado.connect(func(_f, _z, _d): tutorial.notificar("arremessado"))
# ... pesca_iniciada, silhueta_surgiu, peixe_fisgado -> "fisgado", pesca_falhou -> "falhou"
# _on_servico_pedido: tipo "tutorial" -> tutorial.iniciar(pedido.tutorial, npc)
```

## Fora do escopo, de propósito

| | |
|---|---|
| **progresso salvo no meio** | não há: quem salva no meio da lição recomeça do primeiro passo ao falar de novo com o Anselmo (a vara não é entregue duas vezes — não empilha) |
| **recompensa a cada repetição** | repetir a lição dá as minhocas de novo; o efeito está no dado (`despedida.ao_concluir`) e sai de lá se isso virar problema |
