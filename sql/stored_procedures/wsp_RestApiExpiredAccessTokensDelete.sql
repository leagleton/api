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
-- Description:	Stored procedure to DELETE expired Access Tokens for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiExpiredAccessTokensDelete'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiExpiredAccessTokensDelete AS PRINT ''wsp_RestApiExpiredAccessTokensDelete''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiExpiredAccessTokensDelete]
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	DELETE FROM 
		RestApiAccessTokens 
	WHERE 
		Expires < GETDATE();

	DELETE FROM 
		RestApiAuthorisationCodes
	WHERE 
		Expires < GETDATE();

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
