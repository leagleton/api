SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing the requested client(s) for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiClientsSelect]
	@client BIGINT = NULL,
	@clientId NVARCHAR(32) = NULL,
	@user BIGINT = NULL
AS
BEGIN
	SET NOCOUNT ON;

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

	OPTION (OPTIMIZE FOR (@client UNKNOWN, @clientId UNKNOWN, @user UNKNOWN))

END
GO
