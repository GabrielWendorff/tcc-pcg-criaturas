#!/usr/bin/env python3
"""Valida as tabelas de probabilidade condicionada FORA da engine.

Uso:  python3 tools/validate_tables.py
Confere: (1) distribuicoes categoricas somam 1.0; (2) chaves batem com o
vocabulario canonico; (3) imprime os perfis esperados dos exemplos-canonicos
para inspecao visual da coerencia semantica. Retorna codigo != 0 se falhar.
"""
import json, sys, os

DATA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
def load(name): return json.load(open(os.path.join(DATA, name), encoding="utf-8"))

vocab = load("vocabulary.json")
ELEM = vocab["primarios"]["elemento"]
ANIM = vocab["primarios"]["animal_base"]
PAL  = set(vocab["derivados"]["paleta"])
MAT  = set(vocab["derivados"]["matiz"])
MORPH = vocab["derivados"]["morfologia"]
PORTES = vocab["derivados"]["porte"]

errors = []


def check_vies(label, pesos, n):
    """Vetor de vies: n pesos numericos, nao negativos, com soma > 0."""
    if len(pesos) != n:
        errors.append(f"{label}: len(pesos)={len(pesos)} != {n}")
        return
    if any((not isinstance(w, (int, float))) or w < 0 for w in pesos):
        errors.append(f"{label}: pesos invalidos (negativos/nao-numericos)")
    if sum(pesos) <= 0:
        errors.append(f"{label}: soma de pesos <= 0")

def check_sum(label, dist, allowed):
    s = sum(dist.values())
    if abs(s - 1.0) > 1e-6:
        errors.append(f"{label}: soma = {s:.4f} (esperado 1.0)")
    for k in dist:
        if k not in allowed:
            errors.append(f"{label}: chave invalida '{k}'")

# --- priors primarios ---
pri = load("primary_priors.json")
check_sum("prior elemento", pri["elemento"], set(ELEM))
check_sum("prior animal_base", pri["animal_base"], set(ANIM))
if set(pri["elemento"]) != set(ELEM): errors.append("prior elemento: conjunto difere do vocabulario")
if set(pri["animal_base"]) != set(ANIM): errors.append("prior animal_base: conjunto difere do vocabulario")

# --- vies de porte | elemento (seleciona a mascara de corpo) ---
porte = load("conditional_porte.json")
if porte["portes"] != PORTES:
    errors.append("porte: lista 'portes' difere do vocabulario")
for e in ELEM:
    if e not in porte["vies_por_elemento"]:
        errors.append(f"porte: elemento '{e}' ausente"); continue
    check_vies(f"porte|{e}", porte["vies_por_elemento"][e], len(PORTES))

# --- P(paleta|elemento) ---
pal = load("conditional_palette.json")["tabela"]
for e in ELEM:
    if e not in pal: errors.append(f"paleta: elemento '{e}' ausente"); continue
    check_sum(f"paleta|{e}", pal[e], PAL)

# --- P(matiz|elemento) ---
hue = load("conditional_hue.json")["tabela"]
for e in ELEM:
    if e not in hue: errors.append(f"matiz: elemento '{e}' ausente"); continue
    check_sum(f"matiz|{e}", hue[e], MAT)

# --- morfologia (Bernoulli aditivo com clamp) ---
morph = load("conditional_morphology.json")
base = morph["base_por_animal"]; mod = morph["modificador_por_elemento"]
cmin, cmax = morph["_meta"]["clamp_min"], morph["_meta"]["clamp_max"]
for a in ANIM:
    if a not in base: errors.append(f"morfologia: animal '{a}' ausente"); continue
    for f in MORPH:
        if f not in base[a]: errors.append(f"morfologia base[{a}]: feature '{f}' ausente")
for e in ELEM:
    if e not in mod: errors.append(f"morfologia: modificador elemento '{e}' ausente"); continue
    for f in MORPH:
        if f not in mod[e]: errors.append(f"morfologia mod[{e}]: feature '{f}' ausente")

def p_feature(animal, elem, feat):
    return max(cmin, min(cmax, base[animal][feat] + mod[elem][feat]))

# --- variantes (modelos) das features ---
variants = load("feature_variants.json")
for feat in MORPH:
    if feat not in variants:
        errors.append(f"variantes: feature '{feat}' ausente"); continue
    n = variants[feat]["num_modelos"]
    modelos = variants[feat]["modelos"]
    if len(modelos) != n:
        errors.append(f"variantes[{feat}]: len(modelos)={len(modelos)} != num_modelos={n}")
    vies = variants[feat]["vies_por_elemento"]
    for e in ELEM:
        if e not in vies:
            errors.append(f"variantes[{feat}]: elemento '{e}' ausente"); continue
        check_vies(f"variantes[{feat}][{e}]", vies[e], n)

print("=" * 64)
print("VALIDACAO DAS TABELAS DE PROBABILIDADE CONDICIONADA")
print("=" * 64)
print(f"elementos: {len(ELEM)} | animais: {len(ANIM)} | "
      f"combinacoes primarias: {len(ELEM)*len(ANIM)}\n")

def perfil(elem, animal):
    top_pal = max(pal[elem], key=pal[elem].get)
    top_mat = max(hue[elem], key=hue[elem].get)
    vp = porte["vies_por_elemento"][elem]
    top_porte = PORTES[vp.index(max(vp))]
    feats = {f: p_feature(animal, elem, f) for f in MORPH}
    print(f"  {elem.upper()} + {animal.upper()}")
    print(f"    porte provavel  : {top_porte} ({max(vp)/sum(vp):.0%})"
          f"  -> corpo_{animal}_{PORTES.index(top_porte)+1}_{top_porte}.png")
    print(f"    paleta provavel : {top_pal} ({pal[elem][top_pal]:.0%})")
    print(f"    matiz provavel  : {top_mat} ({hue[elem][top_mat]:.0%})")
    print("    morfologia P(presenca) [modelo mais provavel p/ o elemento]:")
    for f in MORPH:
        bar = "#" * round(feats[f] * 20)
        vies = variants[f]["vies_por_elemento"][elem]
        modelo = variants[f]["modelos"][vies.index(max(vies))]
        print(f"      {f:<11}{feats[f]:>5.0%} |{bar:<20}| {modelo}")
    print()

print("PERFIS-CANONICOS:")
perfil("fogo", "gato")
perfil("agua", "peixe")
print("OUTROS EXEMPLOS:")
perfil("ar", "ave")
perfil("gelo", "reptil")

# --- cobertura da arte: toda combinacao animal x porte precisa de mascara ---
# Roda aqui, e nao so na engine, porque uma tabela valida que aponta para um PNG
# inexistente so falharia no meio da geracao do bestiario.
ARTE = os.path.join(os.path.dirname(DATA), "arte")
ancoras_path = os.path.join(ARTE, "corpos", "corpos_ancoras.json")
if not os.path.exists(ancoras_path):
    errors.append(f"arte: {ancoras_path} inexistente")
else:
    sprites = json.load(open(ancoras_path, encoding="utf-8"))["sprites"]
    for a in ANIM:
        for i, p in enumerate(PORTES):
            body_id = f"{a}_{i+1}_{p}"
            if body_id not in sprites:
                errors.append(f"arte: ancoras sem '{body_id}'")
            elif not os.path.exists(os.path.join(ARTE, "corpos", f"corpo_{body_id}.png")):
                errors.append(f"arte: mascara ausente corpo_{body_id}.png")
    print(f"cobertura da arte: {len(sprites)} mascaras de corpo "
          f"({len(ANIM)} animais x {len(PORTES)} portes)")

for feat, sub in (("garras", "garras"),):
    for i, modelo in enumerate(variants[feat]["modelos"]):
        arq = os.path.join(ARTE, sub, f"{feat[:-1]}_{i+1:02d}_{modelo}.png")
        if not os.path.exists(arq):
            errors.append(f"arte: mascara ausente {os.path.relpath(arq, ARTE)}")

print("=" * 64)
if errors:
    print(f"FALHOU: {len(errors)} erro(s)")
    for e in errors: print("  -", e)
    sys.exit(1)
print("OK: todas as distribuicoes somam 1.0 e as chaves batem com o vocabulario.")
