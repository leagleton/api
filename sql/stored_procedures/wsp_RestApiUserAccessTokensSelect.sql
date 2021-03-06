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
-- Description:	Stored procedure for SELECTing access tokens for the specified user for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiUserAccessTokensSelect'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiUserAccessTokensSelect AS PRINT ''wsp_RestApiUserAccessTokensSelect''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiUserAccessTokensSelect
	@user bigint
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	SELECT 
		rat.RestApiAccessToken,
		rat.Expires,
		rac.RestApiClientId
	FROM 
		RestApiAccessTokens rat
		INNER JOIN RestApiClients rac ON rac.RestApiClient = rat.RestApiClient
	WHERE
		rat.RestApiUser = @user
	GROUP BY
		rat.RestApiAccessToken,
		rat.Expires,
		rac.RestApiClientId;	

	--OPTION (OPTIMIZE FOR (@user UNKNOWN));	

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
