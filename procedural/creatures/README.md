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
