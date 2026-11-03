# Mudanças estruturais do algoritmo

Registro das alterações no **modelo de geração** — o que muda a Seção 3 do artigo.
Refatorações que não alteram o modelo não entram aqui.

---

## 2026-10-27 — Pesca: o modelo NÃO mudou

### O que mudou, e por que isto entra aqui mesmo assim

**Nada no modelo generativo.** `GeradorCriaturas`, `Criatura`, `data/*.json` (fora
de `data/captura/`, `data/itens/` e da pasta nova `data/pesca/`) e
`MetricasCoerencia` não foram tocados. A mesma seed produz o mesmo bestiário de
antes, criatura por criatura — e isso é verificado duas vezes:

- `tools/test_pesca.gd` regera o bestiário **depois** de calcular os perfis de
  pesca e compara: idêntico (RF03);
- `tools/test_pesca_integracao.tscn` compara o bestiário da cena jogável, já com a
  pesca montada, com o do gerador puro: as 100 criaturas, campo a campo, iguais.

RF04 e RF08 medem exatamente o mesmo objeto. O registro existe por dois motivos:

1. a pesca é mais uma **leitura** da saída do modelo que vira mecânica — o mesmo
   caso da afinidade de captura (2026-09-04), agora com uma mecânica inteira;
2. ela introduz uma **segunda distribuição criatura × lugar**, posterior à
   geração, com forma diferente da do encontro. A Seção 3 precisa saber que ela
   existe e que não é a mesma coisa.

### O perfil de pesca é derivado, não declarado

Cada criatura elegível (elemento `agua` **ou** animal `peixe`/`anfibio`) ganha
altura preferida, velocidade preferida, folgas e peso de sorteio **calculados**
dos atributos que o gerador já sorteou — `data/pesca/perfil.json`:

```
prof(c) = clamp( base + Δ_animal[a] + Δ_elemento[e] + Δ_porte[p]
                 + Σ_{t ∈ traços(c)} Δ_traço[t] + j₁ · variação )
vel(c)  = idem, com a sua tabela e j₂
tol_v(c) = max(mínimo, tol_base + Σ_{t ∈ traços(c)} Δtol[t])     (nadadeiras: −0,04)
peso(c) = base · w_porte[p] · w_elemento[e] · 0,9^|traços(c)|   → raridade por faixas
```

O ruído `j₁, j₂` sai de um RNG **próprio** da criatura
(`seed_individual + 0x9E5CA`): o perfil é determinístico e não consome nenhum
número do RNG do gerador. O que **emerge** das tabelas condicionais é o efeito
dos traços: com nadadeiras, a criatura é mais rápida e tem menos folga de
velocidade (0,34 × 0,28; 0,109 × 0,141). O contraste fundo/raso e rápido/lento
entre peixe e anfíbio vem sobretudo de `por_animal` em `perfil.json` (+0,14/+0,08
contra −0,20/−0,06): é declarado, não emergente. Números da seed de teste
(`123456789`, impressos por `tools/test_pesca.gd`):

| grupo | n | altura | velocidade | folga de velocidade | dificuldade |
|---|---|---|---|---|---|
| elegíveis | 36 de 100 | | | | |
| peixe | 12 | 0,75 | 0,38 | 0,120 | 16,2 |
| anfíbio | 11 | 0,41 | 0,23 | 0,113 | 18,4 |
| com nadadeiras (bestiário inteiro) | 28 | | 0,34 | 0,109 | |
| sem nadadeiras (bestiário inteiro) | 72 | | 0,28 | 0,141 | |
| nadadeiras sem × com escamas (só elegíveis) | 10 × 14 | | | 0,098 × 0,120 | |
| gelo/sombra/terra × fogo/ar/elétrico (bestiário inteiro) | 37 × 36 | 0,58 × 0,34 | | | |
| gelo/terra × fogo/ar/elétrico (só elegíveis; nenhuma sombra é elegível) | 11 × 6 | 0,62 × 0,53 | | | |
| compacto × esbelto/alongado (bestiário inteiro) | 21 × 57 | | 0,21 × 0,34 | | |
| compacto × esbelto/alongado (só elegíveis) | 6 × 20 | | 0,25 × 0,34 | | |

`dificuldade` é a média de `PerfilPesca.dificuldade()` (1/folga de altura +
1/folga de velocidade + 2·|altura − 0,5| + 2·|velocidade − 0,5|; menor = mais
fácil), a mesma métrica que escolhe o monstro do tutorial.

Raridade entre os elegíveis: 20 comuns, 10 incomuns, 6 raros. É a coerência
semântica do trabalho (RF04) aparecendo como **decisão de jogo**: o peixe nada
fundo e rápido, e por isso pede arremesso longo (`docs/pendencias.md`). As
escamas, muito prováveis em água+peixe, alargam as duas folgas e compensam as
nadadeiras; a criatura mais escorregadia é a que tem nadadeiras **sem** escamas
(tipicamente o anfíbio), e pela `dificuldade()` o peixe sai, em média, **mais
fácil** que o anfíbio. Vale como material de resultado, ao lado da afinidade de
captura, com uma ressalva: os contrastes de elemento e de porte valem no
**bestiário inteiro**. Entre as pescáveis, o eixo elemento é mascarado pelo
animal — os fogo e elétrico elegíveis são todos peixes (Δ peixe +0,14 de altura)
e os gelo são anfíbios (−0,20) —, e na pesca um Fogo-Peixe (#028/#093, 0,59–0,60)
ou um Eletrico-Peixe (#015/#048, 0,66–0,68) nada mais fundo que um Gelo-Anfibio
(#012/#014/#050, 0,45–0,51). Citar como resultado da pesca só as linhas "só
elegíveis".

### Onde a criatura aparece: por PESOS contínuos, não por filtro binário

O ponto de pesca (`data/pesca/pontos.json`: lago da vila, ribeira do Anselmo, rio
da fábrica) não lista criaturas — o bestiário muda com a seed. Declara pesos por
elemento e por animal, e a distribuição é calculada **sobre o bestiário já
gerado**:

```
P(c | ponto) = peso(c) · w_e(ponto, elemento(c)) · w_a(ponto, animal(c)) / Z,   c elegível
w_e(ponto, e) = elementos[e] se declarado, senão peso_fora (0,30–0,40)
w_a(ponto, a) = animais[a] se declarado, senão 1
```

e a silhueta só chega se, a cada 1,2 s de recolhimento, um sorteio passar em
`chance_surgimento (0,22) × multiplicador_surgimento(ponto)`.

A diferença em relação ao encontro (2026-09-04) é de **forma**, e é a que importa
descrever:

| | encontro no mato | pesca |
|---|---|---|
| suporte | o bestiário inteiro | só os elegíveis (36 de 100 na seed de teste) |
| preferência do lugar | filtro **binário** por elemento, ignorado com chance 0,15 | peso **contínuo** por elemento e animal |
| papel da criatura | nenhum: dentro do filtro, todas igualmente prováveis | `peso(c)`, derivado da morfologia, multiplica o habitat |
| amostragem | **mistura**: 1 `randf()` contra `chance_fora_da_regiao` (0,15) e depois 1 `randi()` uniforme no conjunto escolhido (preferidos ou bestiário inteiro), sem laço | **roleta**: exatamente um `randf()` por sorteio, sem laço |
| RNG | `world_seed + 0x5E7A` | `world_seed + 0x9E5CA0` (lance); `seed_individual + 0x9E5CA` (ruído do perfil) |

Duas consequências. A mistura produz uma distribuição **uniforme dentro do
conjunto favorecido** mais um piso uniforme sobre todos:

```
P(c | região) = 0,85 · [c ∈ F] / |F| + 0,15 / N    (F = preferidos da região, F ≠ ∅;
                                                     N = tamanho do bestiário; F = ∅ ⇒ 1/N)
```

Os pesos produzem uma preferência **graduada**, em que raridade (da morfologia) e
habitat (do lugar) se compõem por multiplicação. Nenhum dos dois tem laço; o
contraste de consumo é estreito: no encontro, a contagem de números depende de
`F` ser vazio (1 `randi()` sem preferidos, `randf()` + `randi()` com eles); a
roleta consome sempre 1 `randf()`. Por isso recalibrar os pesos de
criatura/habitat, com o ponto ainda tendo candidatos, muda **qual** criatura sai,
nunca **quantos** números foram consumidos. Já `chance_surgimento`,
`multiplicador_surgimento` e um ponto sem nenhum candidato mudam o consumo: os
dois primeiros decidem quantas roletas (e derivas, 4 números cada) um lance faz,
e o ponto vazio pula o sorteio de surgimento sem consumir nada.

Na seed de teste, com 2000 sorteios de uma roleta 1:2:7, o desvio máximo foi
0,020; os mais prováveis da ribeira são Agua-Peixe #016 (6%),
Agua-Peixe #072 (5%) e Agua-Inseto #056 (5%), e os do rio da fábrica,
Eletrico-Peixe #048 (8%) e Eletrico-Peixe #015 (6%).

Calibragem do minigame (`SimulacaoRecolhimento`, regra pura, mesma seed + mesmas
entradas ⇒ mesmo desfecho no mesmo instante):

| medida (`tools/test_pesca.gd`) | valor |
|---|---|
| fisgar com a política perfeita (silhueta → fisgado) | 3,18 s (mín. 3,00, máx. 3,38) |
| monstro foge com a política errada | 4,45 s (esperado 4,44 s) |
| ribeira, 300 arremessos máximos, política perfeita | 284 fisgados, 16 recolhidos, 0 fugas |
| ribeira, 300 arremessos médios, política perfeita | 139 fisgados, 161 recolhidos |
| arremesso médio (4,25 células) recolhido devagar | 1,54 silhuetas esperadas; 82% veem ao menos uma |

### O que NÃO é modelo, e por isso não muda a Seção 3

- `data/pesca/*.json` é **balanceamento de jogo**, em pasta separada pelo mesmo
  motivo de `data/captura/`: não é modelo probabilístico de geração e não deve
  ser lido como tal.
- A lição do Anselmo (`autoral/tutoriais/pesca.json`,
  `autoral/dialogos/anselmo_tutorial.json`) é **Camada 1**: fixa, sem seed. A
  bandeira `tutorial_pesca_concluido` mora no `EstadoMundo` e vai para o save
  pela seção que já existia.
- Item na mão e roda de itens (`presentation/equipamento/`) e a pesca e o tutorial
  (`presentation/pesca/`, `presentation/tutorial/`) são **Camada 4**. As quatro
  camadas da arquitetura continuam as mesmas; ganharam módulos dentro delas.

### O que isso exige da Seção 3 do artigo

Uma **nota**, não uma reescrita. A formulação do modelo continua correta. O que
falta declarar:

1. que o jogo aplica uma segunda distribuição posterior à geração,
   `P(criatura | ponto de pesca)`, **por pesos contínuos** e não por filtro
   binário, e que ela não entra nas métricas de coerência — RF04/RF08 continuam
   medindo o bestiário;
2. que o perfil de pesca é uma **leitura determinística** dos atributos derivados
   (RF04 virando mecânica), útil como exemplo na seção de resultados junto da
   afinidade de captura;
3. se a descrição da Camada 1 e da Camada 4 enumera módulos, acrescentar o
   tutorial em dado (Camada 1) e equipamento/pesca/tutorial (Camada 4).

Se algum dia o ponto de pesca passar a condicionar a **geração** (viés de
elemento ou de traço na seed da criatura), aí sim é mudança de modelo e exige
seção própria aqui, com a informação mútua medida contra a baseline. **Não é o
caso hoje.**

---

## 2026-09-16 — Mundo expandido, NPCs e diálogo: o modelo NÃO mudou

### O que mudou, e por que isto entra aqui mesmo assim

**Nada no modelo generativo.** `GeradorCriaturas`, `data/*.json` (fora de
`data/captura/`) e `MetricasCoerencia` não foram tocados: a mesma seed produz o
mesmo bestiário de antes, criatura por criatura. RF04 e RF08 medem exatamente o
mesmo objeto.

O registro existe por dois motivos de **escala**, que tocam a Seção 3 apenas como
atualização de números:

| | antes | agora |
|---|---|---|
| área jogável | 1 vila, 40×36 = 1.440 células | 4 regiões, 96×88 = 8.448 células |
| zonas de encontro | 8 | 16 |
| elementos favorecidos por região | 8 pares | 16 pares, cobrindo os 8 elementos |

A distribuição de encontro continua sendo a mesma de 2026-09-04:

```
P(criatura encontrada | região) ∝ 1 se elemento ∈ elementos_provaveis(região)
                                  (com chance_fora_da_regiao = 0,15)
```

Só o **suporte** dela cresceu: mais regiões, mais pares elemento/lugar. Não há
condicionamento novo, nem viés novo na geração.

### O que NÃO é modelo, e por isso não muda a Seção 3

NPCs, árvores de diálogo, estado de mundo e mapa geral são **Camada 1 (autoral)**
e **Camada 4 (apresentação)**. Nenhum deles recebe a seed, nenhum sorteia nada:
`autoral/npcs/npcs.json` e `autoral/dialogos/*.json` são conteúdo fixo, iguais em
toda partida. Se algum dia um NPC passar a comentar a criatura gerada (ler o
bestiário da seed), aí sim há o que registrar — seria conteúdo condicionado à
saída do gerador.

### O que isso exige do artigo

Uma **atualização de números** na descrição da área jogável e da distribuição de
encontro (Seção 3/4, onde a vila e as 8 zonas são citadas), não uma reescrita. A
formulação do modelo continua correta como está.

---

## 2026-09-04 — Encontro e captura; a região passa a filtrar QUEM aparece

### O que mudou no modelo — e o que não mudou

**As tabelas condicionais, o bestiário e as métricas de RF04/RF08 estão
intactos.** `GeradorCriaturas`, `data/*.json` (fora de `data/captura/`) e
`MetricasCoerencia` não foram tocados; a mesma seed produz o mesmo bestiário de
antes, criatura por criatura.

O que passou a existir é uma **distribuição de encontro** sobre esse bestiário
pronto:

```
P(criatura encontrada | região) ∝ 1 se elemento ∈ elementos_provaveis(região)
                                  (com chance_fora_da_regiao = 0,15 de ignorar o filtro)
```

`PontoDeEncontro.elementos_provaveis` — declarado pelo mapa desde 2026-09-02 e
até aqui lido por ninguém — agora seleciona, **por filtro com mistura
(`chance_fora_da_regiao`) sobre o bestiário já gerado**, qual criatura aparece em
cada zona.

A distinção é a que importa para o artigo:

| | antes | agora |
|---|---|---|
| como a criatura é **gerada** | P(derivado \| primário) | **idêntico** |
| onde a criatura **aparece** | não existia | P(criatura \| região) |

Não é um novo condicionamento dentro da criatura. É um condicionamento entre
**criatura e lugar**, aplicado depois da geração, e implementado como
filtro com mistura (`chance_fora_da_regiao`) — não como um viés novo no gerador.

### O que isso exige da Seção 3 do artigo

Uma **nota**, não uma reescrita. A Seção 3 continua descrevendo corretamente o
modelo generativo. O que falta declarar é que o jogo aplica uma segunda
distribuição, posterior e independente, ao escolher o encontro — e que ela não
entra nas métricas de coerência atuais.

Se algum dia a região passar a condicionar a **geração** (viés de elemento na
seed da criatura), aí sim é mudança de modelo: exigiria seção própria aqui, com
`I(região; elemento)` medida contra baseline, como as demais. **Não é o caso
hoje.**

### A afinidade de captura reaproveita a morfologia, sem tabela nova

A dificuldade de captura não é declarada por espécie. Cada traço morfológico tem
um fator de evasão em `data/captura/balanceamento.json`, e quais traços a criatura
possui já foi decidido por `P(traço | animal, elemento)` na geração. A mecânica
lê a saída do modelo:

- `água + peixe` → escamas (0,90) e nadadeiras (0,92) → evasão ×0,58;
- `fogo + gato` → garras (0,85 + 0,10) → reage;
- criatura sem apêndice → evasão ×1,00.

É a coerência semântica do trabalho (RF04) aparecendo como **decisão de jogo**, e
não apenas como leitura de ficha. Vale como material de resultado no artigo.

### Outras mudanças

- A vila passou a ter **seed** (`VilaInicial.SEED_DO_MUNDO`, igual à do
  visualizador) e a gerar o bestiário da partida no `_ready` — RF01/RF02 dentro
  da cena jogável, em ~8 ms para 100 criaturas.
- `data/captura/` é pasta nova, **separada** das tabelas do gerador de propósito:
  balanceamento de jogo não é modelo probabilístico e não deve ser lido como tal.
- Nenhuma ação de entrada nova em `project.godot`: a navegação reusa
  `mover_*` e as nativas `ui_accept`/`ui_cancel`.
- Tecla **F4** na vila força um encontro.

---

## 2026-09-02 — Primeira área jogável; o modelo de geração NÃO mudou

### Por que isto está aqui

Entra neste registro por exceção. A vila inicial
(`presentation/exploracao/`, `autoral/mapas/mundo.json`) é conteúdo de
**Camada 1 e 4** e **não altera nada do modelo de geração**: nenhuma tabela
condicional, nenhum atributo, nenhuma métrica. A Seção 3 do artigo continua
válida como está.

O que exige ação são dois efeitos colaterais:

### 1. As figuras do artigo precisam ser refeitas

`project.godot` ganhou

```
[rendering]
textures/canvas_textures/default_texture_filter=0   ; 0 = Nearest
```

O projeto rodava sem essa chave, isto é, com o padrão **Linear**: toda a pixel
art — inclusive as criaturas do bestiário — era desenhada borrada. Qualquer
captura feita antes desta data mostra a arte suavizada e **não** representa o
que o sistema produz. Recapturar antes de usar no artigo.

Cuidado ao mexer nela: a numeração deste ajuste de projeto não é a de
`CanvasItem.texture_filter`, onde `0 = Inherit` e `1 = Nearest`.

### 2. Um gancho novo para RF04, ainda sem código

Cada zona de encontro do mapa declara `elementos_provaveis` — nomes vindos de
`data/vocabulary.json`:

| zona | elementos |
|---|---|
| margem_do_lago | agua, gelo |
| pedregal_leste | terra, eletrico |
| bosque_oeste | planta, sombra |
| … | … |

Hoje **nenhum código lê o campo**. Ele existe para que o sistema de encontros,
quando existir, condicione o sorteio da criatura à *região* — estendendo os
atributos correlacionados do interior da criatura (elemento → porte, cor,
morfologia) para o par criatura↔lugar. Se essa extensão for feita, ela **é**
mudança de modelo e vira uma seção própria aqui, com informação mútua
`I(regiao; elemento)` medida contra baseline, como as demais.

Enquanto não for: é contrato de dados, não comportamento, e não deve ser
descrito no artigo como se já produzisse correlação.

### Outras mudanças de projeto

- `run/main_scene` passou do visualizador do bestiário para a vila. O
  visualizador continua acessível (tecla F2 na vila, ou abrindo a cena direto) —
  RF07/RF08 não perderam tela.
- Bloco `[input]` novo (`mover_cima/baixo/esquerda/direita`, setas e WASD).
- `default_clear_color` escuro: um mapa isométrico é um losango, e sempre sobra
  canto de viewport fora dele.

---

## 2026-08-11 — Silhueta em pixel art e o porte como atributo derivado

### Resumo

O corpo deixou de ser uma silhueta vetorial sorteada por `P(corpo | animal)` e
passou a ser uma **máscara de pixel art indexada** pelo par `(animal_base, porte)`,
onde o **porte é um novo atributo derivado, condicionado ao elemento**.

### O que mudou no fluxo de geração

Antes:

```
seed → elemento, animal_base            (priors)
     → corpo      ~ P(corpo  | animal)  (part_library.tres — 14 corpos vetoriais)
     → paleta     ~ P(paleta | elemento)
     → matiz      ~ P(matiz  | elemento)
     → morfologia ~ P(feature | animal, elemento)
```

Depois:

```
seed → elemento, animal_base            (priors)
     → porte      ~ P(porte  | elemento)   (data/conditional_porte.json)   ← NOVO
     → paleta     ~ P(paleta | elemento)
     → matiz      ~ P(matiz  | elemento)
     → morfologia ~ P(feature | animal, elemento)

body_id = f"{animal_base}_{índice_porte+1}_{porte}"   →  arte/corpos/corpo_<body_id>.png
```

`animal_base` (primário) dá a **estrutura** — quantas patas, onde fica a cabeça, se
há cauda. `porte` (derivado) a **estica** no eixo *compacto → alongado*. São 8 × 4 =
32 máscaras.

### Por que isso importa para a tese

1. **O condicionamento passou a agir na silhueta.** O porte é o único derivado que
   muda a forma, e não a superfície. É a leitura mais imediata da criatura: um
   monstro de terra é atarracado e um de ar é esguio *antes de qualquer cor*. As
   correlações anteriores (cor, morfologia) só apareciam depois de olhar o detalhe.

2. **Nova dimensão medida em RF08.** `I(elemento; porte)` entra nas métricas com
   baseline pareado, e a coerência por moda passou a agregar 5 dimensões (era 4).

3. **A escala fica explícita como argumento de desempenho.** As máscaras não
   carregam cor: o canal R codifica um índice de paleta (1 contorno, 2 sombra, 3
   base, 4 brilho) e `paleta_indexada.gdshader` substitui pela rampa derivada de
   `(matiz, paleta)`. O mesmo PNG serve às 8 famílias elementais e às ~100
   criaturas do bestiário — custo de memória **O(silhuetas)**, não
   O(silhuetas × paletas). É a peça que faltava para sustentar escala e coerência
   ao mesmo tempo, sem pagar em desempenho, no trade-off central do trabalho.

4. **A rampa vem de `(matiz, paleta)`, nunca de uma tabela fixa por elemento.**
   Uma cor por elemento tornaria `I(elemento; cor)` trivialmente igual a
   `H(elemento)` e inflaria a métrica de RF08 com um número que não vem do modelo
   probabilístico. Ponto a declarar no artigo.

### Decisão: sem veto anatômico na apresentação

`P(garras | peixe)` fica entre 2% e 12%. Todo corpo — inclusive os sem patas —
declara pontos de acoplagem de garra (no peixe, na borda ventral), e o apêndice é
desenhado sempre que o sorteio o concede.

O lugar de suprimir um apêndice improvável é a **tabela condicional**, que é
calibrável e entra nas métricas, e não um silêncio na camada de apresentação —
que produziria uma ficha de criatura em contradição com o quadro.

### Números (seed 123456789, n=5000)

| dimensão | teto teórico | observado | eficiência |
|---|---|---|---|
| porte | 36,8% | 36,4% | 98,8% |
| paleta | 55,0% | 54,8% | 99,6% |
| matiz | 43,7% | 43,2% | 98,7% |
| morfologia | 85,1% | 85,0% | 100,0% |
| variante | 41,0% | 40,7% | 99,2% |

Eficiência geral: **99,3%**.

| par | I condicionado | I baseline | razão | U |
|---|---|---|---|---|
| elemento→porte | 0,118 | 0,002 | 68× | 5,9% |
| elemento→paleta | 0,577 | 0,003 | 181× | 25,1% |
| elemento→matiz | 1,300 | 0,008 | 163× | 39,6% |
| elemento→cor | 1,601 | 0,049 | 33× | 30,3% |
| animal→morfologia | 1,182 | 0,017 | 69× | 35,6% |

O porte tem a menor informação mútua porque seu viés é o mais suave (no máximo
5:3:2:1). É escolha de calibração, não defeito: endurecer `conditional_porte.json`
aumenta a coerência da silhueta e reduz a variedade — o trade-off em miniatura.
O valor medido bate com o analítico `H(porte) − Σₑ P(e)·H(porte|e) = 0,1176`.

Unicidade (k=3, 13 posições): 1189/5000 distintas no condicionado contra 2295/5000
no baseline. Desempenho: 100 criaturas em ~2 ms (meta: < 2 s).

### Efeitos colaterais a declarar

- O **vetor de atributos** da distância de Hamming passou a usar `porte`
  (4 valores) no lugar de `body_id` do pipeline vetorial (14 valores). Os números
  de unicidade não são comparáveis aos da rodada anterior.
- Os números de informação mútua de paleta, matiz, cor e morfologia **não**
  mudaram: `_amostrar_indice_ponderado` consome exatamente um `randf()`, como o
  sorteio de corpo que substituiu, então o fluxo de RNG dos derivados seguintes é
  idêntico.
- Escamas, asas e nadadeiras continuam sorteadas e medidas, mas ainda não
  desenhadas — ver `docs/pendencias.md`.

### Arquivos

Novos: `data/conditional_porte.json`, `procedural/creatures/catalogo_corpos.gd`,
`procedural/creatures/paleta_criatura.gd`,
`presentation/creature_sprite_renderer.gd`, `arte/**`, `tools/arte/**`.

O pipeline vetorial anterior (`BodyDef`, `CreaturePartLibrary`,
`data/part_library.tres`, `presentation/creature_renderer.gd`) permanece no
repositório sem uso, como referência para a comparação entre as duas abordagens.

---

## 2026-08-11 (b) — Silhuetas com esqueleto próprio por animal

### O problema

`gato`, `canino`, `roedor` e `reptil` saíam todos de uma única função
`_quadrupede()` parametrizada: mudavam raios, orelhas e cauda, mas o esqueleto era
o mesmo. O resultado eram quatro variações do mesmo cachorro.

Isso não é só estética. Se `animal_base` mal muda a silhueta, o **atributo
primário perde poder discriminativo** — e as correlações derivadas (porte, cor,
morfologia) ficam penduradas numa forma que o jogador não consegue distinguir. É a
mesma crítica que o projeto já fazia ao "blob circular" da fase vetorial, agora um
nível acima.

### O que mudou

Cada uma das 8 bases passou a ter função e assinatura próprias, documentadas no
docstring da sua função em `tools/arte/corpos_tipos.py`:

| animal | assinatura |
|---|---|
| gato | tronco baixo e curto, cabeça pequena, cauda longa em arco alto |
| canino | dorso **inclinado** (peito alto, garupa baixa), focinho longo, orelhas caídas |
| roedor | postura **sentada** — silhueta vertical, garupa no chão, cauda arrastando |
| reptil | **esparramado** — altura mínima, crista serrilhada, cauda grossa |
| anfibio | perfil em rampa: coxa culmina acima da linha do dorso |
| ave | corpo em ovo inclinado, pescoço curvo, cauda em leque |
| peixe | corpo em gota, caudal em meia-lua de dois lobos |
| inseto | três segmentos encostados, seis pernas articuladas (fêmur/tíbia) |

O eixo de porte também foi endurecido: de `rx += 0,4·p` para `rx += 0,85..1,0·p`,
para que *compacto* e *alongado* sejam distinguíveis a olho — sem isso, o único
derivado que age sobre a forma não era perceptível.

### Efeito colateral no dado

`ARQUETIPOS` mudou para acompanhar as novas posturas, e isso **altera
`Criatura.arquetipo`** exportado:

- `roedor`: `quadrupede` → **`bipede`** (agora desenhado sentado)
- `reptil`: `quadrupede` → **`serpentiforme`** (agora esparramado e rasteiro)

Os seis arquétipos seguem todos em uso. Nenhuma métrica depende de `arquetipo`
hoje — ele é anotação de análise —, mas quem citar a distribuição de arquétipos no
artigo precisa reexportar.

Todas as caudas ganharam clamp ao quadro de 32px: nos portes esbelto/alongado o
comprimento crescia e a ponta saía em `x` negativo, truncada em silêncio, com a
âncora `cauda` apontando para fora da máscara.

### Correção de renderização (não altera o modelo, mas invalidava a inspeção)

O `CreatureSpriteRenderer` compunha as máscaras com `draw_texture_rect()` dentro
de `_draw()`. Num shader `canvas_item`, `TEXTURE` é a textura **do nó**, não a do
comando de desenho: o shader amostrava a textura branca padrão, caía em
`round(1,0 × 4) = 4` e pintava o quadro inteiro de `cor_brilho`, sem nunca
descartar o transparente. Toda criatura aparecia como um retângulo sólido.

Agora cada máscara vive num `TextureRect` próprio, com um `ShaderMaterial`
compartilhado pelas camadas da mesma criatura. O reenquadramento migrou para
`NOTIFICATION_RESIZED`: em lista, `configurar()` é chamado logo após
`add_child()`, quando o Control ainda mede `(0,0)` e o container só distribui
espaço no frame seguinte.
