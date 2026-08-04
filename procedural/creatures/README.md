# Camada 2 — Gerador Procedural de Criaturas

Contribuição original do trabalho. Gera ~100 criaturas únicas por seed com
**atributos correlacionados via probabilidade condicionada** (RF04).

Fluxo:
`Seed → Atributos Primários → Probabilidades Condicionadas → Atributos Derivados → Criatura Final`

- Atributos primários: elemento, animal base, paleta.
- Atributos derivados (cor, garras, escamas, asas, nadadeiras): sorteados
  **condicionados** aos primários, nunca de forma independente.

Regras (obrigatório):
- Toda função de geração recebe a **seed explicitamente** (RF03 — sem estado
  aleatório global).
- Tabelas de probabilidade vêm de `res://data/` (`.tres`/JSON), não hardcoded.
- Saída determinística: mesma seed ⇒ mesmo bestiário.

## Silhueta como atributo (Fase 1)

O corpo é o **primeiro derivado a ser resolvido**, condicionado ao animal
(`P(corpo | animal)`). Antes, `animal_base` apenas alterava os raios de uma mesma
elipse e todas as criaturas compartilhavam a silhueta de um blob circular; os
apêndices nasciam em frações fixas do quadro, iguais para os 8 animais — uma asa
brotava no mesmo ponto num peixe e numa ave.

Agora `data/part_library.tres` declara 14 corpos em 6 arquétipos, cada um com sua
geometria, suas âncoras por slot e seus slots proibidos. A geometria é **dado**:
`creature_renderer.gd` não contém nenhuma forma, só a transformação do espaço
normalizado do `BodyDef` para pixels. Cada corpo é enquadrado pela sua própria
caixa envolvente, porque os arquétipos têm extensões muito diferentes.

`forbidden_slots` já está preenchido, mas só vira veto na Fase 2.

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
| elemento→paleta | 0,565 | 0,004 | 145× |
| elemento→matiz | 1,320 | 0,009 | 153× |
| elemento→cor | 1,622 | 0,056 | 29× |
| animal→morfologia | 1,173 | 0,016 | 71× |

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
distintas (1430 vs 712 em n=5000), porque descorrelacionar aumenta a dispersão. É
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
