# GRN pendentes de facturação

Relatório das guias de recepção (GRN, GRNI, GRS) registadas no **Cegid Evolution ERP Primavera V10** e ainda não convertidas, total ou parcialmente, em factura de fornecedor. Serve para acompanhar os pendentes de recepção e desbloquear a conciliação entre Armazém, Compras e Contabilidade.

> Documento confidencial – Grupo Naval Angola, Projectos Digitais.

## Lógica

- Linhas de GRN/GRNI/GRS com estado de transformação `P` (pendente) ou `R`, documento não anulado nem fechado, e quantidade por facturar superior a 0,0001 (tolerância de arredondamento).
- No Primavera as quantidades das guias são gravadas a negativo; o relatório usa valores absolutos.
- A PO de origem é obtida pela tabela de transformações (`LinhasComprasTrans`), quando existe.
- `Ageing`: 0-30, 31-60, 61-90, > 90 dias e `Check date` (data no futuro).
- `StatusReason`: observações da GRN – o motivo do atraso pode ser registado no próprio documento.

## Objectos

| BD | Objecto | Descrição |
|---|---|---|
| Cada uma das 17 empresas | `dbo.vw_GRN_Pendentes` | Pendentes da empresa |
| Cada uma das 17 empresas | `dbo.fn_GRN_Pendentes(@DataInicial, @DataFinal)` | Idem, filtrado por datas |
| PRIGERAL | `dbo.vw_GRN_Pendentes` | Consolidado (UNION ALL das views das empresas) |
| PRIGERAL | `dbo.fn_GRN_Pendentes(@DataInicial, @DataFinal)` | Consolidado filtrado por datas |

## Ficheiros

| Ficheiro | Utilização |
|---|---|
| `sql/01_criar_vw_GRN_Pendentes.sql` | Cria/recria todos os objectos (SSMS, F5) |
| `sql/02_lista_empresa.sql` | Query SQL da lista **GRN Pendentes de Facturação** |
| `sql/03_lista_consolidado.sql` | Query SQL da lista **GRN Pendentes de Facturação – Consolidado** |

## Listas no Primavera

- Parâmetros **From** e **To**, tipo Data, sem valor (pedidos ao utilizador na execução).
- A Query SQL não aceita `ORDER BY`: ordenar na lista por Company, GRN Date, GRN Number.
- Totais: somar **Value Outstanding** agrupado por **Currency** (AKZ e USD não se somam).
