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
 ├─ corpo         ~ P(corpo  | animal)            (part_library.tres)
 ├─ paleta        ~ P(paleta | elemento)          (conditional_palette.json)
 ├─ matiz (cor)   ~ P(matiz  | elemento)          (conditional_hue.json)
 ├─ morfologia    ~ P(feature | animal, elemento) (conditional_morphology.json)
 └─ p/ cada feature presente:
     modelo       ~ P(modelo | elemento)          (feature_variants.json)
```

O corpo é resolvido **antes** dos demais derivados: é dele que dependem as
posições e a viabilidade anatômica dos apêndices.

## `part_library.tres` — biblioteca de corpos

Único recurso em formato `.tres` e não JSON, porque guarda `Vector2` e
`PackedVector2Array` — geometria, que o `ResourceSaver` serializa nativamente e
que não teria por que ser validada fora da engine.

Contém 14 corpos em 6 arquétipos (quadrúpede, avial, serpentiforme, aquático,
insetoide, bípede), cada um com sua silhueta, os pontos de ancoragem de cada
apêndice e a lista de slots anatomicamente impossíveis.

Regenerado por `tools/gerar_part_library.gd`, que é a fonte de calibração — o
`.tres` é o dado versionado. **Editar silhueta é mexer no gerador e regerar**,
nunca escrever geometria no renderer:

```bash
godot --headless -s res://tools/gerar_part_library.gd   # regera o .tres
godot -s res://tools/folha_corpos.gd                    # folha de contato p/ conferir
```

A criatura visual e montada de partes: corpo (por `animal_base`) + cada feature
presente no seu **modelo** escolhido. Nao so *se* tem garras, mas *qual* garra
tambem e condicionado ao elemento (Fogo -> garras agressivas) — a coerencia
semantica alcanca a camada visual (RF07).

Os **derivados nunca são sorteados de forma independente** — todos dependem
de pelo menos um primário. É essa dependência que produz a coerência
semântica (RF04) e diferencia a proposta dos jogos comerciais (No Man's Sky:
escala sem coerência).

## Arquivos

| Arquivo | Relação | Tipo |
|---|---|---|
| `vocabulary.json` | valores canônicos de todos os atributos | fonte única de verdade |
| `primary_priors.json` | P(elemento), P(animal_base) | categórica (soma 1) |
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
