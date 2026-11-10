# Dados — Tabelas de Probabilidade Condicionada

Tabelas que definem P(atributo derivado | atributos primários), como
**recursos de dados JSON** — nunca hardcoded no código, para permitir
calibração sem recompilar a lógica. JSON foi escolhido em vez de
`.tres` para que as tabelas sejam **testáveis fora da engine**
(`tools/validate_tables.py`).

## Modelo probabilístico

```
Seed
 ├─ elemento      ~ prior                         (primary_priors.json)
 ├─ animal_base   ~ prior                         (primary_priors.json)
 ├─ porte         ~ P(porte  | elemento)          (conditional_porte.json)
 ├─ paleta        ~ P(paleta | elemento)          (conditional_palette.json)
 ├─ matiz (cor)   ~ P(matiz  | elemento)          (conditional_hue.json)
 ├─ morfologia    ~ P(feature | animal, elemento) (conditional_morphology.json)
 └─ p/ cada feature presente:
     modelo       ~ P(modelo | elemento)          (feature_variants.json)
```

A silhueta é o par **(animal_base, porte)**: o animal dá a estrutura — quantas
patas, onde fica a cabeça, se há cauda — e o porte a estica no eixo
*compacto → alongado*. Juntos indexam uma das 32 máscaras de `arte/corpos/` pelo
`body_id` (`gato_2_medio` → `corpo_gato_2_medio.png`).

O porte é resolvido **antes** dos demais derivados: é da silhueta que dependem as
posições e a viabilidade anatômica dos apêndices. Ele é também o único derivado
que muda a *silhueta*, e não a superfície — é por ele que o condicionamento
aparece na leitura mais imediata da criatura: um monstro de terra é atarracado, um
de ar é esguio, antes de qualquer cor.

## Modelo v2

`modelo_v2.json` acrescenta o que a v1 não condiciona: `P(porte | animal, elemento)`, o
sorteio em cadeia dos traços e o limiar da nota de coerência. Os outros arquivos valem
para as duas versões. A v1 não lê este arquivo e continua reproduzível. O registro
completo está em `docs/mudancas-estruturais.md`.

## Silhueta e arte

A geometria da silhueta **não** vive mais aqui: ela é pixel art em `arte/corpos/`,
com as âncoras de apêndice em `arte/corpos/corpos_ancoras.json` (ver
`arte/README.md`). Esta pasta guarda só o modelo probabilístico.

`part_library.tres` (14 corpos vetoriais em 6 arquétipos, gerado por
`tools/gerar_part_library.gd`) é o **pipeline vetorial anterior**, mantido apenas
como referência; o gerador não o consulta mais.

A criatura visual é montada de partes: corpo (por `animal_base` + `porte`) + cada
feature presente no seu **modelo** escolhido. Não só *se* tem garras, mas *qual*
garra também é condicionado ao elemento (Fogo → garras agressivas) — a coerência
semântica alcança a camada visual (RF07).

Os **derivados nunca são sorteados de forma independente** — todos dependem
de pelo menos um primário. É essa dependência que produz a coerência
semântica (RF04) e diferencia a proposta dos jogos comerciais (No Man's Sky:
escala sem coerência).

## Arquivos

| Arquivo | Relação | Tipo |
|---|---|---|
| `vocabulary.json` | valores canônicos de todos os atributos | fonte única de verdade |
| `primary_priors.json` | P(elemento), P(animal_base) | categórica (soma 1) |
| `conditional_porte.json` | P(porte \| elemento) — seleciona a máscara de corpo | pesos inteiros (o gerador normaliza) |
| `conditional_palette.json` | P(paleta \| elemento) | categórica condicional (linha soma 1) |
| `conditional_hue.json` | P(matiz \| elemento) | categórica condicional (linha soma 1) |
| `conditional_morphology.json` | P(garras/escamas/asas/nadadeiras \| animal, elemento) | Bernoulli aditivo com clamp |
| `feature_variants.json` | P(modelo da feature \| elemento) — qual das N variantes | pesos inteiros (o gerador normaliza) |

### Categóricas (`_meta.tipo` = `categorica` / `condicional`)
Cada linha é uma distribuição que **soma 1.0**. Chaves omitidas valem 0.
O gerador amostra um valor via CDF a partir da seed.

### Morfologia (`_meta.tipo` = `condicional_bernoulli`)
Cada feature é um evento independente:
`P(feature | animal, elemento) = clamp(base_animal[feature] + modificador_elemento[feature], 0.02, 0.98)`.
O clamp mantém a geração estocástica (nunca 0%/100%), preservando variedade.
Não soma 1 — são 4 moedas viesadas, não uma distribuição.

## `captura/` — balanceamento da mecânica, não do gerador

`data/captura/` guarda os números do sistema de encontro e captura
(`presentation/encontro/`). Ficam **separados** das tabelas acima de propósito:
estas descrevem o modelo generativo do trabalho e são material da Seção 3 do
artigo; aquelas são ajuste de jogo e não participam de sorteio nenhum de criatura.

| Arquivo | Papel |
|---|---|
| `captura/balanceamento.json` | chance base, clamps, fator de evasão por traço, faixas de vigor, bônus de isca errada, risco de fuga |
| `captura/dispositivos.json` | dispositivos: multiplicador geral + eficácia contra cada traço |
| `captura/iscas.json` | iscas: `tipos_preferidos` (valores de `animal_base`) + bônus |
| `captura/encontro.json` | ritmo do roteiro e parâmetros de detecção |

A ligação entre as duas pastas é o **fator de evasão por traço**: a dificuldade
de captura não é declarada por espécie: ela é a leitura, do lado da mecânica, da
morfologia que `conditional_morphology.json` sorteou. `água + peixe` sai
escamado e com nadadeiras — e, por consequência, difícil de segurar.

## `pesca/` — balanceamento da pesca, também não do gerador

`data/pesca/` guarda os números da pesca (`presentation/pesca/regras/`). Mesma
separação de `captura/`: **não é modelo generativo**. Nenhum destes arquivos
sorteia criatura, consome o RNG do gerador ou muda o bestiário de uma seed — eles
**leem atributos já sorteados**. O bestiário continua idêntico (RF03) e as métricas
de RF04/RF08 medem as mesmas criaturas de antes da pesca existir
(`tools/test_pesca.gd` regera o bestiário depois de calcular os perfis e compara).

| Arquivo | Papel |
|---|---|
| `pesca/configuracao.json` | ritmo e calibragem: arco de força, recolhimento (velocidade/profundidade), surgimento da silhueta, interesse, deriva, tutorial, textos (`ConfiguracaoPesca`) |
| `pesca/perfil.json` | perfil de pesca **derivado**: profundidade, velocidade, tolerâncias e peso/raridade como soma de contribuições de animal, elemento, porte e traços (`PerfilPesca`) |
| `pesca/pontos.json` | pontos de pesca por região do mapa: pesos por elemento e animal, aplicados ao bestiário da seed **depois** da geração (`PontoDePesca`, `TabelasPesca`) |

O perfil é o equivalente, na pesca, do fator de evasão na captura: não há tabela
por espécie. A coerência semântica do gerador vira mecânica sem regra extra —
`água + peixe` recebe nadadeiras e escamas com alta probabilidade e, por isso, nada
**fundo**, **rápido** e **escorregadio** (menos folga de velocidade); um anfíbio fica
no raso e lento; gelo/sombra/terra puxam para o fundo, fogo/ar/elétrico para a
superfície. O ruído individual usa um RNG próprio (`seed_individual + 0x9E5CA`).

Os pontos não listam criaturas (o bestiário muda com a seed): declaram pesos de
habitat, como `elementos_provaveis` dos pontos de encontro. A região muda **quem**
se pesca ali, nunca **como** a criatura é gerada.

Calibragem verificada por `tools/test_pesca.gd`, que também imprime a tabela de
perfis da seed de teste (material para o artigo):

```bash
godot --headless --path . -s res://tools/test_pesca.gd
```

## Coerência (exemplos-canônicos, validados)
- **Fogo + Gato** → paleta *quente*, matiz *vermelho*, `garras` ≈ 95%.
- **Água + Peixe** → paleta *fria*, matiz *azul*, `escamas` ≈ 98%, `nadadeiras` ≈ 98%.

## Validação
```bash
python3 tools/validate_tables.py
```
Confere somas, chaves contra o `vocabulary.json` e imprime os perfis esperados.
Rodar **sempre após calibrar** qualquer tabela.

> Alterar o esquema/modelo aqui exige sinalizar atualização da **Seção 3 do
> artigo** (manter artigo e código sincronizados).
