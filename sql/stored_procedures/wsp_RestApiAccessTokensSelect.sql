SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing the requested access token for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiAccessTokensSelect]
	@uuid NVARCHAR(36)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 
		Expires,
		Scopes,
		RestApiClient,
		RestApiUser
	FROM RestApiAccessTokens
	WHERE
		TokenUUID = @uuid
		AND Expires > GETDATE()

	OPTION (OPTIMIZE FOR (@uuid UNKNOWN))		

END
GO
