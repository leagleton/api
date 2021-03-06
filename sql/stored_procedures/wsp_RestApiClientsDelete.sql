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
-- Description:	Stored procedure to DELETE the specified client for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiClientsDelete'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiClientsDelete AS PRINT ''dbo.wsp_RestApiClientsDelete''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiClientsDelete]
	@client bigint
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;

	DELETE FROM
		RestApiUserClients
	WHERE
		RestApiClient = @client;

	DELETE FROM
		RestApiAuthorisationCodes
	WHERE
		RestApiClient = @client;

	DELETE FROM
		RestApiAccessTokens
	WHERE
		RestApiClient = @client;

	DELETE FROM
		RestApiClients
	WHERE
		RestApiClient = @client;

	--OPTION (OPTIMIZE FOR (@client UNKNOWN));

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
