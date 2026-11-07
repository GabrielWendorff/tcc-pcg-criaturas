# Pendências

Decisões adiadas e trabalho conhecido em aberto. Não é backlog de ideias — só o
que já foi identificado como necessário e deliberadamente deixado para depois.

---

## 1 e 2. Encaixes nos corpos e arte de escamas, asas e nadadeiras — entregues

**Estado:** entregue em 07/11/2026. Os corpos declaram `dorso`, `dorso_tras` e `flanco`,
medidos na silhueta (o `tronco` virou desnecessário: as escamas são uma sobreposição
recortada por corpo, não uma peça ancorada). `tools/arte/gerar_apendices.py` desenha
asas e nadadeiras (4 modelos cada) e as escamas (4 modelos × 32 corpos). Ver
`arte/README.md`.

Em aberto: a asa é desenhada só do lado de perto; um par visível (a de trás, mais
escura, atrás do corpo) pediria uma camada abaixo do corpo no renderizador.

## 3. Silhueta do anfíbio ainda lê como bloco

**Estado:** em aberto, é a pior das 8.

Os três volumes (coxa, tronco, cabeça) continuam próximos demais em altura e o
contorno fecha num retângulo. As outras sete leem: gato e canino já se distinguem
(dorso inclinado e focinho longo no segundo), o réptil ganhou crista e postura
esparramada, o roedor está sentado, o inseto tem três segmentos e pernas
articuladas.

Limite conhecido do método: as silhuetas são desenhadas por composição de
primitivas geométricas em `corpos_tipos.py`. Isso garante 32 máscaras coerentes,
reprodutíveis e alinhadas à grade — mas tem teto de qualidade. Formas orgânicas
como uma rã agachada pedem pixel colocado à mão.

## 4. Coxim das garras lê como bloco

**Estado:** em teste pelo autor.

O `_pad()` de `tools/arte/gerar_garras.py` ocupa x=1..14, quase a largura do
quadro. Ele existe para dar leitura à forma isolada em 16×16, mas composto sobre
corpos estreitos (ave, canino) aparece como um bloco maciço em vez de se fundir ao
membro. Estreitá-lo é a correção provável.

Parâmetro de calibração relacionado: `escala_garra_sugerida` (hoje `0.375`,
gerado por `tools/arte/gerar_corpos.py`).

## 5. Pipeline vetorial órfão

**Estado:** mantido de propósito.

`BodyDef`, `CreaturePartLibrary`, `data/part_library.tres`,
`presentation/creature_renderer.gd`, `tools/gerar_part_library.gd` e
`tools/folha_corpos.gd` compõem o renderizador de silhuetas vetoriais anterior à
pixel art. Compilam e funcionam, mas nenhum caminho ativo os usa.

Ficam no lugar como referência. Se um dia incomodarem, mover para `old/` em vez de
apagar — a comparação entre as duas abordagens de silhueta é material do artigo.

## 6. Captura automatizada do visualizador

**Estado:** resolvido parcialmente.

`tools/screenshot.gd` precisa de display real — em `--headless` o `get_texture()`
não devolve imagem. Funciona apontando para a sessão X:

```bash
DISPLAY=:0 SHOT_PATH="user://shot.png" \
  godot --display-driver x11 --rendering-driver opengl3 \
  res://presentation/bestiario_viewer.tscn -s res://tools/screenshot.gd
```

`SHOT_PATH` precisa ser `user://` ou `res://`: `save_png` recusou caminho absoluto
fora do projeto.

Mesma limitação em `tools/screenshot_mundo.gd` e `tools/screenshot_encontro.gd`
(este captura os seis momentos do roteiro de encontro), que usam `SHOT_DIR`.

## 7. Mundo jogável — o que ficou de fora de propósito

**Estado:** encontro e captura entregues (2026-09-04); **NPCs, diálogo, mundo
expandido e mapa geral entregues (2026-09-16)**; **pesca, item na mão, roda de
itens e a lição do Anselmo entregues (2026-10-27, item 11)**. O resto segue em
aberto.

O mundo tem hoje quatro regiões contíguas numa grade 96×88 (vila, ribeira,
distrito industrial, sítio), 16 zonas de encontro, 15 construções, duas pontes e
cinco NPCs conversáveis. `presentation/dialogo/` entrega árvore de diálogo com
ramificação, condições, efeitos e estado de mundo; `presentation/mapa/` entrega a
carta geral (M) rasterizada do próprio terreno.

Continua fora, por decisão de escopo: **loja, missões, arbustos interativos e
batalha de verdade.** (Save em disco entrou em 2026-10-02, item 9; pesca em
2026-10-27, item 11.)

Pontos concretos em aberto:

- **Loja (gancho pronto, sem implementação).** Padaria (Bento) e sítio (Dulce)
  já oferecem a opção de comprar, e o efeito `{"servico": {"tipo": "loja"}}`
  chega à cena — que responde com uma nota no HUD. Quando a loja existir, ela
  entra em `mundo.gd::_on_servico_pedido`; nenhuma árvore de diálogo muda. É o
  caminho natural para repor dispositivos e iscas, que hoje só têm a carga
  inicial do JSON.
- **Pesca — entregue (2026-10-27, item 11).** O gancho foi atendido do jeito
  previsto: o pedido `{"servico": {"tipo": "tutorial"}}` da fala do Anselmo chega
  a `mundo.gd::_on_servico_pedido`, que entrega a lição ao `GerenciadorTutorial`;
  `{"tipo": "pesca"}` ("Posso pescar agora?") vira a dica de como pescar no HUD.
  Nenhuma árvore de diálogo precisou ser reescrita — só ganhou nós.
- **Save em disco.** `EstadoMundo.para_dicionario()/de_dicionario()` estão
  prontos e testados (bandeiras, regiões visitadas, nós de diálogo vistos), mas
  **nada escreve em arquivo**. Falta decidir o formato junto com o que mais
  precisa ser salvo: `InventarioJogador.colecao`, posição do jogador e a seed.
- **Batalha (RF06).** `presentation/batalha/` continua vazio. O `Atacar` do
  encontro derruba um valor de vigor e nada mais.
- **Missão, agenda e relacionamento.** Não implementados. O lugar deles é uma
  bandeira no `EstadoMundo` e um provedor registrado na cena — a condição de
  diálogo `{"missao": "...", "igual": "ativa"}` passa a funcionar sem que
  `presentation/dialogo/regras/` mude.
- **Interiores de casa.** As 15 construções têm colisão e um campo `papel`; não
  há interior. Entrar numa casa exigiria uma segunda cena — e aí, sim, um
  carregamento, que é o que o mundo contínuo evitou até aqui.
- **Arte de arbusto.** Não foi gerada: seria asset sem uso. Hoje a zona de
  encontro é a área de grama alta do terreno, sem arbusto interativo.
- **Ícones de item.** `IconeCaptura` desenha as 15 formas por primitivas
  geométricas em `_draw()`. Funciona e mantém a política de arte gerada, mas tem
  o mesmo teto de qualidade das silhuetas (item 3).
- **Coleção de capturadas.** Vive em `InventarioJogador.colecao`, em memória.
  Não há tela de coleção.
- **`window/stretch/scale_mode`.** Continua fracionário, e **pesa mais a cada
  tela nova**: a caixa de diálogo e o mapa geral usam a mesma fonte de bitmap da
  interface de encontro, e uma janela em tamanho não múltiplo de 1152×648 borra o
  *texto*. Pôr `"integer"` resolveria; muda o enquadramento do visualizador do
  bestiário, então precisa ser avaliado nas quatro telas juntas.
- **Cobertura da fonte pixel.** 127 glifos: ASCII, os acentuados do português e
  os sinais usados na interface — sem `…`, por exemplo. `tools/test_dialogo.gd`
  falha se algum texto de diálogo pedir um glifo ausente; glifo faltando não dá
  erro na engine, sai como caixa vazia.
- **Densidade do interior do mundo.** As faixas entre regiões (leste da ribeira,
  sul do sítio) são propositalmente abertas — é onde a Camada 3
  (`procedural/ambiance/`) vai espalhar vegetação e pontos de interesse a partir
  da seed. Hoje elas leem como campo vazio em alguns trechos.
- **Grade única de altura.** Os penhascos da borda dão *leitura* de relevo, mas
  o mapa é plano: não há duas alturas pisáveis nem rampas.

## 8. Bordas do mapa: colisão de tile não segura, e por quê

**Estado:** contornado, vale registrar.

A fronteira de um bloco de losangos é uma serra de faces a 26,57°, nunca uma
parede reta. Um corpo empurrado contra ela **escorrega ao longo da serra** em
vez de parar — verificado com simulação de física: um `CharacterBody2D` lançado
na horizontal contra um bloco de tiles sai por cima dele em ~70 quadros, tanto
em `GROUNDED` quanto em `FLOATING`.

Isso é o comportamento desejado no lago (contornar a margem) e inútil como
limite de mundo. Daí `MundoIso.LimitesDoMapa`: quatro paredes **retas** ao longo
das arestas do losango do mapa. Quem for criar outra área precisa das duas
coisas — a colisão de tile não substitui as paredes.

---

## 9. Menu principal e save em disco — entregue

**Estado:** entregue (2026-10-02). Substitui o item "Save em disco" da seção 7.

`sistemas/` (novo diretório) e `presentation/menu/` (novo) entregam menu
principal, três slots de save em `user://saves/` e a escolha da seed pelo jogador
— RF01 e RF03 deixam de ser uma constante no código e viram tela. Ver
`sistemas/README.md` e `presentation/menu/README.md`.

O que isso **fecha** da seção 7:

- **Save em disco.** `EstadoMundo.para_dicionario()/de_dicionario()`, que estavam
  prontos e sem uso, agora são uma seção do save. `InventarioJogador` ganhou
  `quantidades()`/`repor()` pelo mesmo motivo. As criaturas capturadas vão para
  `armazenadas`.

O que **continua em aberto** da seção 7: loja, missões, arbustos interativos,
batalha de verdade, interiores de casa. (A pesca saiu desta lista em 2026-10-27 —
item 11.)

### Pontos concretos em aberto nesta etapa

- **Menu de pausa.** Não existe. Hoje a única forma de gravar durante a partida é
  **F5**, que é provisório e está marcado como tal em `mundo.gd::_salvar_agora`.
  O lugar definitivo é o item "Salvar" do menu de pausa.
- **Tela de opções.** A entrada já está no menu principal e responde com uma nota
  "Etapa 2". O menu nasceu com a forma final para que nenhuma tela precise ser
  remontada quando ela existir.
- **Time e depósito.** `DadosPartida` já declara `equipe` e `armazenadas`, mas só
  o segundo é preenchido: não há conceito de time ativo. A seção `criaturas` de
  `mundo.gd` é provisória e será substituída pela do gerenciador de equipe. Saves
  gravados agora continuam válidos — depósito é exatamente onde uma criatura sem
  time deve estar.
- **Nível, experiência e HP.** `CriaturaSalva` já tem os três campos, todos
  parados no padrão. Existem desde já porque acrescentar campo a um formato
  versionado é barato e mudar o significado de um save já gravado não é.
- **`window/stretch/scale_mode` fracionário** (seção 7) **pesa mais uma tela.** O
  menu usa a mesma fonte bitmap das demais, e o fundo é uma imagem 192×108
  ampliada 6× — em janela que não seja múltipla de 1152×648, tanto o texto quanto
  o fundo saem reamostrados. São cinco telas pedindo `"integer"` agora.
- **Nome do jogo.** O título do menu vem de `application/config/name` em
  `project.godot`, hoje "RPG PCG - Coerencia Semantica", que é nome de trabalho
  acadêmico e não de jogo. Trocar lá troca no menu, e nenhuma tela fica para trás.
- **Autoloads.** `Save` é o primeiro do projeto. A régua para entrar em
  `sistemas/` está escrita no README de lá: tempo de vida maior que o da cena.
  `Opcoes`, `Bolsa` e `Equipe` virão pelas etapas 2, 3 e 4.

---

## 10. Opções e bolsa — entregue

**Estado:** entregue (2026-10-02).

Dois autoloads novos em `sistemas/` — `Opcoes` e `Bolsa` — mais o menu de pausa
e a tela de itens. Ver `sistemas/README.md` e `presentation/bolsa/README.md`.

O que isso **fecha**:

- **Menu de pausa** (pendência do item 9). ESC pausa a árvore e oferece
  continuar · bolsa · opções · salvar · menu principal. F5 continua como atalho.
- **Tela de opções** (pendência do item 9). Quatro opções, construídas a partir
  de `Opcoes.DEFINICOES`; a mesma tela serve ao menu principal e à pausa.
- **Inventário com categorias, descrição e ícone.** `InventarioJogador` não foi
  reescrito: a `Bolsa` o envelopa e acrescenta o catálogo.

### Em aberto nesta etapa

- **Efeitos de item não são consumidos.** `{"tipo": "curar", "valor": 30}` está
  no dado e na ficha; nenhum sistema interpreta, porque não há alvo antes da
  batalha (Etapa 5). Usar uma poção responde com uma recusa escrita.
- **`IconeCaptura` tem o nome errado.** Ele recorta qualquer id de
  `arte/itens/itens.png` e agora desenha poções e a vara de pesca, que não têm
  nada a ver com captura. Renomear custa um sed em três arquivos; ficou de fora
  para não misturar refatoração com entrega.
- **Sem loja.** A bolsa só recebe pela carga inicial e pela captura. O gancho
  `{"servico": {"tipo": "loja"}}` continua chegando em `mundo.gd` e agora tem
  onde depositar: `Bolsa.adicionar`.
- ~~**A vara de pesca existe e não faz nada.**~~ **Resolvido em 2026-10-27
  (item 11).** Quem a dá é o Anselmo, no primeiro passo da lição (ou ao pular a
  lição — quem pula também sai com a vara). Na mão, `F` de frente para a água
  pesca. Ela continua começando fora da bolsa.
- **Depósito/time.** A seção `criaturas` do save continua provisória — tudo vai
  para `armazenadas`. Etapa 4.

---

## 11. Pesca, item na mão, roda de itens e a lição do Anselmo — entregue

**Estado:** entregue (2026-10-27). Ver `presentation/pesca/README.md`,
`presentation/equipamento/README.md`, `presentation/tutorial/README.md` e a
entrada de mesma data em `docs/mudancas-estruturais.md` (o modelo **não** mudou).

O que entrou:

- **Pesca** (`presentation/pesca/`, `data/pesca/`): `OCIOSO → ARREMESSO →
  RECOLHENDO → FISGADO | FALHOU → OCIOSO`; arco de força em meio círculo, corte
  lateral da água com o mouse (X = velocidade, Y = altura), silhueta com a
  máscara do corpo da criatura, medidor de interesse, deriva desligável. O perfil
  de cada criatura é **derivado** da morfologia já sorteada.
- **Item na mão e roda de itens** (`presentation/equipamento/`): `SlotDaMao` no
  jogador, ordem de desenho por ordem de filho (sem `z_index`); roda radial no
  **Q** com o que a bolsa tem marcado como `equipamento`; o item na mão vai para o
  save (`DadosPartida.item_equipado`).
- **Lição do Anselmo** (`presentation/tutorial/`, `autoral/tutoriais/pesca.json`):
  sequência de passos em dado, dica no topo, **P** pula com "Tem certeza?" (a vara
  é entregue mesmo assim); bandeira `tutorial_pesca_concluido` no `EstadoMundo`.
- **Integração** em `presentation/exploracao/mundo.gd`: um dono da tela por vez
  (`_dono_da_tela`), HUD com "Q itens  F usar", HUD escondido no minigame, diálogo
  suspenso durante a pesca, `_ao_fisgar` como ponto de integração.
- **Testes:** `tools/test_pesca.gd` (regra, calibragem, RF03), `test_equipamento.gd`,
  `test_tutorial.gd` e `tools/test_pesca_integracao.tscn` — este roda como **cena**
  (`godot --headless --path . res://tools/test_pesca_integracao.tscn`), não sob
  `-s`, e joga a lição inteira no mundo de verdade. `tools/cena_teste_pesca.tscn`
  é o sandbox para calibrar no editor (F6).

### Em aberto nesta etapa

- **Captura ou batalha depois de fisgar.** `peixe_fisgado(criatura)` chega a
  `mundo.gd::_ao_fisgar`, que hoje só escreve "Fisgou ..." no HUD e no console. O
  caminho está desenhado e documentado lá: `pesca.encerrar_ao_fisgar = false`,
  abrir a batalha/captura com a criatura, `pesca.encerrar()` ao fim. Depende de
  RF06 (`presentation/batalha/` continua vazio).
- **A isca não influencia a pesca.** Toda isca de captura carrega o marcador
  `pesca` (`ItemJogo.de_captura`) e declara `tipos_preferidos`, e a lição dá 5
  minhocas de recompensa — mas o lance não consome isca nem muda
  `P(criatura | ponto)`. O lugar natural é um fator `w_isca(animal)` na roleta do
  `PontoDePesca` (como o bônus da `IscaCaptura` na captura) e o consumo no
  arremesso. Sem isso, a recompensa da lição é só estoque para a captura.
- **Arte final.** A vara, a lanterna e a pá são placeholders desenhados em
  `ItemNaMao._draw`; a troca por arte é uma linha no catálogo (`mao.textura` ou
  `mao.cena`). A silhueta usa a máscara do corpo pintada de escuro — nadadeiras,
  escamas e asas não aparecem nela pelo mesmo motivo do item 2.
- **Recolhimento só no mouse.** O arco e a roda funcionam no controle (botão 2,
  botão 9 e analógico na roda), mas o minigame lê só o mouse
  (`MinigameRecolhimento.fonte_de_entrada`). Um leitor do analógico entra ali,
  sem mexer na regra.
- **Calibragem sensível à largura da água.** A velocidade do perfil é o parâmetro
  mais sensível: fisgar consome trajeto, e os trechos de água do mapa têm mediana
  de 4–6 células. Hoje um arremesso médio fisga ~46% com jogo perfeito e um
  máximo ~95% — peixe pede arremesso longo. Subir a escala de velocidade deixa
  peixes inalcançáveis em água estreita (ver `data/pesca/perfil.json`).
- **Saves anteriores sem as ferramentas de exemplo.** Lanterna e pá de jardim
  entram na carga inicial; a seção `itens` do save repõe as quantidades gravadas,
  então um save antigo não as tem. Completar itens permanentes ausentes é decisão
  da `Bolsa` (`sistemas/bolsa.gd`), não obrigatória.
- **Progresso no meio da lição não é salvo.** De propósito: quem recarrega
  recomeça a lição ao falar com o Anselmo (a vara não é entregue duas vezes). E
  repetir a lição dá as 5 minhocas de novo — o efeito está no dado
  (`despedida.ao_concluir`) e sai de lá se isso virar problema.
- **`tools/test_bolsa.gd` continua sem compilar** (erro de parse pré-existente na
  linha 125). A expectativa da linha ~193 já foi atualizada para 3 equipamentos
  em estoque (vara + lanterna + pá); falta só o conserto do parse.
- **Tremor da fisgada** é `@export` no `GerenciadorPesca` (visual, como os demais
  parâmetros de nó), não um campo de `data/pesca/configuracao.json`.

---

## 12. Batalha, guardiã, vitória e derrota — entregue (fatia)

**Estado:** fatia jogável entregue em 2026-11-03. Ver `presentation/batalha/README.md`. Isto
fecha, da seção 7, a **batalha de verdade**; da seção 9, **time e depósito** e **HP**; da
seção 10, os **efeitos de item** e **depósito/time**; da seção 11, **captura ou batalha
depois de fisgar**.

### Em aberto nesta etapa

- **Faltam 2 guardiões e o duelo final** (até 16/11, pelo plano). Quem faz o duelo final
  ainda não foi decidido. Hoje `selos_para_vencer` é 1 e vencer a Dulce encerra o jogo.
- **Os percentis são medidos, não sentidos.** O simulador joga com IA. O valor da Dulce
  (0,9) sai dele, e pode estar errado para pessoas: conferir no playtest.
- **Encontro selvagem é caro.** Lutar até o fim custa em média 42% da vida. Sem loja, a
  reposição é a cura gratuita da Mirela, que pode ficar longe. Dado para o playtest.
- **Sem loja, poções acabam.** Continua fora do escopo; a cura da Mirela evita o jogo travar.
- **Bestiário no jogo: entregue em 06/11** (tecla N e pausa), com as 100 criaturas, ficha e
  marca nas capturadas. Ainda falta a **vitrine do algoritmo** (primários → probabilidades →
  derivados, e coerente ou atípica), que depende da nota por criatura do gerador v2.
- **Sem animação de golpe.** O alvo só treme. Polimento, depois da vitrine.
- **Testes ainda quebrados, de antes desta etapa:** `test_interacao` aborta sob `-s`,
  `test_bolsa` não compila, e `test_save` falha em `autoload registrado` (efeito do `-s`).
  `test_encontro` foi corrigido e virou cena. Convertê-los segue no plano, até 08/11.

