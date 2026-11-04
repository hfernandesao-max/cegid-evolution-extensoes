# Cegid Evolution ERP Primavera – Extensões e relatórios internos

Desenvolvimentos internos do **Grupo Naval Angola** para o Cegid Evolution ERP Primavera V10, mantidos pela área de **Projectos Digitais**.

> Repositório privado. Conteúdo confidencial.

## Conteúdo

| Pasta | Tipo | Descrição | Versão |
|---|---|---|---|
| [`adf-validacao-po/`](adf-validacao-po/) | Extensão (C#) | Obriga a indicar PO válidas do fornecedor no Número do Documento dos ADF | 1.1.0 |
| [`relatorios/grn-pendentes/`](relatorios/grn-pendentes/) | Views SQL + listas | GRN pendentes de facturação, por empresa e consolidado na PRIGERAL | 1.0 |

## Ambiente

- Cegid Evolution ERP Primavera V10 – `C:\Program Files\PRIMAVERA\SG100`
- 17 empresas em produção: AGRO, BIGAS, CAZENGO, EMBALTEC, EVERYTEL, GUARDA, INDUCLEAN, INOVAGATE, LIMPODOURO, MAJITEC, METAL, MFUTILA, OCEANO, PAKTEC, VISTAR, YAWABA, ZOMBO
- BD global de consolidação: PRIGERAL
- Testes: PRIFORMACAO (nunca testar directamente em produção)

## Regras de trabalho

1. Cada desenvolvimento tem a sua pasta, com `README.md` e `CHANGELOG.md`.
2. Os `.dll` compilados ficam em `releases/vX.Y/`, com o SHA-256 registado no CHANGELOG.
3. Testar sempre na PRIFORMACAO antes de registar nas empresas.
4. Em cada nova versão de uma extensão, remover e voltar a registar no Administrador.
