# GR / IR Report (encomendas × recepções × facturas)

Lista do **Cegid Evolution ERP Primavera V10** que cruza cada linha de encomenda (PO*) com a guia de recepção (GR) e a factura do fornecedor (IR), mostrando quantidades, valores e diferenças.

> Documento confidencial – Grupo Naval Angola, Gestão de Projectos Digitais.

## Objectos

| BD | Objecto | Descrição |
|---|---|---|
| Cada uma das 17 empresas | `dbo.GRIR_Report` | View da empresa (30 colunas) |
| PRIGERAL | `dbo.vw_GR_IR_Report` | Consolidado das 17 empresas + coluna `Company` |
| Todas as BD | Lista **GR / IR - Report** | Query própria de cada empresa (25 a 27 colunas, versões diferentes) |
| Todas as BD | Lista **Global GR IR - Report** | Lê `PRIGERAL.dbo.vw_GR_IR_Report` |

## Intervenções

| Data | Alteração | Cópias de segurança |
|---|---|---|
| 10-11-2026 | Coluna `Supplier Code & Name` → `Supplier Code - Name` em `QB_Queries` e `QB_Campos` (21 listas, 17 empresas + PRIGERAL). O `&` impedia abrir/actualizar a lista (erro XML 0x26). | `BK_QB_Campos_20261110`, `BK_QB_Queries_20261110` em cada BD |
| 12-11-2026 | View `GRIR_Report`: `&` retirado e **IR Date** corrigida (usava a data da GRN; passa a usar a data da factura). Nova view consolidada `vw_GR_IR_Report` com as 17 empresas (antes: MAJITEC em falta, LIMPODOURO a ler da MAJITEC, "ÕCEANO"). Lista Global passa a ler a view consolidada. Validação: 4 949 linhas, empresa = consolidado. | `PRIGERAL.dbo.BK_Vistas_20261112`, `BK_QB_Queries_20261112` em cada BD |

## Pendente

- Listas repetidas com versões diferentes: OCEANO (2 × GR / IR - Report), VISTAR (2 × GR / IR - Report + FS / IR - Report), YAWABA ("GR / IR - Report" e "GR / IR Report"). Decidir a versão oficial.
- Nomes de colunas com espaço no fim (`GRN Date `, `IR Date `) e "Unit of Massive" mantidos para não alterar a configuração das listas.
