"""Regioes autorais do mundo. Um arquivo por lugar.

Cada modulo exporta:
    REGIAO    dict com id, nome, descricao, icone, cor e retangulo na grade
    construir(m)  pinta terreno, encaixa construcoes e registra pontos de encontro

A ORDEM em que gerar_mundo.py chama os modulos importa: terreno depois sobrescreve
terreno antes, e `livre()` ja considera o que as regioes anteriores ocuparam. As
ligacoes (estradas, pontes, bordas) rodam por ultimo, por isso.
"""
