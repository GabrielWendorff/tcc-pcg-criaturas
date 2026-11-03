# Sistemas globais

O que vive **fora** de qualquer cena, porque tem tempo de vida maior que o dela.

```bash
godot --headless --path . -s res://tools/test_save.gd    # regra + disco + autoload
```

## Por que este diretório existe

O projeto não tinha autoload nenhum até aqui, e isso era uma qualidade: cada cena
monta o que precisa e nada é global por conveniência. O save quebra a regra por
um motivo que nenhum sistema anterior tinha — ele existe **antes** da cena de
jogo (o menu lê os slots sem montar o mundo) e **continua existindo depois**
dela (a seed atravessa menu → mundo → menu). Um dado com tempo de vida maior que
o da cena não cabe dentro de uma cena.

A régua para entrar aqui é essa, e só essa. Um sistema que nasce e morre com a
cena do mundo (encontro, diálogo, mapa) **não** entra.

## Arquivos

### Regra — `regras/`, sem engine, testável fora de cena

| arquivo | papel |
|---|---|
| `semente.gd` | `Semente` — texto → seed (RF01) e sorteio de seed nova |
| `definicao_opcao.gd` | `DefinicaoOpcao` — a declaração de uma opção (booleana ou escolha) |
| `item_jogo.gd` | `ItemJogo` — a ficha de um item, envelopando a mecânica quando há; `mao`/`uso`/`equipavel()` para o equipamento |
| `catalogo_itens.gd` | `CatalogoItens` — as duas fontes de item num namespace só |
| `criatura_salva.gd` | `CriaturaSalva` — uma criatura do jogador, como ela vai para o disco |
| `dados_partida.gd` | `DadosPartida` — **o formato do save**, com versão e migração |
| `arquivo_save.gd` | `ArquivoSave` — a única classe do projeto que toca em disco |

### Autoloads

| nome | script | o quê |
|---|---|---|
| `Save` | `gerenciador_save.gd` | partida em curso + os três slots |
| `Opcoes` | `opcoes.gd` | configurações do jogador, em `user://opcoes.json` |
| `Bolsa` | `bolsa.gd` | catálogo de itens + quantidades — ver `presentation/bolsa/README.md` |

Previsto pela etapa seguinte: `Equipe` (time ativo e depósito).

A ordem em `project.godot` importa: `Bolsa._ready()` registra uma seção no
`Save` e escuta `Save.partida_iniciada`, então `Save` vem antes.

## Opções: acrescentar uma é acrescentar uma entrada

Nenhum nome de opção aparece em `painel_opcoes.gd`. A tela se constrói varrendo
`Opcoes.DEFINICOES`; a persistência grava as chaves que encontrar; a validação
sai do tipo declarado. Dois tipos existem — `BOOLEANA` e `ESCOLHA` — porque um
só não provaria que a estrutura é extensível.

```gdscript
{"id": "tremor_camera", "rotulo": "Tremor de câmera", "padrao": true}
{"id": "velocidade_texto", "padrao": "normal", "valores": [
    {"id": "lento", "rotulo": "LENTO", "dado": 26.0}, ...]}
```

O campo `dado` separa a opção da sua apresentação: *"Rápido"* é o que o jogador
lê, `80.0` é o que a caixa de diálogo põe em caracteres por segundo. Sem ele,
cada consumidor teria um `match` por id espalhado pelo código.

**A opção é consultada no ponto de entrada, não em cada chamador.**
`CameraExploracao.tremer()` pergunta a `Opcoes` no instante em que o tremor
começaria — e com isso o encontro, a pesca e qualquer sistema futuro respeitam
"desligar tremor de câmera" sem saber que a opção existe. Um `if` esquecido num
chamador novo seria um defeito de acessibilidade descoberto justamente por quem
desligou a opção porque precisava.

**Nenhuma opção toca o modelo generativo.** Desligar os encontros aleatórios
muda se o jogo apresenta uma criatura, nunca qual criatura a seed produz — o
bestiário de uma `world_seed` é o mesmo com qualquer configuração (RF03), e
`tools/test_bolsa.gd` verifica isso.

## Opções ficam fora do save da partida

`user://opcoes.json`, separado dos slots: uma opção vale para o **jogador**, não
para o mundo. Trocar de slot não pode religar um efeito que ele desligou, e
apagar um save não pode devolver um tremor de câmera que ele não quer ver.

## O save não guarda as criaturas

Guarda o **índice** de cada uma no bestiário e a **seed do mundo**. Elemento,
animal base, porte, paleta, matiz, morfologia e variantes são recalculados na
carga, rodando o mesmo `GeradorCriaturas` com a mesma `world_seed`.

```json
{"id": 42, "seed": 123456789, "nivel": 5, "xp": 0, "hp": -1, "apelido": ""}
```

É RF03 virando formato de arquivo, e tem três consequências práticas:

1. **Tamanho.** Um depósito cheio custa seis números curtos por criatura em vez
   de todos os atributos repetidos.
2. **Coerência impossível de quebrar.** Nenhum campo do save pode contradizer o
   gerador, porque nenhum atributo gerado está no save. Recalibrar uma tabela
   condicional muda a criatura guardada junto — ela nunca vira um fóssil de uma
   versão antiga das tabelas.
3. **Validação de graça.** Um save cuja seed não bate com a do mundo é detectado
   na hora, e não três telas depois.

## Escrita em três tempos

Um save é o único dado do jogo que o jogador não pode refazer.

```
1. grava slot_N.tmp
2. RELÊ o tmp e o reconstrói como DadosPartida  ──falhou?──▶ aborta, nada mudou
3. slot_N.json → slot_N.bak    e    slot_N.tmp → slot_N.json
```

Escrever por cima do arquivo bom e só então descobrir que o disco encheu é
exatamente o modo de falha que destrói a partida. Aqui o pior caso de uma queda
no meio do passo 3 é perder o save **mais novo**: o `.bak` é de antes, e `ler()`
cai nele sozinho — e avisa que caiu (`do_backup`), para o cartão do slot dizer
ao jogador que o save mais recente se perdeu.

**Danificado é um estado, não uma exceção.** `ler()` nunca falha e nunca derruba
o jogo: devolve `VAZIO`, `OK` ou `DANIFICADO` com o motivo por escrito, e o menu
desenha o cartão correspondente.

**JSON e não Resource.** Um `.tres` de save é código — `ResourceLoader` instancia
o que o arquivo mandar, e um save editado à mão vira vetor de execução. JSON é
dado inerte, lê-se num editor de texto e dispensa migração binária.

## Seções: como o save colhe o que não é dele

`Save` não conhece `MundoIso`, `InventarioJogador`, `EstadoMundo` nem `Equipe`.
Quem tem dado vivo registra como entregá-lo e como recebê-lo de volta:

```gdscript
Save.registrar_secao("jogador", _colher_jogador, _repor_jogador)
```

É o mesmo padrão dos provedores de `EstadoMundo`, e pelo mesmo motivo: um
sistema novo custa **uma linha na cena** e nenhuma alteração aqui. A
alternativa — o save importando cada sistema do jogo — é o que transforma um
formato de arquivo no nó mais acoplado do projeto.

A ordem de registro é a ordem de aplicação, e importa: `presentation/exploracao/mundo.gd`
registra `jogador` antes de `estado_mundo` porque repor a posição é o que define
em que região o personagem está.

**Seção permanente.** Um autoload (`Bolsa`, e depois `Equipe`) nasce antes de
qualquer cena e sobrevive a todas: a seção dele não pode ser esquecida na troca
de cena junto com as do mundo, ou o save gravaria uma bolsa vazia. Daí
`registrar_secao(..., permanente = true)`, e daí `esquecer_secoes()` derrubar só
as de cena. As permanentes registram primeiro (no `_ready` do autoload), que é
exatamente a ordem certa: a bolsa tem de estar reposta antes de o encontro ler o
estoque dela.

## Formato

```
user://saves/slot_1.json   ·   slot_1.bak   ·   slot_1.tmp (transitório)
```

```json
{
  "versao": 1,
  "mundo":   {"seed": 123456789, "seed_texto": "ribeira", "criaturas": 100},
  "jogador": {"mapa": "mundo", "celula": [60, 20], "direcao": "cima",
              "regiao": "ribeira", "regiao_nome": "Ribeira do Anselmo",
              "item_equipado": "vara_de_pesca"},
  "estado_mundo": {"versao": 1, "bandeiras": {}, "regioes": [], "vistos": {}},
  "itens": {"esfera_simples": 12, "osso": 4},
  "equipe": [], "armazenadas": [],
  "tempo_jogado": 0.0, "criado_em": "...", "salvo_em": "..."
}
```

**Campos ausentes não são erro** — todo `get()` tem padrão, e um save da Etapa 1
(sem time, sem depósito) carrega na Etapa 4 com time vazio. O que *é* erro está
em `DadosPartida._validar()`: sem seed de mundo não há partida para reconstruir.

**Versão.** Um save de versão menor passa por `_migrar()` (cadeia de degraus, um
por versão); um de versão **maior** é recusado, porque nenhuma migração adivinha
um campo que ainda não foi inventado.

**As configurações não estão aqui.** Elas vão para `user://opcoes.json` na Etapa
2, separadas de propósito: valem para o jogador, não para a partida — trocar de
slot não pode religar um efeito que ele desligou.

## `item_equipado`: campo opcional, sem versão nova

O id do item na mão do jogador (`""` = mãos livres), na seção `jogador`. Entrou
**sem** subir `VERSAO_ATUAL`: ausente lê como `""`, que é exatamente o estado de
quem nunca equipou nada — um save antigo carrega de mãos livres, sem migração.
Um degrau em `_migrar()` só se justifica quando o padrão de um campo novo **não**
é o valor certo para os saves antigos.

Grava-se o **id**, nunca o `ItemJogo`. Quem reequipa na carga (a cena do mundo)
confere se o item ainda está na bolsa: um save editado à mão, ou um item que
saiu da bolsa, cai em mãos livres em vez de pôr na mão algo que o jogador não
tem. E `Jogador.equipar()` recusa item sem o marcador `equipamento`.

Os campos de item que o acompanham — `mao`, `uso` e o marcador `equipamento` em
`ItemJogo` — não vão para o save: são dado do catálogo (Camada 1), iguais em
toda partida. Ver `presentation/bolsa/README.md`.

## `regiao_nome` é denormalização deliberada

O cartão do slot precisa ser legível **sem montar o mundo**, e o nome da região
só existe dentro de `autoral/mapas/mundo.json` — 133 KB de terreno cujo único
byte útil para o cartão é esse nome. O `id` continua sendo a verdade; o nome é
só o rótulo. Mesma razão de `seed_texto`.
