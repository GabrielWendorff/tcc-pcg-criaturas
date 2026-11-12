# Prova de autoria: onde está cada resposta

As 25 perguntas típicas do [guia do Playbook](https://github.com/CatolicaSC-Portfolio/The-Portfolio-Playbook/blob/main/documentation/guia-prova-de-autoria.md),
adaptadas para a linha de Jogos Digitais, com o lugar do código que responde cada uma. A
resposta é sua: este mapa só diz onde abrir.

## Arquitetura e decisões

| # | Pergunta | Onde abrir |
|---|---|---|
| 1 | Arquitetura, do clique ao dado | Wiki → Arquitetura; `presentation/exploracao/mundo.gd` costura tudo; o dado sai de `procedural/creatures/gerador_criaturas.gd` e vai para o save em `sistemas/regras/dados_partida.gd` |
| 2 | Por que Godot e GDScript | `docs/GDD.md` §12; Wiki → Decisões Técnicas |
| 3 | Ponto de entrada | `project.godot` → `run/main_scene` (`presentation/menu/menu_principal.tscn`) e os autoloads `Save`, `Opcoes`, `Bolsa`, `RegistroSessao`, `Audio` |

## Configuração e ambiente

| # | Pergunta | Onde abrir |
|---|---|---|
| 4 | Banco e produção | não há banco: dados em JSON (`data/`, `autoral/`) e save em `user://` (`sistemas/regras/arquivo_save.gd`); a build de entrega desliga F2, F3 e F4 (`OS.is_debug_build()`) |
| 5 | Variáveis de ambiente | só no CI: `BUTLER_API_KEY` e `ITCH_ALVO` (`.github/workflows/ci.yml`) |
| 6 | Rodar do zero | README e Wiki → Como Executar e Testar: `godot --headless --path . --import`, depois `godot --path .` |

## Dados

| # | Pergunta | Onde abrir |
|---|---|---|
| 7 | Entidades | `Criatura` (`procedural/creatures/criatura.gd`), `FichaCombate`, `DadosPartida`, `CriaturaSalva` |
| 8 | Última mudança de esquema | `DadosPartida.modelo_gerador` (campo opcional, sem migração) e `_migrar()` |
| 9 | Isolamento entre usuários | jogo local de um jogador; os 3 slots são independentes (`ArquivoSave`) |

## Autenticação e segurança

| # | Pergunta | Onde abrir |
|---|---|---|
| 10–11 | Autenticação e autorização | não se aplicam: jogo offline, sem conta |
| 12 | Dados sensíveis e entrada inválida | save em JSON validado (`DadosPartida._validar`), recusa modelo desconhecido e versão futura; o log não guarda nada pessoal |

## Regras do jogo

| # | Pergunta | Onde abrir |
|---|---|---|
| 13 | Regra principal, linha a linha | `GeradorCriaturas._gerar_uma_v2` e `TabelasProbabilidade.prob_feature_v2` |
| 14 | Dado inválido | tabelas validadas por `tools/validate_tables.py`; seed em texto vira número por FNV-1a (`sistemas/regras/semente.gd`) |
| 15 | Erros em produção | `sistemas/registro_sessao.gd`: cada erro de script vai para `user://logs/` com arquivo e linha |

## Integrações

| # | Pergunta | Onde abrir |
|---|---|---|
| 16 | Comunicação entre partes | sinais: `GerenciadorEncontro.encontro_terminado` → `mundo.gd`; o "dono da tela" em `mundo.gd` |
| 17 | Serviço externo | só o itch.io, na publicação; o jogo roda sem rede |

## Testes e qualidade

| # | Pergunta | Onde abrir |
|---|---|---|
| 18 | Quais testes e o que verificam | `tools/rodar_testes.sh` (20 testes); exemplo: `tools/test_gerador_v2.gd` confere que a v1 não mudou (hash) e que os 64 pares aparecem |
| 19 | Mudar uma regra e ver o teste falhar | mudar `percentil_forca` de um guardião → `simular_batalha.gd` acusa; mudar `expoente_vies_elemento` em `data/modelo_v2.json` → `comparar_bracos.gd` acusa |

## CI/CD e deploy

| # | Pergunta | Onde abrir |
|---|---|---|
| 20 | Rodar manualmente | trocar `on: push` por `workflow_dispatch` em `.github/workflows/ci.yml` |
| 21 | Etapas e falhas | testes → gdlint → builds → publicar-itch; qualquer falha para o pipeline e o merge |
| 22 | Hospedagem e voltar versão | itch.io por butler; voltar = republicar o commit anterior, ou reverter o merge e deixar o CI publicar |

## Processo e histórico

| # | Pergunta | Onde abrir |
|---|---|---|
| 23 | Um commit explicado | `cf309e2` (gerador v2): o que mudou e as quedas declaradas em `docs/mudancas-estruturais.md` |
| 24 | Bug mais difícil | queda da build ao voltar ao save depois de perder (`cc6e2d4`): trocar de cena dentro do evento de entrada; corrigido adiando a troca |

## Mudança ao vivo

| # | Pergunta | Como fazer |
|---|---|---|
| 25 | Campo novo até a tela | exemplo: um prêmio novo de guardião → `autoral/guardioes/guardioes.json` → `mundo.gd::_ao_vencer_duelo` → `_nota`; rodar `test_arco` |
