
/****** Object:  StoredProcedure [dbo].[ACA_RID_RM_Process]    Script Date: 22/05/2017 07:39:41 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[ACA_RID_RM_Process] @Proceso smallint, @TRXDATE DATETIME, @USERID CHAR(15), @BACHNUMB CHAR(15),  -- 1=Reclasificar; 2=Revertir
@TABLA CHAR(100) 
AS
--DROP PROCEDURE ACA_RID_RM_Process
-- EXEC ACA_RID_RM_Process 2, '20121224', 'sa', 'TESTREV121224', '##1000946'
DECLARE @EJECUTAR varchar(4000)
DECLARE @VCHRNMBR CHAR(21)

CREATE TABLE #TEMPORAL
	(VCHRNMBR CHAR(21)
	, DEX_ROW_ID INT identity(1,1)
	)

IF @Proceso = 1
BEGIN
	SELECT @EJECUTAR = 'INSERT INTO #TEMPORAL SELECT A.VCHRNMBR FROM ' + RTRIM(@TABLA) + ' A LEFT OUTER JOIN ACA_RID10000 B ON A.VCHRNMBR = B.VCHRNMBR WHERE A.COMMENT1 IN(' + char(39) + 'Debe reclasificar' + char(39) + ', ' + char(39) + 'OK (Puede reclasificar)' + char(39) + ') AND Selected_To_Print = 1 AND ISNULL(B.TXDTLTYP, 1) = 1 AND ISNULL(B.ACA_RID_Tax_Status, 2) = 2 AND ISNULL(B.ACA_RID_LAST, 1) = 1 '
END
ELSE
BEGIN
	SELECT @EJECUTAR = 'INSERT INTO #TEMPORAL SELECT A.VCHRNMBR FROM ' + RTRIM(@TABLA) + ' A LEFT OUTER JOIN ACA_RID10000 B ON A.VCHRNMBR = B.VCHRNMBR WHERE A.COMMENT1 IN(' + char(39) + 'OK (puede revertir)' + char(39) + ', ' + char(39) + 'Debe revertir' + char(39) + + ', ' + char(39) + 'Debe revertir o corregir FC IE' + char(39) + ') AND Selected_To_Print = 1 AND ISNULL(B.TXDTLTYP, 1) = 1 AND ISNULL(B.ACA_RID_Tax_Status, 1) = 1 AND ISNULL(B.ACA_RID_LAST, 1) = 1  '
END
EXEC (@EJECUTAR)

PRINT 'COUNT TEMPORAL' 
DECLARE @CUENTA INT
SELECT @CUENTA = COUNT(VCHRNMBR) FROM #TEMPORAL
PRINT @CUENTA

DECLARE PAGOS CURSOR FOR SELECT VCHRNMBR FROM #TEMPORAL
OPEN PAGOS
FETCH NEXT FROM PAGOS INTO @VCHRNMBR
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @Proceso = 1
	BEGIN
		PRINT 'LLAMA ACA_RID_Reimputacion_Impuestos_RM_OPEN_HIST'
		EXEC ACA_RID_Reimputacion_Impuestos_RM_OPEN_HIST @VCHRNMBR, @TRXDATE, @BACHNUMB, @USERID
	END
	ELSE
	BEGIN
		EXEC ACA_RID_RM_Revertir @VCHRNMBR, @TRXDATE, @BACHNUMB, @USERID
	END
	SELECT @EJECUTAR = 'DELETE ' + RTRIM(@TABLA) + ' WHERE VCHRNMBR = ' + CHAR(39) + RTRIM(@VCHRNMBR) + CHAR(39) + ' '
	EXEC (@EJECUTAR)
	FETCH NEXT FROM PAGOS INTO @VCHRNMBR
END
CLOSE PAGOS
DEALLOCATE PAGOS

go