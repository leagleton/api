SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing access tokens for the specified user for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiUserAccessTokensSelect]
	@user BIGINT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 
		rat.RestApiAccessToken,
		rat.Expires,
		rac.RestApiClientId
	FROM RestApiAccessTokens rat
		INNER JOIN RestApiClients rac ON rac.RestApiClient = rat.RestApiClient
	WHERE
		rat.RestApiUser = @user

	OPTION (OPTIMIZE FOR (@user UNKNOWN))	

END
GO
