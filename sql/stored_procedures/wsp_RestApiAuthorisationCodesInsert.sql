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
-- Description:	Stored procedure for INSERTing authorisation codes for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
    SELECT * FROM sys.procedures p
    JOIN sys.schemas s
    ON p.schema_id = s.schema_id
    WHERE
        p.[type] = 'P'
    AND
        p.[name] = 'wsp_RestApiAuthorisationCodesInsert'
    AND
        s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiAuthorisationCodesInsert AS PRINT ''dbo.wsp_RestApiAuthorisationCodesInsert''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiAuthorisationCodesInsert]
	@uuid nvarchar(36),
	@expires datetime,
	@scopes nvarchar(1000),
	@client bigint,
	@user bigint,
	@redirectUri nvarchar(100),
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
			RestApiAuthorisationCodes ( 
				CodeUUID,
				Expires,
				Scopes,
				RestApiClient,
				RestApiUser,
				RedirectURI,
				EcommerceWebsite
			)
			VALUES
			(
				@uuid,
				@expires,
				@scopes,
				@client,
				@user,
				@redirectUri,
				@website
			);
	END;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
