SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure to DELETE a specified access token for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiUserAccessTokensDelete]
	@token BIGINT
AS
BEGIN
	SET NOCOUNT ON;

	DELETE FROM
		RestApiAccessTokens
	WHERE
		RestApiAccessToken = @token

	OPTION (OPTIMIZE FOR (@token UNKNOWN))

END
GO
