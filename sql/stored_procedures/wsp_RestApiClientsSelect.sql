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
-- Description:	Stored procedure for SELECTing the requested client(s) for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
    SELECT * FROM sys.procedures p
    JOIN sys.schemas s
    ON p.schema_id = s.schema_id
    WHERE
        p.[type] = 'P'
    AND
        p.[name] = 'wsp_RestApiClientsSelect'
    AND
        s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiClientsSelect AS PRINT ''dbo.wsp_RestApiClientsSelect''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiClientsSelect]
	@client bigint = null,
	@clientId nvarchar(32) = null,
	@user bigint = null
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	SELECT 
		c.RestApiClient AS RestApiClient,
		c.RestApiClientId AS RestApiClientId,
		c.[Secret] AS [Secret],
		c.RedirectURI AS RedirectURI,
		uc.Scopes AS Scopes
	FROM RestApiClients c
		INNER JOIN RestApiUserClients uc ON uc.RestApiClient = c.RestApiClient
	WHERE
		c.RestApiClient = COALESCE(@client, c.RestApiClient)
		AND c.RestApiClientId = COALESCE(@clientId, c.RestApiClientId)
		AND uc.RestApiUser = COALESCE(@user, uc.RestApiUser)
	GROUP BY
		c.RestApiClient,
		c.RestApiClientId,
		c.[Secret],
		c.RedirectURI,
		uc.Scopes;

	--OPTION (OPTIMIZE FOR (@client UNKNOWN, @clientId UNKNOWN, @user UNKNOWN));

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
