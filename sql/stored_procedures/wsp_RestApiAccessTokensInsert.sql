SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for INSERTing access tokens for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiAccessTokensInsert]
	@uuid NVARCHAR(36),
	@expires DATETIME,
	@scopes NVARCHAR(20),
	@user BIGINT,
	@client BIGINT
AS
BEGIN
	SET NOCOUNT ON;

	IF ISNUMERIC(REPLACE(@scopes, ',', '')) = 0
		BEGIN
			SET @scopes = dbo.wfn_RestApiConvertScopes(@scopes)
		END

	INSERT INTO
		RestApiAccessTokens (
			TokenUUID,
			Expires,
			Scopes,
			RestApiUser,
			RestApiClient
		)
		VALUES
		(
			@uuid,
			@expires,
			@scopes,
			@user,
			@client
		)

	OPTION (OPTIMIZE FOR (@uuid UNKNOWN, @expires UNKNOWN, @scopes UNKNOWN, @user UNKNOWN, @client UNKNOWN))

END
GO
