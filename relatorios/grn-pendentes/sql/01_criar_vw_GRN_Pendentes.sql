-- ============================================================
--  GRN pendentes de facturação – criação das views e funções
--  Cria dbo.vw_GRN_Pendentes e dbo.fn_GRN_Pendentes em cada uma
--  das 17 empresas e o consolidado na PRIGERAL.
--  Cegid Evolution ERP Primavera V10.
--  Grupo Naval Angola – Projectos Digitais. CONFIDENCIAL.
--
--  Reexecutável: voltar a correr quando entrar/sair uma empresa
--  ou quando mudar a regra de cálculo.
-- ============================================================
USE PRIGERAL;
GO

SET NOCOUNT ON;

-- ================== EMPRESAS ==================
DECLARE @Empresas TABLE (BD SYSNAME);
INSERT INTO @Empresas (BD)
SELECT N'PRIAGRO'       UNION ALL SELECT N'PRIBIGAS'      UNION ALL
SELECT N'PRICAZENGO'    UNION ALL SELECT N'PRIEMBALTEC'   UNION ALL
SELECT N'PRIEVERYTEL'   UNION ALL SELECT N'PRIGUARDA'     UNION ALL
SELECT N'PRIINDUCLEAN'  UNION ALL SELECT N'PRIINOVAGATE'  UNION ALL
SELECT N'PRILIMPODOURO' UNION ALL SELECT N'PRIMAJITEC'    UNION ALL
SELECT N'PRIMETAL'      UNION ALL SELECT N'PRIMFUTILA'    UNION ALL
SELECT N'PRIOCEANO'     UNION ALL SELECT N'PRIPAKTEC'     UNION ALL
SELECT N'PRIVISTAR'     UNION ALL SELECT N'PRIYAWABA'     UNION ALL
SELECT N'PRIZOMBO';
-- ==============================================

IF OBJECT_ID('tempdb..#Resultado') IS NOT NULL DROP TABLE #Resultado;
CREATE TABLE #Resultado (BD SYSNAME, Objecto NVARCHAR(50), Estado NVARCHAR(10), Mensagem NVARCHAR(2000));

DECLARE @BD        SYSNAME;
DECLARE @Exec      NVARCHAR(300);
DECLARE @ModeloVW  NVARCHAR(MAX);
DECLARE @ModeloFN  NVARCHAR(MAX);
DECLARE @SQL       NVARCHAR(MAX);
DECLARE @POApply   NVARCHAR(MAX);
DECLARE @Colunas   NVARCHAR(MAX);
DECLARE @Consol    NVARCHAR(MAX) = N'';

SET @Colunas = N'Company, GRNNumber, GRNDate, DaysOpen, Ageing, PONumber, VendorCode, VendorName,
       VendorDeliveryNote, ItemCode, ItemDescription, Unit, QtyReceived, QtyInvoiced,
       QtyOutstanding, UnitPrice, ValueOutstanding, Currency, Status, StatusReason';

SET @ModeloVW = N'CREATE VIEW dbo.vw_GRN_Pendentes
AS
SELECT
    CAST(N''{EMP}'' AS NVARCHAR(50))                                                          AS Company,
    CAST(grn.TipoDoc + N'' '' + grn.Serie + N''/'' + CAST(grn.NumDoc AS NVARCHAR(20)) AS NVARCHAR(60)) AS GRNNumber,
    CAST(grn.DataDoc AS DATE)                                                                AS GRNDate,
    DATEDIFF(DAY, grn.DataDoc, GETDATE())                                                    AS DaysOpen,
    CAST(CASE WHEN DATEDIFF(DAY, grn.DataDoc, GETDATE()) < 0   THEN N''Check date''
              WHEN DATEDIFF(DAY, grn.DataDoc, GETDATE()) <= 30 THEN N''0-30 days''
              WHEN DATEDIFF(DAY, grn.DataDoc, GETDATE()) <= 60 THEN N''31-60 days''
              WHEN DATEDIFF(DAY, grn.DataDoc, GETDATE()) <= 90 THEN N''61-90 days''
              ELSE N''> 90 days'' END AS NVARCHAR(20))                                        AS Ageing,
    CAST(po.PONumber AS NVARCHAR(60))                                                        AS PONumber,
    CAST(grn.Entidade AS NVARCHAR(50))                                                       AS VendorCode,
    CAST(COALESCE(f.Nome, grn.Nome) AS NVARCHAR(255))                                        AS VendorName,
    CAST(grn.NumDocExterno AS NVARCHAR(100))                                                 AS VendorDeliveryNote,
    CAST(l.Artigo AS NVARCHAR(100))                                                          AS ItemCode,
    CAST(l.Descricao AS NVARCHAR(512))                                                       AS ItemDescription,
    CAST(l.Unidade AS NVARCHAR(20))                                                          AS Unit,
    CAST(ABS(l.Quantidade) AS DECIMAL(28,6))                                                 AS QtyReceived,
    CAST(ABS(ISNULL(ls.QuantTrans, 0)) AS DECIMAL(28,6))                                     AS QtyInvoiced,
    CAST(ABS(l.Quantidade) - ABS(ISNULL(ls.QuantTrans, 0)) AS DECIMAL(28,6))                 AS QtyOutstanding,
    CAST(ABS(l.PrecUnit) AS DECIMAL(28,6))                                                   AS UnitPrice,
    CAST(ABS((ABS(l.Quantidade) - ABS(ISNULL(ls.QuantTrans, 0))) * l.PrecUnit
             * (1 - ISNULL(l.Desconto1, 0) / 100.0)) AS DECIMAL(18,2))                       AS ValueOutstanding,
    CAST(grn.Moeda AS NVARCHAR(10))                                                          AS Currency,
    CAST(CASE WHEN ls.EstadoTrans = ''R''       THEN N''R - to confirm''
              WHEN ISNULL(ls.QuantTrans, 0) = 0 THEN N''Open - not invoiced''
              ELSE N''Partially invoiced'' END AS NVARCHAR(40))                               AS Status,
    CAST(grn.Observacoes AS NVARCHAR(500))                                                   AS StatusReason
FROM dbo.CabecCompras grn
INNER JOIN dbo.CabecComprasStatus  cs ON cs.IdCabecCompras  = grn.Id
INNER JOIN dbo.LinhasCompras       l  ON l.IdCabecCompras   = grn.Id
INNER JOIN dbo.LinhasComprasStatus ls ON ls.IdLinhasCompras = l.Id
LEFT  JOIN dbo.Fornecedores        f  ON f.Fornecedor       = grn.Entidade
                                     AND grn.TipoEntidade   = ''F''
{PO_APPLY}
WHERE grn.TipoDoc IN (''GRN'', ''GRNI'', ''GRS'')
  AND ls.EstadoTrans IN (''P'', ''R'')
  AND ISNULL(cs.Anulado, 0) = 0
  AND ISNULL(cs.Fechado, 0) = 0
  AND ISNULL(ls.Fechado, 0) = 0
  AND l.Artigo IS NOT NULL
  AND ABS(l.Quantidade) - ABS(ISNULL(ls.QuantTrans, 0)) > 0.0001';

SET @ModeloFN = N'CREATE FUNCTION dbo.fn_GRN_Pendentes
(
    @DataInicial DATE,
    @DataFinal   DATE
)
RETURNS TABLE
AS
RETURN
    SELECT ' + @Colunas + N'
    FROM dbo.vw_GRN_Pendentes
    WHERE GRNDate >= ISNULL(@DataInicial, ''19000101'')
      AND GRNDate <= ISNULL(@DataFinal,   ''99991231'')';

-- Remover primeiro o consolidado (depende das views das empresas)
IF OBJECT_ID(N'dbo.fn_GRN_Pendentes') IS NOT NULL
    DROP FUNCTION dbo.fn_GRN_Pendentes;

IF OBJECT_ID(N'dbo.vw_GRN_Pendentes', N'V') IS NOT NULL
    DROP VIEW dbo.vw_GRN_Pendentes;

DECLARE cBD CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.BD
    FROM @Empresas e
    INNER JOIN sys.databases d ON d.name = e.BD
    WHERE d.state_desc = 'ONLINE'
      AND HAS_DBACCESS(e.BD) = 1
      AND OBJECT_ID(QUOTENAME(e.BD) + N'.dbo.CabecCompras') IS NOT NULL
    ORDER BY e.BD;

OPEN cBD;
FETCH NEXT FROM cBD INTO @BD;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Exec = QUOTENAME(@BD) + N'.sys.sp_executesql';

    SET @POApply = CASE
        WHEN OBJECT_ID(QUOTENAME(@BD) + N'.dbo.LinhasComprasTrans') IS NOT NULL
         AND COL_LENGTH(QUOTENAME(@BD) + N'.dbo.LinhasComprasTrans', N'IdLinhasCompras') IS NOT NULL
         AND COL_LENGTH(QUOTENAME(@BD) + N'.dbo.LinhasComprasTrans', N'IdLinhasComprasOrigem') IS NOT NULL
        THEN N'OUTER APPLY (SELECT TOP 1 co.TipoDoc + N'' '' + co.Serie + N''/'' + CAST(co.NumDoc AS NVARCHAR(20)) AS PONumber
             FROM dbo.LinhasComprasTrans t
             INNER JOIN dbo.LinhasCompras lo ON lo.Id = t.IdLinhasComprasOrigem
             INNER JOIN dbo.CabecCompras  co ON co.Id = lo.IdCabecCompras
             WHERE t.IdLinhasCompras = l.Id) po'
        ELSE N'OUTER APPLY (SELECT CAST(NULL AS NVARCHAR(60)) AS PONumber) po'
    END;

    SET @SQL = REPLACE(@ModeloVW, N'{PO_APPLY}', @POApply);
    SET @SQL = REPLACE(@SQL, N'{EMP}', SUBSTRING(@BD, 4, 50));

    BEGIN TRY
        EXEC @Exec N'IF OBJECT_ID(N''dbo.fn_GRN_Pendentes'') IS NOT NULL DROP FUNCTION dbo.fn_GRN_Pendentes;';
        EXEC @Exec N'IF OBJECT_ID(N''dbo.vw_GRN_Pendentes'', N''V'') IS NOT NULL DROP VIEW dbo.vw_GRN_Pendentes;';
        EXEC @Exec @SQL;
        INSERT INTO #Resultado VALUES (@BD, N'vw_GRN_Pendentes', N'OK', NULL);

        SET @Consol = @Consol
                    + CASE WHEN @Consol = N'' THEN N'' ELSE N'
UNION ALL
' END
                    + N'SELECT ' + @Colunas + N'
FROM ' + QUOTENAME(@BD) + N'.dbo.vw_GRN_Pendentes';
    END TRY
    BEGIN CATCH
        INSERT INTO #Resultado VALUES (@BD, N'vw_GRN_Pendentes', N'ERRO', ERROR_MESSAGE());
    END CATCH

    BEGIN TRY
        EXEC @Exec @ModeloFN;
        INSERT INTO #Resultado VALUES (@BD, N'fn_GRN_Pendentes', N'OK', NULL);
    END TRY
    BEGIN CATCH
        INSERT INTO #Resultado VALUES (@BD, N'fn_GRN_Pendentes', N'ERRO', ERROR_MESSAGE());
    END CATCH

    FETCH NEXT FROM cBD INTO @BD
END

CLOSE cBD;
DEALLOCATE cBD;

-- Consolidado na PRIGERAL
BEGIN TRY
    SET @SQL = N'CREATE VIEW dbo.vw_GRN_Pendentes
AS
' + @Consol;
    EXEC (@SQL);
    INSERT INTO #Resultado VALUES (N'PRIGERAL', N'vw_GRN_Pendentes', N'OK', NULL);

    EXEC (@ModeloFN);
    INSERT INTO #Resultado VALUES (N'PRIGERAL', N'fn_GRN_Pendentes', N'OK', NULL);
END TRY
BEGIN CATCH
    INSERT INTO #Resultado VALUES (N'PRIGERAL', N'consolidado', N'ERRO', ERROR_MESSAGE());
END CATCH

-- Resultado 1: estado da criação por BD
SELECT BD, Objecto, Estado, Mensagem
FROM #Resultado
ORDER BY Estado DESC, CASE WHEN BD = N'PRIGERAL' THEN 1 ELSE 0 END, BD, Objecto;

-- Resultado 2: verificação do consolidado
SELECT Company, Currency,
       COUNT(DISTINCT GRNNumber) AS OpenGRNs,
       COUNT(*)                  AS Lines,
       SUM(ValueOutstanding)     AS TotalValueOutstanding
FROM PRIGERAL.dbo.vw_GRN_Pendentes
GROUP BY Company, Currency
ORDER BY Company, Currency;
