#!/usr/bin/env python3
"""Gera todos os sons do jogo por sintese, sem amostra de terceiros.

Uso:  python3 tools/audio/gerar_audio.py
Saida: arte/audio/*.wav e arte/audio/sons.json (catalogo lido por sistemas/audio.gd).

Chiptune de proposito: onda quadrada, triangulo e ruido, como os consoles portateis que
inspiram o genero, e coerente com a pixel art gerada por script. Deterministico: o ruido
usa semente fixa, e rodar de novo produz os mesmos arquivos.
"""
import json
import os
import wave

import numpy as np

TAXA = 22050
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "arte", "audio")
RNG = np.random.default_rng(20261112)

NOTAS = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8,
         "A": 9, "A#": 10, "B": 11}


def freq(nota):
    """'A4' -> 440 Hz. 'r' e pausa."""
    if nota == "r":
        return 0.0
    nome, oitava = nota[:-1], int(nota[-1])
    semitons = NOTAS[nome] + (oitava - 4) * 12 - 9
    return 440.0 * 2 ** (semitons / 12)


def tempo(segundos):
    return np.arange(int(segundos * TAXA)) / TAXA


def quadrada(f, seg, duty=0.5):
    t = tempo(seg)
    if f <= 0:
        return np.zeros_like(t)
    return np.where((t * f) % 1.0 < duty, 1.0, -1.0)


def triangulo(f, seg):
    t = tempo(seg)
    if f <= 0:
        return np.zeros_like(t)
    return 2.0 * np.abs(2.0 * ((t * f) % 1.0) - 1.0) - 1.0


def ruido(seg):
    return RNG.uniform(-1.0, 1.0, int(seg * TAXA))


def varredura(f0, f1, seg, forma="quadrada", duty=0.5):
    t = tempo(seg)
    f = np.linspace(f0, f1, t.size)
    fase = np.cumsum(f) / TAXA
    if forma == "triangulo":
        return 2.0 * np.abs(2.0 * (fase % 1.0) - 1.0) - 1.0
    return np.where(fase % 1.0 < duty, 1.0, -1.0)


def envelope(n, ataque=0.005, queda=0.0, sustento=1.0, soltura=0.05):
    """ADSR em segundos, sobre n amostras."""
    e = np.full(n, sustento)
    a = min(n, int(ataque * TAXA))
    d = min(n - a, int(queda * TAXA))
    r = min(n, int(soltura * TAXA))
    if a:
        e[:a] = np.linspace(0.0, 1.0, a)
    if d:
        e[a:a + d] = np.linspace(1.0, sustento, d)
    if r:
        e[-r:] *= np.linspace(1.0, 0.0, r)
    return e


def nota(f, seg, forma="quadrada", duty=0.5, **env):
    onda = {"quadrada": lambda: quadrada(f, seg, duty), "triangulo": lambda: triangulo(f, seg),
            "ruido": lambda: ruido(seg)}[forma]()
    return onda * envelope(onda.size, **env)


def sequencia(partes):
    return np.concatenate(partes)


def mixar(*faixas):
    n = max(f.size for f in faixas)
    saida = np.zeros(n)
    for f in faixas:
        saida[:f.size] += f
    return saida


def normalizar(x, pico=0.7):
    m = np.max(np.abs(x))
    return x * (pico / m) if m > 0 else x


def gravar(nome, amostras):
    os.makedirs(SAIDA, exist_ok=True)
    dados = (np.clip(amostras, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(os.path.join(SAIDA, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados.tobytes())
    return nome + ".wav"


# ------------------------------------------------------------------ efeitos

def efeitos():
    e = {}
    e["ui_mover"] = nota(freq("E6"), 0.035, duty=0.25, soltura=0.02) * 0.5
    e["ui_confirmar"] = sequencia([nota(freq("C6"), 0.05, duty=0.25, soltura=0.01),
                                   nota(freq("G6"), 0.08, duty=0.25, soltura=0.05)])
    e["ui_cancelar"] = sequencia([nota(freq("G5"), 0.05, duty=0.25, soltura=0.01),
                                  nota(freq("C5"), 0.08, duty=0.25, soltura=0.05)])
    e["dialogo"] = nota(freq("A5"), 0.03, duty=0.125, soltura=0.02) * 0.4
    e["encontro"] = sequencia([nota(freq("E5"), 0.07, duty=0.5, soltura=0.01),
                               nota(freq("B5"), 0.07, duty=0.5, soltura=0.01),
                               nota(freq("E6"), 0.18, duty=0.5, soltura=0.12)])
    pancada = nota(0, 0.12, forma="ruido", soltura=0.11) * 0.8
    e["golpe"] = mixar(pancada, varredura(220, 60, 0.12) * envelope(int(0.12 * TAXA), soltura=0.1) * 0.6)
    e["golpe_eficaz"] = mixar(nota(0, 0.2, forma="ruido", soltura=0.18),
                              varredura(440, 80, 0.2) * envelope(int(0.2 * TAXA), soltura=0.15) * 0.7,
                              sequencia([np.zeros(int(0.08 * TAXA)),
                                         nota(freq("A6"), 0.1, duty=0.25, soltura=0.08) * 0.4]))
    e["errou"] = varredura(900, 300, 0.18, duty=0.125) * envelope(int(0.18 * TAXA), soltura=0.15) * 0.4
    e["caiu"] = varredura(500, 70, 0.55, forma="triangulo") * envelope(int(0.55 * TAXA), soltura=0.3)
    e["cura"] = sequencia([nota(freq(n), 0.06, forma="triangulo", soltura=0.03)
                           for n in ("C5", "E5", "G5", "C6", "E6")])
    e["reforco"] = sequencia([nota(freq(n), 0.07, duty=0.25, soltura=0.04)
                              for n in ("G4", "C5", "G5")])
    e["captura_lancar"] = varredura(200, 900, 0.25, duty=0.25) * envelope(int(0.25 * TAXA), soltura=0.08) * 0.5
    e["captura_balanco"] = sequencia([nota(freq("C4"), 0.04, forma="triangulo", soltura=0.03),
                                      np.zeros(int(0.03 * TAXA)),
                                      nota(freq("G3"), 0.06, forma="triangulo", soltura=0.05)])
    e["captura_sucesso"] = sequencia([nota(freq(n), d, duty=0.25, soltura=0.03)
                                      for n, d in (("C5", 0.08), ("E5", 0.08), ("G5", 0.08),
                                                   ("C6", 0.3))])
    e["captura_falha"] = sequencia([nota(0, 0.08, forma="ruido", soltura=0.07) * 0.6,
                                    varredura(600, 200, 0.2, duty=0.25) * envelope(int(0.2 * TAXA), soltura=0.15) * 0.5])
    e["moeda"] = sequencia([nota(freq("B5"), 0.06, duty=0.5, soltura=0.01),
                            nota(freq("E6"), 0.22, duty=0.5, soltura=0.2)])
    e["achado"] = sequencia([nota(freq(n), 0.07, duty=0.125, soltura=0.05)
                             for n in ("E6", "G6", "B6", "E7")])
    e["porta"] = mixar(nota(0, 0.15, forma="ruido", soltura=0.14) * 0.5,
                       nota(freq("C3"), 0.15, forma="triangulo", soltura=0.12))
    e["fisgou"] = sequencia([nota(freq("A5"), 0.05, duty=0.5, soltura=0.01),
                             nota(freq("A5"), 0.05, duty=0.5, soltura=0.01),
                             nota(freq("E6"), 0.15, duty=0.5, soltura=0.1)])
    e["selo"] = mixar(sequencia([nota(freq(n), d, duty=0.5, soltura=0.03)
                                 for n, d in (("G4", 0.12), ("C5", 0.12), ("E5", 0.12),
                                              ("G5", 0.12), ("C6", 0.5))]),
                      sequencia([nota(freq(n), d, forma="triangulo", soltura=0.03)
                                 for n, d in (("C3", 0.24), ("G3", 0.24), ("C4", 0.5))]))
    e["vitoria"] = mixar(sequencia([nota(freq(n), d, duty=0.5, soltura=0.03)
                                    for n, d in (("C5", 0.15), ("C5", 0.15), ("C5", 0.15),
                                                 ("C5", 0.4), ("G#4", 0.4), ("A#4", 0.4),
                                                 ("C5", 0.2), ("A#4", 0.1), ("C5", 0.8))]),
                         sequencia([nota(freq(n), d, forma="triangulo", soltura=0.03)
                                    for n, d in (("C3", 0.85), ("G#2", 0.4), ("A#2", 0.4),
                                                 ("C3", 1.1))]))
    e["derrota"] = mixar(sequencia([nota(freq(n), 0.35, duty=0.25, soltura=0.1)
                                    for n in ("E5", "D#5", "D5", "C#5")] +
                                   [nota(freq("C5"), 0.9, duty=0.25, soltura=0.6)]),
                         sequencia([nota(freq(n), 0.35, forma="triangulo", soltura=0.1)
                                    for n in ("A2", "G#2", "G2", "F#2")] +
                                   [nota(freq("F2"), 0.9, forma="triangulo", soltura=0.6)]))
    e["passos_ponte"] = nota(0, 0.05, forma="ruido", soltura=0.045) * 0.3
    return e


# ------------------------------------------------------------------- musica

def compasso(bpm):
    return 60.0 / bpm


def faixa_melodica(notas, bpm, forma="quadrada", duty=0.25, volume=0.25, legato=0.9):
    """notas: [(nota, batidas)]."""
    b = compasso(bpm)
    partes = []
    for n, batidas in notas:
        seg = batidas * b
        som = nota(freq(n), seg * legato, forma=forma, duty=duty, ataque=0.004, soltura=0.03)
        partes.append(np.concatenate([som, np.zeros(int(seg * TAXA) - som.size)]))
    return sequencia(partes) * volume


def bateria(padrao, bpm, volume=0.12):
    """padrao: string por colcheia: 'k' bumbo, 's' caixa, 'h' chimbal, '.' nada."""
    b = compasso(bpm) / 2
    partes = []
    for p in padrao:
        n = int(b * TAXA)
        if p == "k":
            som = varredura(150, 45, 0.09, forma="triangulo") * envelope(int(0.09 * TAXA), soltura=0.08)
        elif p == "s":
            som = nota(0, 0.08, forma="ruido", soltura=0.07) * 0.8
        elif p == "h":
            som = nota(0, 0.025, forma="ruido", soltura=0.02) * 0.35
        else:
            som = np.zeros(0)
        partes.append(np.concatenate([som[:n], np.zeros(n - min(n, som.size))]))
    return sequencia(partes) * volume


def musica_vila():
    """Do maior, 96 bpm, 8 compassos: C, Am, F, G. Calma, para andar pela vila."""
    bpm = 96
    melodia = [
        ("E5", 1), ("G5", 0.5), ("A5", 0.5), ("G5", 1), ("E5", 1),
        ("C5", 1), ("D5", 0.5), ("E5", 0.5), ("A4", 2),
        ("F5", 1), ("E5", 0.5), ("D5", 0.5), ("C5", 1), ("A4", 1),
        ("B4", 1), ("D5", 1), ("G5", 2),
        ("E5", 1), ("G5", 0.5), ("C6", 0.5), ("B5", 1), ("G5", 1),
        ("A5", 1), ("G5", 0.5), ("E5", 0.5), ("C5", 2),
        ("D5", 1), ("F5", 1), ("A5", 1), ("G5", 1),
        ("E5", 1), ("D5", 1), ("C5", 2),
    ]
    raizes = ["C3", "A2", "F2", "G2", "C3", "A2", "F2", "G2"]
    quintas = ["G3", "E3", "C3", "D3", "G3", "E3", "C3", "D3"]
    baixo = []
    for r, q in zip(raizes, quintas):
        baixo += [(r, 1), (q, 1), (r, 1), (q, 1)]
    return mixar(faixa_melodica(melodia, bpm, duty=0.25, volume=0.22),
                 faixa_melodica(baixo, bpm, forma="triangulo", volume=0.3, legato=0.8),
                 bateria("h.h.h.h." * 8, bpm, volume=0.08))


def musica_batalha():
    """La menor, 144 bpm, 8 compassos: Am, F, G, E. Com pulso de bumbo e caixa."""
    bpm = 144
    melodia = [
        ("A5", 0.5), ("A5", 0.5), ("C6", 0.5), ("A5", 0.5), ("E6", 1), ("D6", 1),
        ("C6", 0.5), ("B5", 0.5), ("A5", 1), ("F5", 2),
        ("G5", 0.5), ("G5", 0.5), ("B5", 0.5), ("G5", 0.5), ("D6", 1), ("C6", 1),
        ("B5", 1), ("G#5", 1), ("E5", 2),
        ("A5", 0.5), ("C6", 0.5), ("E6", 0.5), ("C6", 0.5), ("A6", 1), ("G6", 1),
        ("F6", 0.5), ("E6", 0.5), ("D6", 0.5), ("C6", 0.5), ("D6", 2),
        ("E6", 0.5), ("D6", 0.5), ("C6", 0.5), ("B5", 0.5), ("C6", 1), ("D6", 1),
        ("B5", 1), ("G#5", 1), ("E5", 2),
    ]
    raizes = ["A2", "F2", "G2", "E2", "A2", "F2", "G2", "E2"]
    baixo = []
    for r in raizes:
        oitava = r[:-1] + str(int(r[-1]) + 1)
        baixo += [(r, 0.5), (oitava, 0.5)] * 4
    return mixar(faixa_melodica(melodia, bpm, duty=0.5, volume=0.2),
                 faixa_melodica(baixo, bpm, forma="triangulo", volume=0.32, legato=0.7),
                 bateria("k.h.s.h.k.k.s.h." * 4, bpm, volume=0.14))


def main():
    catalogo = {"_meta": {"descricao": "Gerado por tools/audio/gerar_audio.py. Nao editar a mao.",
                          "taxa": TAXA}, "efeitos": {}, "musicas": {}}
    for nome, amostras in efeitos().items():
        catalogo["efeitos"][nome] = gravar(nome, normalizar(amostras, 0.6))
    for nome, func in (("vila", musica_vila), ("batalha", musica_batalha)):
        catalogo["musicas"][nome] = gravar("musica_" + nome, normalizar(func(), 0.55))
    with open(os.path.join(SAIDA, "sons.json"), "w", encoding="utf-8") as f:
        json.dump(catalogo, f, ensure_ascii=False, indent=2)
        f.write("\n")
    total = sum(os.path.getsize(os.path.join(SAIDA, n)) for n in os.listdir(SAIDA))
    print("ok  %d efeitos, %d musicas, %.1f MB em %s" % (
        len(catalogo["efeitos"]), len(catalogo["musicas"]), total / 1e6, SAIDA))


if __name__ == "__main__":
    main()
