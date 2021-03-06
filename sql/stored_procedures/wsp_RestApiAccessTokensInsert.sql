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
-- Description:	Stored procedure for INSERTing access tokens for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiAccessTokensInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiAccessTokensInsert AS PRINT ''dbo.wsp_RestApiAccessTokensInsert''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiAccessTokensInsert
	@uuid nvarchar(36),
	@expires datetime,
	@scopes nvarchar(1000),
	@user bigint,
	@client bigint,
	@website bigint
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
			RestApiAccessTokens (
				TokenUUID,
				Expires,
				Scopes,
				RestApiUser,
				RestApiClient,
				EcommerceWebsite
			)
			VALUES
			(
				@uuid,
				@expires,
				@scopes,
				@user,
				@client,
				@website
			);
	END;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
