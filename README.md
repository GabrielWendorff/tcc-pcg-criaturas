# RPG 2D com PCG e Coerência Semântica

Jogo de coleta de criaturas em que cada seed gera um bestiário próprio, com cerca de 100
criaturas cujos atributos fazem sentido entre si. Em vez de sortear cor, garras ou nadadeiras de
forma independente, o gerador sorteia esses atributos com **probabilidade condicionada** ao
elemento e ao animal base da criatura.

Trabalho de Portfólio PAC VII/VIII do Centro Universitário Católica de Santa Catarina, de
Gabriel Wendorff. Feito em Godot 4 e GDScript.

**[Documentação completa na Wiki](https://github.com/GabrielWendorff/tcc-pcg-criaturas/wiki)**

## Por que isto existe

Jogos comerciais geram conteúdo em escala e em tempo real, mas sem coerência entre os atributos.
Trabalhos acadêmicos alcançam coerência, mas sem desempenho de tempo real. Este projeto busca os
três ao mesmo tempo com um mecanismo leve: tabelas de probabilidade condicionada, sem busca
evolutiva.

Medido na seed de teste:

| | Resultado |
|---|---|
| Geração de 100 criaturas | 1,59 ms (meta: abaixo de 2 s) |
| Informação mútua contra o sorteio independente (n=5000) | de 33 a 181 vezes maior |
| Criaturas distintas (distância de Hamming, k=3) | 91 de 100, nenhuma duplicata exata |
| Reprodutibilidade pela seed | verificada por teste |

## O jogo

Você escolhe uma seed e recebe a primeira criatura na vila. Depois captura e pesca outras para montar
uma equipe e enfrenta a guardiã do sítio. Ler o corpo da criatura importa: quem tem garras bate mais
forte e tem um golpe de garra, mas é mais difícil de capturar. Nenhuma dessas regras é escrita por
espécie: todas são derivadas dos atributos que o gerador sorteou.

## Estado

| Parte | Estado |
|---|---|
| Gerador de criaturas e métricas | funcionando; versão 2 planejada |
| Exploração, encontro, captura e pesca | funcionando |
| Batalha, vitória e derrota | funcionando, com 1 guardiã; faltam 2 guardiões e o duelo final |
| Arte de escamas, asas e nadadeiras | sorteadas e medidas, ainda não desenhadas |
| Ambientação gerada pela seed | ainda não implementada |
| Build pública | prevista |

O que falta até a entrega está no [Roteiro](https://github.com/GabrielWendorff/tcc-pcg-criaturas/wiki/Roteiro).

## Como rodar

Requer **Godot 4.7**.

```bash
git clone https://github.com/GabrielWendorff/tcc-pcg-criaturas.git
cd tcc-pcg-criaturas
godot --headless --path . --import   # uma vez, em clone novo
godot --path .
```

Controles: setas ou WASD para andar, **E** para falar e confirmar, **Q** para a roda de itens, **F** para
usar o item na mão, **B** para a bolsa, **M** para o mapa e **ESC** para a pausa.

## Testes

```bash
godot --headless --path . -s res://tools/test_gerador.gd       # gerador e métricas
godot --headless --path . -s res://tools/test_batalha.gd       # regra de combate
godot --headless --path . res://tools/test_arco.tscn           # o jogo de ponta a ponta
godot --headless --path . -s res://tools/simular_batalha.gd    # critérios de balanceamento
```

A lista completa e os problemas conhecidos estão em
[Como Executar e Testar](https://github.com/GabrielWendorff/tcc-pcg-criaturas/wiki/Como-Executar-e-Testar).

## Estrutura

```
autoral/        Camada 1: mapa, NPCs, diálogos e guardiões, fixos em toda partida
procedural/     Camadas 2 e 3: gerador de criaturas e métricas; ambientação
data/           tabelas do modelo e balanceamento de jogo, em JSON
presentation/   Camada 4: exploração, encontro, batalha, pesca, diálogo
sistemas/       save, opções e bolsa
arte/           máscaras de pixel art e shader de paleta
tools/          testes, simulador e geradores de arte e mapa
docs/           plano, pendências e registro de mudanças do modelo
```

Cada módulo tem um README próprio. A visão de conjunto está em
[Arquitetura](https://github.com/GabrielWendorff/tcc-pcg-criaturas/wiki/Arquitetura) e os porquês em
[Decisões Técnicas](https://github.com/GabrielWendorff/tcc-pcg-criaturas/wiki/Decisoes-Tecnicas).
