# Camada 2 — Gerador Procedural de Criaturas

Contribuição original do trabalho. Gera ~100 criaturas únicas por seed com
**atributos correlacionados via probabilidade condicionada** (RF04).

Fluxo:
`Seed → Atributos Primários → Probabilidades Condicionadas → Atributos Derivados → Criatura Final`

- Atributos primários: elemento, animal base.
- Atributos derivados (porte, paleta, matiz, garras, escamas, asas, nadadeiras):
  sorteados **condicionados** aos primários, nunca de forma independente.

Regras (obrigatório):
- Toda função de geração recebe a **seed explicitamente** (RF03 — sem estado
  aleatório global).
- Tabelas de probabilidade vêm de `res://data/` (`.tres`/JSON), não hardcoded.
- Saída determinística: mesma seed ⇒ mesmo bestiário.

## Silhueta como atributo

O **porte** é o primeiro derivado a ser resolvido, condicionado ao elemento
(`P(porte | elemento)`, em `data/conditional_porte.json`). Combinado ao
`animal_base`, ele forma o `body_id` que indexa uma das 32 máscaras de pixel art
em `arte/corpos/` — 8 animais × 4 portes no eixo *compacto → alongado*.

Antes, `animal_base` apenas alterava os raios de uma mesma elipse e todas as
criaturas compartilhavam a silhueta de um blob circular; os apêndices nasciam em
frações fixas do quadro, iguais para os 8 animais. Hoje cada corpo declara suas
próprias âncoras (`arte/corpos/corpos_ancoras.json`) e o apêndice acompanha a
anatomia: a garra encosta na ponta da pata daquele corpo, e um corpo sem patas não
declara `pe_*` — logo não recebe garras.

Isso põe o condicionamento na leitura mais imediata da criatura: um monstro de
terra é atarracado e um de ar é esguio, antes de qualquer cor.

`CatalogoCorpos` é a ponte entre esta camada e a apresentação: resolve *quais
atributos → qual PNG e em que ponto ele encosta*. `PaletaCriatura` traduz
(matiz, paleta) na rampa de 4 tons que colore as máscaras indexadas.

**Cobertura de arte.** Só `garras` tem máscaras (`CatalogoCorpos.ARTE_DE_FEATURE`).
`escamas`, `asas` e `nadadeiras` continuam sendo sorteadas e medidas normalmente —
apenas ainda não são desenhadas, e a ficha da criatura marca isso como *(sem
arte)*. O pipeline vetorial anterior (`BodyDef` / `part_library.tres` /
`creature_renderer.gd`) permanece no repositório como referência, sem uso.

## Métricas (RF08)

`metricas_coerencia.gd` reporta três famílias de medida, com propósitos distintos.

### 1. Coerência por moda — descritiva, **não** é a prova

Fração de criaturas cujo derivado caiu na moda da sua condicional. **O máximo
não é 100%**: é o teto imposto pelas próprias tabelas, `E[max_v P(v|primário)]`.
Se `P(matiz=vermelho|fogo) = 0,40`, nenhum gerador correto passa de ~44% nessa
dimensão. Perseguir 100% exigiria tabelas quase degeneradas e destruiria a
variedade procedural — o oposto do que o trabalho propõe.

Por isso cada dimensão é reportada como **observado / teto**, e a razão entre os
dois (`eficiencia_pct`) responde à única pergunta legítima aqui: *o gerador está
amostrando fielmente das condicionais?* Com n=5000, a eficiência é ~99,9%.

| dimensão | teto teórico |
|---|---|
| porte | 36,8% |
| paleta | 55,0% |
| matiz | 43,7% |
| morfologia | 85,1% |
| variante | 41,0% |

### 2. Informação mútua — **esta** é a prova da hipótese (RF04)

`I(primário; derivado)` em bits, contra o baseline de sorteio independente
(`GeradorCriaturas.Modo.INDEPENDENTE`), que amostra das marginais e portanto
mantém as mesmas proporções globais **sem** correlação com os primários. Ambos os
modos partem dos mesmos primários e consomem o RNG na mesma ordem: a comparação é
pareada e a única diferença observável é o condicionamento.

Sob H₀, `I → 0`. Medido com seed 123456789, n=5000:

| par | condicionado | independente | razão |
|---|---|---|---|
| elemento→porte | 0,118 | 0,002 | 68× |
| elemento→paleta | 0,577 | 0,003 | 181× |
| elemento→matiz | 1,300 | 0,008 | 163× |
| elemento→cor | 1,601 | 0,049 | 33× |
| animal→morfologia | 1,182 | 0,017 | 69× |

O porte tem a menor informação mútua das dimensões (`U = 5,9%`) porque seu viés é o
mais suave — no máximo 5:3:2:1. É escolha de calibração, não defeito: endurecer
`conditional_porte.json` aumenta a coerência da silhueta e reduz a variedade. O
valor medido bate com o analítico `H(porte) − Σₑ P(e)·H(porte|e) = 0,1176`.

**Atenção ao n.** O estimador plug-in é fortemente enviesado para cima quando há
mais células que observações: com n=100 e 8 elementos × ~50 combinações de cor,
até dados independentes exibem `I > 0` (o baseline chega a 1,687 bits em
`elemento→cor`, contra 0,056 em n=5000). O bestiário **jogável** é o de n≈100; a
**estimativa de I** exige n ≥ 5000. São dois usos distintos do mesmo gerador, e o
artigo deve declarar qual n produziu cada número. Reporta-se também a correção de
Miller-Madow e o coeficiente de incerteza `U = I/H(Y)`.

### 3. Unicidade — definição operacional

Distância de Hamming sobre o vetor de atributos, com limiar `k` explícito: duas
criaturas são distintas quando `d ≥ k`. Custo O(n²) — para amostras grandes, use
`avaliar_info_mutua()` direto, que é O(n).

Unicidade **não** mede qualidade: o baseline independente produz *mais* criaturas
distintas (2295 vs 1189 em n=5000), porque descorrelacionar aumenta a dispersão. É
a coerência que separa variedade de ruído — este é exatamente o ponto do trabalho
frente a No Man's Sky.

## Ferramentas

```bash
# testes + relatório completo (RF03, desempenho, RF04, RF08)
godot --headless -s res://tools/test_gerador.gd

# exportar bestiário + métricas para análise externa
godot --headless -s res://tools/exportar_bestiario.gd -- --n 5000 --out /tmp/b.json

# tabelas, CSV e figuras do artigo (matplotlib opcional)
python3 tools/analise.py /tmp/b.json --csv out/ --graficos out/
```
