# Dados — Tabelas de Probabilidade Condicionada

Tabelas que definem P(atributo derivado | atributos primários), como
**recursos de dados** (`.tres` ou JSON) — nunca hardcoded no código, para
permitir calibração sem recompilar a lógica.

Exemplos de correlação esperada:
- Fogo + Gato → cores quentes, garras, presas (alta prob.)
- Água + Peixe → cores frias, escamas, nadadeiras (alta prob.)

Consumidas pela Camada 2 (`procedural/creatures/`). Alterar uma tabela aqui
muda o bestiário mantendo o determinismo por seed (RF03).
