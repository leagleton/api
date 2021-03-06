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
-- Description:	Stored procedure for INSERTing new clients for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiClientsInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiClientsInsert AS PRINT ''dbo.wsp_RestApiClientsInsert''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiClientsInsert]
	@clientId nvarchar(32),
	@secret nvarchar(32),
	@redirectUri nvarchar(100),
	@user bigint,
	@scopes nvarchar(1000),
	@client bigint OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	IF ISNUMERIC(REPLACE(@scopes, ',', '')) = 0
		BEGIN
			SET @scopes = dbo.wfn_RestApiConvertScopes(@scopes);
		END;

	BEGIN
		INSERT INTO
			RestApiClients (
				RestApiClientId,
				[Secret],
				RedirectURI
			)
			VALUES
			(
				@clientId,
				@secret,
				@redirectUri
			);

			SET @client = (SELECT SCOPE_IDENTITY());
			
		INSERT INTO
			RestApiUserClients (
				RestApiUser,
				RestApiClient,
				Scopes
			)
			VALUES
			(
				@user,
				@client,
				@scopes
			);
	END;

	SELECT @client AS [client];

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
