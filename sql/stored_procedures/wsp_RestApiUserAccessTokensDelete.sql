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
-- Description:	Stored procedure to DELETE a specified access token for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiUserAccessTokensDelete'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiUserAccessTokensDelete AS PRINT ''wsp_RestApiUserAccessTokensDelete''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiUserAccessTokensDelete
	@token bigint
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	DELETE FROM
		RestApiAccessTokens
	WHERE
		RestApiAccessToken = @token;

	--OPTION (OPTIMIZE FOR (@token UNKNOWN));

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
