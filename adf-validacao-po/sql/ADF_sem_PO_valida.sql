-- ============================================================
--  Controlo: ADF a fornecedores sem PO válida no Número do Documento
--  Cegid Evolution ERP Primavera V10 – executar na BD da empresa.
--  Grupo Naval Angola – Projectos Digitais. CONFIDENCIAL.
-- ============================================================
USE PRIVISTAR;   -- <<< BD da empresa
GO

SELECT
    h.Entidade                                       AS [Vendor Code],
    f.Nome                                           AS [Vendor Name],
    h.TipoDoc + ' ' + h.Serie + '/' + CAST(h.NumDocInt AS VARCHAR(20)) AS [ADF Number],
    CAST(h.DataDoc AS DATE)                          AS [ADF Date],
    h.NumDoc                                         AS [Document Number],
    h.ValorTotal                                     AS [Amount],
    h.Moeda                                          AS [Currency],
    ISNULL(p.ValorPendente, 0)                       AS [Amount Not Used],
    h.Utilizador                                     AS [User],
    po.PONumber                                      AS [PO Found],
    CASE WHEN po.PONumber IS NULL THEN 'Missing / invalid PO'
         ELSE 'OK' END                               AS [PO Check]
FROM dbo.Historico h
LEFT JOIN dbo.Fornecedores f ON f.Fornecedor = h.Entidade
LEFT JOIN dbo.Pendentes    p ON p.IdHistorico = h.Id
OUTER APPLY (
    SELECT TOP 1 c.TipoDoc + ' ' + c.Serie + '/' + CAST(c.NumDoc AS VARCHAR(20)) AS PONumber
    FROM dbo.CabecCompras c
    INNER JOIN dbo.CabecComprasStatus cs ON cs.IdCabecCompras = c.Id
    WHERE c.TipoDoc IN ('PO', 'POL', 'POS', 'POM', 'POI', 'ECF')
      AND c.Entidade = h.Entidade
      AND ISNULL(cs.Anulado, 0) = 0
      AND ' ' + REPLACE(REPLACE(h.NumDoc, '.', ' '), '-', ' ') + ' '
          LIKE '% ' + c.TipoDoc + ' ' + c.Serie + '/' + CAST(c.NumDoc AS VARCHAR(20)) + '[^0-9]%'
) po
WHERE h.TipoDoc = 'ADF'
  AND h.TipoEntidade = 'F'
  AND ISNULL(h.Anulado, 0) = 0
ORDER BY [PO Check], h.DataDoc DESC;
