SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure to DELETE used authorisation codes for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
    SELECT 
		p.[name] 
	FROM 
		sys.procedures p
		INNER JOIN sys.schemas s ON p.[schema_id] = s.[schema_id]
    WHERE
        p.[type] = 'P'
		AND p.[name] = 'wsp_RestApiAuthorisationCodesDelete'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiAuthorisationCodesDelete AS PRINT ''dbo.wsp_RestApiAuthorisationCodesDelete''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiAuthorisationCodesDelete]
	@uuid nvarchar(36)
AS
BEGIN
	SET NOCOUNT ON;
	
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	DELETE FROM
		RestApiAuthorisationCodes
	WHERE
		CodeUUID = @uuid;

	--OPTION (OPTIMIZE FOR (@uuid UNKNOWN));

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
