SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for INSERTing new clients for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiClientsInsert]
	@clientId NVARCHAR(32),
	@secret NVARCHAR(32),
	@redirectUri NVARCHAR(100),
	@user BIGINT,
	@scopes NVARCHAR(20),
	@client BIGINT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	IF ISNUMERIC(REPLACE(@scopes, ',', '')) = 0
		BEGIN
			SET @scopes = dbo.wfn_RestApiConvertScopes(@scopes)
		END

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
		)

	SET @client = (SELECT SCOPE_IDENTITY())

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
		)

	OPTION (OPTIMIZE FOR (@clientId UNKNOWN, @secret UNKNOWN, @redirectUri UNKNOWN, @user UNKNOWN, @scopes UNKNOWN, @client UNKNOWN))

	SELECT @client AS [client]
END
GO
