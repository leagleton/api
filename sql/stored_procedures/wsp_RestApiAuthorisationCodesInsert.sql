SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for INSERTing authorisation codes for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiAuthorisationCodesInsert]
	@uuid NVARCHAR(36),
	@expires DATETIME,
	@scopes NVARCHAR(1000),
	@client BIGINT,
	@user BIGINT,
	@redirectUri NVARCHAR(max)
AS
BEGIN
	SET NOCOUNT ON;

	IF ISNUMERIC(REPLACE(@scopes, ',', '')) = 0
		BEGIN
			SET @scopes = dbo.wfn_RestApiConvertScopes(@scopes)
		END

	INSERT INTO
		RestApiAuthorisationCodes ( 
			CodeUUID,
			Expires,
			Scopes,
			RestApiClient,
			RestApiUser,
			RedirectURI
		)
		VALUES
		(
			@uuid,
			@expires,
			@scopes,
			@client,
			@user,
			@redirectUri
		)

	OPTION (OPTIMIZE FOR (@uuid UNKNOWN, @expires UNKNOWN, @scopes UNKNOWN, @client UNKNOWN, @user UNKNOWN, @redirectUri UNKNOWN))

END
GO
