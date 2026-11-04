-- ============================================================
--  Lista Primavera: "GRN Pendentes de Facturação – Consolidado" (PRIGERAL)
--  Colar no separador Query SQL da lista. Parâmetros: From, To (Data).
--  A ordenação define-se na lista (a Query SQL não aceita ORDER BY).
-- ============================================================
SELECT
    Company             AS [Company],
    GRNNumber           AS [GRN Number],
    GRNDate             AS [GRN Date],
    DaysOpen            AS [Days Open],
    Ageing              AS [Ageing],
    PONumber            AS [PO Number],
    VendorCode          AS [Vendor Code],
    VendorName          AS [Vendor Name],
    VendorDeliveryNote  AS [Vendor Delivery Note],
    ItemCode            AS [Item Code],
    ItemDescription     AS [Item Description],
    Unit                AS [Unit],
    QtyReceived         AS [Qty Received],
    QtyInvoiced         AS [Qty Invoiced],
    QtyOutstanding      AS [Qty Outstanding],
    UnitPrice           AS [Unit Price],
    ValueOutstanding    AS [Value Outstanding],
    Currency            AS [Currency],
    Status              AS [Status],
    StatusReason        AS [Status / Reason]
FROM PRIGERAL.dbo.vw_GRN_Pendentes
WHERE GRNDate >= COALESCE(TRY_CONVERT(DATE, '@From@', 103),
                          TRY_CONVERT(DATE, '@From@', 105),
                          TRY_CONVERT(DATE, '@From@', 23),
                          TRY_CONVERT(DATE, '@From@'),
                          CAST('19000101' AS DATE))
  AND GRNDate <= COALESCE(TRY_CONVERT(DATE, '@To@', 103),
                          TRY_CONVERT(DATE, '@To@', 105),
                          TRY_CONVERT(DATE, '@To@', 23),
                          TRY_CONVERT(DATE, '@To@'),
                          CAST('99991231' AS DATE))
